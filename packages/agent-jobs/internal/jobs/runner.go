package jobs

import (
	"archive/tar"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// extractOutput accepts only ordinary files and directories from docker cp.
// The archive is untrusted, including its names, types, sizes and permissions.
func extractOutput(destination string, archive io.Reader, limit int64) error {
	root, err := os.OpenRoot(destination)
	if err != nil {
		return err
	}
	defer func() { _ = root.Close() }()

	reader := tar.NewReader(archive)
	var total, entries int64
	for {
		header, err := reader.Next()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("read output archive: %w", err)
		}
		entries++
		if entries > limit/512+1 {
			return errors.New("output archive has too many entries")
		}
		name := strings.TrimSuffix(header.Name, "/")
		if name == "output" && header.Typeflag == tar.TypeDir {
			continue
		}
		if !strings.HasPrefix(name, "output/") {
			return fmt.Errorf("invalid output archive path %q", header.Name)
		}
		name = strings.TrimPrefix(name, "output/")
		if !fs.ValidPath(name) || name == "." || path.Clean(name) != name {
			return fmt.Errorf("invalid output archive path %q", header.Name)
		}
		switch header.Typeflag {
		case tar.TypeDir:
			if err := root.MkdirAll(name, 0750); err != nil {
				return err
			}
		case tar.TypeReg:
			if header.Size < 0 || header.Size > limit-total {
				return errors.New("output archive exceeds byte limit")
			}
			total += header.Size
			if err := root.MkdirAll(path.Dir(name), 0750); err != nil {
				return err
			}
			file, err := root.OpenFile(name, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0640)
			if err != nil {
				return err
			}
			_, copyErr := io.Copy(file, reader)
			closeErr := file.Close()
			if copyErr != nil {
				return copyErr
			}
			if closeErr != nil {
				return closeErr
			}
		default:
			return fmt.Errorf("unsupported output archive entry %q", header.Name)
		}
	}
}

// RunJob runs the untrusted workload before considering publication.
func RunJob(ctx context.Context, job Job, store Store) (resultErr error) {
	if err := job.Check(); err != nil {
		return err
	}
	run, err := store.Create(job)
	if err != nil {
		return err
	}
	defer func() {
		run.FinishedAt = time.Now().UTC()
		run.DurationSeconds = run.FinishedAt.Sub(run.StartedAt).Seconds()
		if resultErr != nil {
			run.Status = "failed"
			if errors.Is(ctx.Err(), context.DeadlineExceeded) || errors.Is(resultErr, context.DeadlineExceeded) {
				run.Status = "timed_out"
			}
			run.Error = resultErr.Error()
		} else {
			run.Phase = "finished"
		}
		resultErr = errors.Join(resultErr, store.Save(run))
	}()
	ctx, cancel := context.WithTimeout(ctx, job.Timeout())
	defer cancel()
	execution := jobRun{job: job, store: store, run: &run, directory: filepath.Join(store.Directory, run.Job, run.ID)}
	return execution.execute(ctx)
}

type jobRun struct {
	job                                      Job
	store                                    Store
	run                                      *Run
	directory, work, checkout, defaultBranch string
	git                                      hostGit
	stdout, stderr                           *boundedWriter
}

func (r *jobRun) execute(ctx context.Context) (resultErr error) {
	stdout, err := os.OpenFile(filepath.Join(r.directory, "stdout.log"), os.O_CREATE|os.O_WRONLY|os.O_EXCL, 0640)
	if err != nil {
		return err
	}
	defer func() { resultErr = errors.Join(resultErr, stdout.Close()) }()
	stderr, err := os.OpenFile(filepath.Join(r.directory, "stderr.log"), os.O_CREATE|os.O_WRONLY|os.O_EXCL, 0640)
	if err != nil {
		return err
	}
	defer func() { resultErr = errors.Join(resultErr, stderr.Close()) }()
	limit := int64(r.job.OutputMB) * 1024 * 1024
	r.stdout = &boundedWriter{writer: stdout, remaining: limit / 4}
	r.stderr = &boundedWriter{writer: stderr, remaining: limit / 4}
	r.work, err = os.MkdirTemp("/var/lib/agent-jobs-work", "run-")
	if err != nil {
		return fmt.Errorf("create work directory: %w", err)
	}
	defer func() { resultErr = errors.Join(resultErr, os.RemoveAll(r.work)) }()

	if err := r.prepare(ctx); err != nil {
		return err
	}
	if err := r.sandbox(ctx); err != nil {
		return err
	}
	return r.publish(ctx)
}

