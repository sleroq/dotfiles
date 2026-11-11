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
	if err := copySource("/input/repo", "/workspace"); err != nil {
		return err
	}
	git := hostGit{home: "/home/agent"}
	if err := prepareSandboxGit(ctx, git); err != nil {
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
	return cfg.writeCandidate(ctx, git)
}

func (cfg sandboxConfig) environment() ([]string, error) {
	env := []string{
		"PATH=/bin", "HOME=/home/agent", "TMPDIR=/tmp", "BASH_ENV=/etc/agent-jobs/bash-env",
		"SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt",
		"GIT_CONFIG_NOSYSTEM=1", "GIT_CONFIG_GLOBAL=/dev/null",
		"GIT_TERMINAL_PROMPT=0", "GIT_LFS_SKIP_SMUDGE=1",
	}
	if value := os.Getenv("FUMO_BASE_URL"); value != "" {
		env = append(env, "FUMO_BASE_URL="+value)
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

func prepareSandboxGit(ctx context.Context, git hostGit) error {
	commands := [][]string{
		{"init", "-q"}, {"add", "-A", "--force"},
		{"-c", "user.name=Agent Jobs", "-c", "user.email=agent-jobs@localhost", "commit", "--allow-empty", "-qm", "base"},
	}
	for _, args := range commands {
		if _, err := git.run(ctx, "/workspace", args...); err != nil {
			return err
		}
	}
	return nil
}

func configureSandboxDirenv(ctx context.Context, git hostGit, directory string) error {
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
	contents := "[global]\nbash_path = \"/bin/bash\"\n[whitelist]\nexact = " + string(paths) + "\n"
	return os.WriteFile(filepath.Join(config, "direnv.toml"), []byte(contents), 0640)
}

func sandboxCommand(ctx context.Context, env []string, args ...string) *exec.Cmd {
	command := append([]string{"-c", `exec "$@"`, "agent-jobs"}, args...)
	cmd := exec.CommandContext(ctx, "/bin/bash", command...)
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

func (cfg sandboxConfig) writeCandidate(ctx context.Context, git hostGit) error {
	if _, err := git.run(ctx, "/workspace", "add", "-A"); err != nil {
		return err
	}
	patch, err := os.OpenFile("/output/candidate.patch", os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0640)
	if err != nil {
		return err
	}
	diff := git.command(ctx, "/workspace", "diff", "--cached", "--binary", "--full-index",
		"--no-ext-diff", "--no-textconv")
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
