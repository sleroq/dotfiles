package jobs

import (
	"archive/tar"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
	"sync"
)

type sandboxConfig struct {
	Name             string            `json:"name"`
	PiCommand        []string          `json:"pi_command"`
	Model            string            `json:"model"`
	Thinking         string            `json:"thinking"`
	EnvironmentFiles map[string]string `json:"environment_files"`
	OutputMB         int               `json:"output_mb"`
	History          bool              `json:"history"`
	BaseCommit       string            `json:"base_commit"`
	StartCommit      string            `json:"start_commit"`
	ExistingPR       bool              `json:"existing_pr"`
}

type sandboxResult struct {
	Agent string `json:"agent"`
}

func Hold(ctx context.Context) error { <-ctx.Done(); return nil }

func RunSandbox(ctx context.Context, configPath string) (resultErr error) {
	data, err := os.ReadFile(configPath)
	if err != nil {
		return err
	}
	var cfg sandboxConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return err
	}
	if len(cfg.PiCommand) == 0 || cfg.OutputMB <= 0 {
		return errors.New("invalid sandbox configuration")
	}
	env, err := cfg.environment()
	if err != nil {
		return err
	}
	if err := setupSandboxHome(); err != nil {
		return err
	}
	git := hostGit{home: "/home/agent"}
	if err := cfg.prepareGit(ctx, git, "/workspace", "/input/repo", "/input/repository.bundle"); err != nil {
		return err
	}
	if err := configureSandboxDirenv(ctx, git, "/workspace"); err != nil {
		return err
	}
	if err := os.MkdirAll("/output/sessions", 0750); err != nil {
		return err
	}

	result := sandboxResult{Agent: "failed"}
	defer func() {
		data, err := json.Marshal(result)
		if err == nil {
			err = os.WriteFile("/output/result.json", append(data, '\n'), 0640)
		}
		resultErr = errors.Join(resultErr, err)
	}()
	if err := cfg.runAgent(ctx, env); err != nil {
		return err
	}
	result.Agent = "success"
	return cfg.writeCandidate(ctx, git, "/workspace", "/output/candidate.patch")
}

func (cfg sandboxConfig) environment() ([]string, error) {
	env := []string{
		"PATH=/bin", "HOME=/home/agent", "TMPDIR=/tmp", "BASH_ENV=/etc/agent-jobs/bash-env",
		"SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt",
		"GIT_CONFIG_NOSYSTEM=1", "GIT_CONFIG_GLOBAL=/dev/null",
		"GIT_TERMINAL_PROMPT=0", "GIT_LFS_SKIP_SMUDGE=1",
	}
	for _, name := range []string{"FUMO_BASE_URL", "FUMO_PI_KEY"} {
		if value := os.Getenv(name); value != "" {
			env = append(env, name+"="+value)
		}
	}
	for name, file := range cfg.EnvironmentFiles {
		value, err := os.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("read environment credential %s: %w", name, err)
		}
		env = append(env, name+"="+strings.TrimRight(string(value), "\r\n"))
	}
	return env, nil
}

func (cfg sandboxConfig) prepareGit(ctx context.Context, git hostGit, directory, source, bundle string) error {
	var commands [][]string
	if cfg.History {
		commands = [][]string{
			{"init", "-q"},
			{"fetch", "--update-head-ok", "--no-tags", bundle, "+refs/*:refs/*"},
			{"checkout", "--detach", cfg.StartCommit},
			{"config", "user.name", "Agent Jobs"},
			{"config", "user.email", "agent-jobs@localhost"},
		}
	} else {
		if err := copySource(source, directory); err != nil {
			return err
		}
		commands = [][]string{
			{"init", "-q"}, {"add", "-A", "--force"},
			{"-c", "user.name=Agent Jobs", "-c", "user.email=agent-jobs@localhost", "commit", "--allow-empty", "-qm", "base"},
		}
	}
	for _, args := range commands {
		if _, err := git.run(ctx, directory, args...); err != nil {
			return err
		}
	}
	return nil
}

func configureSandboxDirenv(ctx context.Context, git hostGit, directory string) error {
	bash, err := exec.LookPath("bash")
	if err != nil {
		return err
	}
	tracked, err := git.command(ctx, directory, "ls-files", "-z", "--", ".envrc", "**/.envrc").Output()
	if err != nil {
		return fmt.Errorf("list project environment files: %w", err)
	}
	allowed := []string{filepath.Join(directory, ".envrc")}
	for name := range strings.SplitSeq(string(tracked), "\x00") {
		if name != "" && name != ".envrc" {
			allowed = append(allowed, filepath.Join(directory, name))
		}
	}
	paths, err := json.Marshal(allowed)
	if err != nil {
		return err
	}
	config := filepath.Join(git.home, ".config", "direnv")
	if err := os.MkdirAll(config, 0750); err != nil {
		return err
	}
	contents := fmt.Sprintf("[global]\nbash_path = %q\n[whitelist]\nexact = %s\n", bash, paths)
	return os.WriteFile(filepath.Join(config, "direnv.toml"), []byte(contents), 0640)
}

func sandboxCommand(ctx context.Context, env []string, args ...string) *exec.Cmd {
	command := append([]string{"-c", `exec "$@"`, "agent-jobs"}, args...)
	cmd := exec.CommandContext(ctx, "bash", command...)
	cmd.Dir = "/workspace"
	cmd.Env = env
	return cmd
}