func (r *jobRun) prepare(ctx context.Context) error {
	home := filepath.Join(r.work, "home")
	if err := os.Mkdir(home, 0700); err != nil {
		return err
	}
	remote, err := url.Parse(cloneURL(r.job))
	if err != nil {
		return fmt.Errorf("parse clone URL: %w", err)
	}
	r.git = hostGit{home: home, credentialHost: remote.Host}
	if r.job.ReadTokenFile != "" {
		token, err := os.ReadFile(r.job.ReadTokenFile)
		if err != nil {
			return fmt.Errorf("read repository credential: %w", err)
		}
		r.git.token = strings.TrimSpace(string(token))
	}
	r.checkout = filepath.Join(r.work, "checkout")
	base, err := r.git.checkoutWithDepth(ctx, r.job, r.checkout, !r.job.ReuseOpenPR)
	if err != nil {
		return err
	}
	r.run.BaseCommit = base
	branch, err := r.git.run(ctx, r.checkout, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
	if err != nil {
		return err
	}
	r.defaultBranch = strings.TrimPrefix(branch, "origin/")
	if r.job.ReuseOpenPR {
		api := githubClient{baseURL: "https://api.github.com", client: &http.Client{Timeout: 30 * time.Second}}
		if err := r.prepareOpenPR(ctx, api); err != nil {
			return err
		}
	}
	return r.store.Save(*r.run)
}

func (r *jobRun) prepareOpenPR(ctx context.Context, api githubClient) (resultErr error) {
	token, err := api.installationToken(ctx, r.job)
	if err != nil {
		return err
	}

	defer func() {
		cleanup, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		resultErr = errors.Join(resultErr, api.request(cleanup, http.MethodDelete, "/installation/token", token, nil, nil))
	}()

	pulls, err := api.openPullRequests(ctx, r.job, token, r.defaultBranch)
	if err != nil {
		return err
	}
	r.run.StartCommit = r.run.BaseCommit
	if len(pulls) == 0 {
		return nil
	}
	if len(pulls) != 1 || pulls[0].Head.SHA == "" {
		return errors.New("GitHub returned invalid open pull requests")
	}

	ref := "refs/remotes/origin/" + r.job.Branch
	tip, err := r.git.run(ctx, r.checkout, "rev-parse", "--verify", ref+"^{commit}")
	if err != nil {
		return err
	}
	remoteRef := "refs/heads/" + r.job.Branch
	remote, err := r.git.run(ctx, r.checkout, "ls-remote", "--heads", "origin", remoteRef)
	if err != nil {
		return err
	}
	if tip != pulls[0].Head.SHA || remote != tip+"\t"+remoteRef {
		return errors.New("open pull request does not match remote branch")
	}
	if _, err := r.git.run(ctx, r.checkout, "checkout", "--detach", tip, "--"); err != nil {
		return err
	}

	r.run.StartCommit, r.run.ExistingPR = tip, true
	return nil
}

func (r *jobRun) sandbox(ctx context.Context) error {
	input, err := stageInput(ctx, r.work, r.checkout, r.defaultBranch, r.job, *r.run)
	if err != nil {
		return err
	}
	r.run.Phase = "sandbox"
	if err := r.store.Save(*r.run); err != nil {
		return err
	}
	output := filepath.Join(r.directory, "output")
	if err := os.Mkdir(output, 0750); err != nil {
		return err
	}
	limit := int64(r.job.OutputMB) * 1024 * 1024
	return runContainer(ctx, r.job, r.run.ID, input, output, r.stdout, r.stderr, limit, &r.run.SandboxDurationSeconds)
}

func (r *jobRun) publish(ctx context.Context) error {
	patch := filepath.Join(r.directory, "output", "candidate.patch")
	info, err := os.Stat(patch)
	if err != nil {
		return fmt.Errorf("candidate patch: %w", err)
	}
	if info.Size() == 0 {
		r.run.Status = "success"
		r.run.Publication = "no_change"
		return nil
	}

	if r.run.ExistingPR {
		if _, err := r.git.run(ctx, r.checkout, "checkout", "--detach", r.run.BaseCommit, "--"); err != nil {
			return err
		}
	}

	if _, err := r.git.applyCandidate(ctx, r.checkout, patch, r.job.AllowedPaths); err != nil {
		return err
	}

	if !r.job.Publish.Enabled {
		r.run.Status = "success"
		r.run.Publication = "disabled"
		return nil
	}

	r.run.Phase = "publish"
	if err := r.store.Save(*r.run); err != nil {
		return err
	}
	body, err := readPRBody(r.store, *r.run)
	if err != nil {
		return err
	}
	api := githubClient{baseURL: "https://api.github.com", client: &http.Client{Timeout: 30 * time.Second}}
	pr, publication, err := r.git.publish(ctx, r.job, r.work, r.run.BaseCommit, r.defaultBranch, patch, body, api, *r.run)
	if err != nil {
		return err
	}
	r.run.PRURL = pr
	r.run.Publication = publication
	r.run.Status = "success"
	return nil
}

func stageInput(ctx context.Context, work, checkout, defaultBranch string, job Job, run Run) (string, error) {
	input := filepath.Join(work, "input")
	for _, name := range []string{"", "repo", "env", "files"} {
		dir := filepath.Join(input, name)
		if err := os.MkdirAll(dir, 0755); err != nil {
			return "", err
		}
		if err := os.Chmod(dir, 0755); err != nil {
			return "", err
		}
	}

	if !job.ReuseOpenPR {
		if err := copySource(checkout, filepath.Join(input, "repo")); err != nil {
			return "", err
		}
	}
	cfg := sandboxConfig{
		Name: job.Name, PiCommand: job.PiCommand,
		Model: job.Model, Thinking: job.Thinking, OutputMB: job.OutputMB,
		EnvironmentFiles: map[string]string{},
	}
	if job.ReuseOpenPR {
		cfg.History, cfg.BaseCommit, cfg.StartCommit, cfg.ExistingPR = true, run.BaseCommit, run.StartCommit, run.ExistingPR
		git := hostGit{home: filepath.Join(work, "home")}
		bundle := filepath.Join(input, "repository.bundle")
		if _, err := git.run(ctx, checkout, "bundle", "create", bundle, "--all"); err != nil {
			return "", err
		}
		if err := os.Chmod(bundle, 0444); err != nil {
			return "", err
		}
	}
	for name, filename := range job.EnvironmentFiles {
		data, err := os.ReadFile(filename)
		if err != nil {
			return "", fmt.Errorf("read credential %s: %w", name, err)
		}
		if err := stageFile(filepath.Join(input, "env", name), data); err != nil {
			return "", err
		}
		cfg.EnvironmentFiles[name] = "/input/env/" + name
	}

	for name, filename := range job.Files {
		data, err := os.ReadFile(filename)
		if err != nil {
			return "", fmt.Errorf("read credential %s: %w", name, err)
		}
		if err := stageFile(filepath.Join(input, "files", name), data); err != nil {
			return "", err
		}
	}

	if err := stageFile(filepath.Join(input, "resolv.conf"), []byte("nameserver 1.1.1.1\n")); err != nil {
		return "", err
	}
	prompt := job.Prompt
	if job.ReuseOpenPR {
		baseRef := "refs/remotes/origin/" + defaultBranch
		if run.ExistingPR {
			prompt += fmt.Sprintf(`

An open PR exists on branch %s at %s. The supplied default branch is %s at %s. Inspect the existing updates and compare against that default reference for conflicts. If no update is needed and there are no conflicts, make no edits and do not rebase. If there are conflicts or new changes are needed, rebase locally onto %s before editing; if you already have edits, stash them before rebasing and restore them afterward. Resolve conflicts locally. When updating the proposal, including conflict resolution alone, write /output/pr-body.md. Do not make other commits or push.`, job.Branch, run.StartCommit, baseRef, run.BaseCommit, baseRef)
		} else {
			prompt += fmt.Sprintf(`

No open PR exists. The checkout is detached at the default branch %s at %s; supplied Git history and refs are available for inspection.`, baseRef, run.BaseCommit)
		}
	}
	if err := stageFile(filepath.Join(input, "prompt"), []byte(prompt+"\n\n"+prBodyInstruction)); err != nil {
		return "", err
	}
	data, err := json.Marshal(cfg)
	if err != nil {
		return "", err
	}
	if err := stageFile(filepath.Join(input, "job.json"), data); err != nil {
		return "", err
	}
	return input, nil
}
func stageFile(name string, data []byte) error {
	if err := os.WriteFile(name, data, 0444); err != nil {
		return err
	}
	return os.Chmod(name, 0444)
}

func dockerCommand(ctx context.Context, args ...string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, "docker", args...)
	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=/nonexistent"}
	return cmd
}

func sandboxRunArgs(job Job, name, nixStore, input string) []string {
	args := []string{
		"run", "--detach", "--pull=never", "--name", name, "--runtime=runsc", "--network", job.Network,
		"--read-only", "--cap-drop", "ALL", "--security-opt", "no-new-privileges",
		"--user", "1000:1000", "--pids-limit", strconv.Itoa(job.PIDs), "--cpus", strconv.Itoa(job.CPUs),
		"--memory", strconv.Itoa(job.MemoryMB) + "m", "--memory-swap", strconv.Itoa(job.MemoryMB) + "m",
	}
	for _, mount := range []struct {
		name string
		size int
	}{{"/workspace", job.WorkspaceMB}, {"/output", job.OutputMB}, {"/home/agent", job.WorkspaceMB}, {"/tmp", job.WorkspaceMB}} {
		options := fmt.Sprintf("%s:rw,nosuid,nodev,size=%dm,uid=1000,gid=1000,mode=0750", mount.name, mount.size)
		args = append(args, "--tmpfs", options)
	}
	args = append(args, "--mount", "type=bind,src="+nixStore+",dst=/nix",
		"--mount", "type=bind,src="+input+",dst=/input,readonly",
		"--mount", "type=bind,src="+filepath.Join(input, "resolv.conf")+",dst=/etc/resolv.conf,readonly",
		"--entrypoint", "/bin/agent-jobs", job.Image, "hold")
	return args
}