func (cfg sandboxConfig) runAgent(ctx context.Context, env []string) error {
	args := append([]string{}, cfg.PiCommand[1:]...)
	args = append(args, "--print", "--session-dir", "/output/sessions", "--name", cfg.Name)
	if cfg.Model != "" {
		args = append(args, "--model", cfg.Model)
	}
	if cfg.Thinking != "" {
		args = append(args, "--thinking", cfg.Thinking)
	}
	args = append(args, "@/input/prompt")
	cmd := sandboxCommand(ctx, env, append([]string{cfg.PiCommand[0]}, args...)...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("agent: %w", err)
	}
	return nil
}

func (cfg sandboxConfig) writeCandidate(ctx context.Context, git hostGit, directory, patchPath string) error {
	if cfg.History {
		if err := checkCandidateCheckout(ctx, git, directory); err != nil {
			return err
		}
	}
	if _, err := git.run(ctx, directory, "add", "-A"); err != nil {
		return err
	}
	patch, err := os.OpenFile(patchPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0640)
	if err != nil {
		return err
	}
	defer func() { _ = patch.Close() }()

	args := []string{"diff", "--cached", "--binary", "--full-index", "--no-ext-diff", "--no-textconv"}
	if cfg.History {
		if cfg.ExistingPR {
			unchanged, err := cfg.unchangedProposal(ctx, git, directory)
			if err != nil {
				return err
			}
			if unchanged {
				return patch.Close()
			}
		}
		if _, err := git.run(ctx, directory, "merge-base", "--is-ancestor", cfg.BaseCommit, "HEAD"); err != nil {
			return fmt.Errorf("base commit is not an ancestor of final HEAD: %w", err)
		}
		if cfg.ExistingPR {
			tree, err := git.run(ctx, directory, "write-tree")
			if err != nil {
				return err
			}
			baseTree, err := git.run(ctx, directory, "rev-parse", cfg.BaseCommit+"^{tree}")
			if err != nil {
				return err
			}
			if tree == baseTree {
				return errors.New("existing PR now has no diff against the default base and needs operator attention")
			}
		}
		args = append(args, cfg.BaseCommit)
	}
	diff := git.command(ctx, directory, args...)
	patchWriter := &boundedWriter{writer: patch, remaining: int64(cfg.OutputMB) * 1024 * 1024}
	diff.Stdout = patchWriter
	diff.Stderr = os.Stderr
	err = diff.Run()
	closeErr := patch.Close()
	if patchWriter.truncated {
		return errors.New("candidate patch exceeds output limit")
	}
	return errors.Join(err, closeErr)
}

func checkCandidateCheckout(ctx context.Context, git hostGit, directory string) error {
	for _, name := range []string{"rebase-merge", "rebase-apply"} {
		location, err := git.run(ctx, directory, "rev-parse", "--git-path", name)
		if err != nil {
			return err
		}
		if !filepath.IsAbs(location) {
			location = filepath.Join(directory, location)
		}
		if _, err := os.Stat(location); err == nil {
			return errors.New("cannot write candidate while a rebase is in progress")
		} else if !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	unmerged, err := git.run(ctx, directory, "ls-files", "--unmerged")
	if err != nil {
		return err
	}
	if unmerged != "" {
		return errors.New("cannot write candidate with unresolved index entries")
	}
	return nil
}

func (cfg sandboxConfig) unchangedProposal(ctx context.Context, git hostGit, directory string) (bool, error) {
	head, err := git.run(ctx, directory, "rev-parse", "HEAD")
	if err != nil || head != cfg.StartCommit {
		return false, err
	}
	tree, err := git.run(ctx, directory, "write-tree")
	if err != nil {
		return false, err
	}
	initial, err := git.run(ctx, directory, "rev-parse", cfg.StartCommit+"^{tree}")
	return tree == initial, err
}

type boundedWriter struct {
	mu        sync.Mutex
	truncated bool
	writer    io.Writer
	remaining int64
}

func (w *boundedWriter) Write(p []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	n := len(p)
	if int64(len(p)) > w.remaining {
		w.truncated = true
		p = p[:w.remaining]
	}
	if len(p) > 0 {
		written, err := w.writer.Write(p)
		w.remaining -= int64(written)
		if err != nil {
			return written, err
		}
		if written != len(p) {
			return written, io.ErrShortWrite
		}
	}
	return n, nil
}

func setupSandboxHome() error {
	const profile = "/etc/agent-pi"
	if _, err := os.Stat(profile); err == nil {
		if err := copySource(profile, "/home/agent/.pi/agent"); err != nil {
			return err
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	data, err := os.ReadFile("/etc/sgconfig.yml")
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join("/home/agent", "sgconfig.yml"), data, 0644)
}

// ArchiveOutput streams only regular output files and directories from the sandbox.
func ArchiveOutput(output io.Writer) error { return archiveOutput("/output", output) }

func archiveOutput(directory string, output io.Writer) error {
	root, err := os.OpenRoot(directory)
	if err != nil {
		return err
	}
	defer func() { _ = root.Close() }()
	writer := tar.NewWriter(output)
	archiveEntry := func(name string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if !info.IsDir() && !info.Mode().IsRegular() {
			return fmt.Errorf("unsupported output entry %q", name)
		}
		header, err := tar.FileInfoHeader(info, "")
		if err != nil {
			return err
		}
		header.Name = path.Join("output", name)
		if err := writer.WriteHeader(header); err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		file, err := root.Open(name)
		if err != nil {
			return err
		}
		_, copyErr := io.CopyN(writer, file, info.Size())
		return errors.Join(copyErr, file.Close())
	}
	walkErr := fs.WalkDir(root.FS(), ".", archiveEntry)
	return errors.Join(walkErr, writer.Close())
}