func prepareNixStore(ctx context.Context, job Job, source, nixStore string, stdout, stderr io.Writer) (resultErr error) {
	mountpoint := exec.CommandContext(ctx, "mountpoint", "-q", nixStore)
	mountpoint.Env = []string{"PATH=" + os.Getenv("PATH")}
	if err := mountpoint.Run(); err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return fmt.Errorf("private Nix store is not mounted: %w", err)
	}

	sourceCreated := false
	defer func() {
		cleanup, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		err := dockerCommand(cleanup, "rm", "-f", source).Run()
		if sourceCreated && err != nil {
			resultErr = errors.Join(resultErr, fmt.Errorf("remove image source: %w", err))
		}
	}()
	create := dockerCommand(ctx, "create", "--name", source, "--pull=never", "--network", "none",
		"--entrypoint", "/bin/agent-jobs", job.Image, "hold")
	create.Stdout = stdout
	create.Stderr = stderr
	if err := create.Run(); err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return fmt.Errorf("create image source: %w", err)
	}
	sourceCreated = true

	copy := dockerCommand(ctx, "cp", "--archive", source+":/nix/.", nixStore)
	copy.Stdout = stdout
	copy.Stderr = stderr
	if err := copy.Run(); err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return fmt.Errorf("populate private Nix store: %w", err)
	}

	// Docker copies these files as the caller; Nix must own its private single-user store.
	owner := exec.CommandContext(ctx, "chown", "--recursive", "--no-dereference", "1000:1000", nixStore)
	owner.Env = []string{"PATH=" + os.Getenv("PATH")}
	if err := owner.Run(); err != nil {
		return fmt.Errorf("assign private Nix store ownership: %w", err)
	}
	return nil
}

func runContainer(ctx context.Context, job Job, id, input, output string, stdout, stderr *boundedWriter, limit int64, duration *float64) (resultErr error) {
	name := "agent-jobs-" + id
	nixStore := filepath.Join("/var/lib/agent-jobs-work", job.Name, "nix")
	if err := prepareNixStore(ctx, job, name+"-source", nixStore, stdout, stderr); err != nil {
		return err
	}

	containerStarted := false
	defer func() {
		cleanup, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		err := dockerCommand(cleanup, "rm", "-f", name).Run()
		if containerStarted && err != nil {
			resultErr = errors.Join(resultErr, fmt.Errorf("remove sandbox: %w", err))
		}
	}()
	args := sandboxRunArgs(job, name, nixStore, input)
	start := dockerCommand(ctx, args...)
	start.Stdout = stdout
	start.Stderr = stderr
	if err := start.Run(); err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return fmt.Errorf("start sandbox: %w", err)
	}
	containerStarted = true
	run := dockerCommand(ctx, "exec", name, "/bin/agent-jobs", "sandbox", "/input/job.json")
	run.Stdout = stdout
	run.Stderr = stderr
	started := time.Now()
	runErr := run.Run()
	*duration = time.Since(started).Seconds()

	// Preserve partial sessions after a timeout; this context is independent of the job.
	copyCtx, cancelCopy := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancelCopy()
	copyCmd := dockerCommand(copyCtx, "exec", name, "/bin/agent-jobs", "archive")
	pipe, err := copyCmd.StdoutPipe()
	if err != nil {
		return err
	}
	copyCmd.Stderr = io.Discard
	if err := copyCmd.Start(); err != nil {
		return err
	}
	used := limit/2 - stdout.remaining - stderr.remaining
	extractErr := extractOutput(output, pipe, limit-used)
	if extractErr != nil {
		_ = copyCmd.Process.Kill()
	}
	copyErr := copyCmd.Wait()
	if ctx.Err() != nil {
		return errors.Join(ctx.Err(), extractErr, copyErr)
	}
	if extractErr != nil {
		return fmt.Errorf("retrieve sandbox output: %w", extractErr)
	}
	if copyErr != nil {
		return fmt.Errorf("archive sandbox output: %w", copyErr)
	}
	if runErr != nil {
		return fmt.Errorf("sandbox execution: %w", runErr)
	}
	return nil
}
