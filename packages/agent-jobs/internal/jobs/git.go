package jobs

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"
)

type hostGit struct{ home, token, credentialHost string }

func (g hostGit) command(ctx context.Context, dir string, args ...string) *exec.Cmd {
	options := []string{
		"-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false",
		"-c", "credential.helper=", "-c", `credential.helper=!f() { ` +
			`while IFS= read -r line; do case "$line" in protocol=*) protocol=${line#protocol=} ;; ` +
			`host=*) host=${line#host=} ;; esac; done; ` +
			`if [ "$protocol" = https ] && [ "$host" = "$AGENT_JOBS_GIT_HOST" ]; then ` +
			`echo username=x-access-token; echo "password=$AGENT_JOBS_GIT_TOKEN"; fi; }; f`,
		"-c", "protocol.ssh.allow=never", "-c", "protocol.ext.allow=never",
	}
	cmd := exec.CommandContext(ctx, "git", append(options, args...)...)
	cmd.Dir = dir
	cmd.Env = []string{
		"PATH=" + os.Getenv("PATH"), "HOME=" + g.home, "XDG_CONFIG_HOME=" + g.home,
		"GIT_CONFIG_NOSYSTEM=1", "GIT_CONFIG_GLOBAL=/dev/null", "GIT_TERMINAL_PROMPT=0",
		"GIT_SSH_COMMAND=/bin/false", "GIT_LFS_SKIP_SMUDGE=1",
		"AGENT_JOBS_GIT_TOKEN=" + g.token, "AGENT_JOBS_GIT_HOST=" + g.credentialHost, "LC_ALL=C",
	}
	return cmd
}

func (g hostGit) run(ctx context.Context, dir string, args ...string) (string, error) {
	var stderr bytes.Buffer
	cmd := g.command(ctx, dir, args...)
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil { // Git can echo remote URLs or credentials; do not retain its output on failure.
		wrapped := fmt.Errorf("git %s: %w", args[0], err)
		text := strings.ToLower(string(out) + stderr.String())
		for _, marker := range []string{"could not resolve host", "connection timed out", "connection reset", "failed to connect", "remote end hung up", "http 429", "error: 429", "error: 500", "error: 502", "error: 503", "error: 504"} {
			if strings.Contains(text, marker) {
				return "", transientGitError{wrapped}
			}
		}
		return "", wrapped
	}
	return strings.TrimSpace(string(out)), nil
}

func cloneURL(job Job) string {
	if job.CloneURL != "" {
		return job.CloneURL
	}
	return "https://x-access-token@github.com/" + job.Repository + ".git"
}

type transientGitError struct{ err error }

func (e transientGitError) Error() string { return e.err.Error() }
func (e transientGitError) Unwrap() error { return e.err }

func retryGit(ctx context.Context, operation func() error) error {
	for attempt := 0; ; attempt++ {
		err := operation()
		var transient transientGitError
		if err == nil || attempt == 2 || !errors.As(err, &transient) {
			return err
		}
		timer := time.NewTimer(time.Duration(attempt+1) * time.Second)
		select {
		case <-ctx.Done():
			timer.Stop()
			return ctx.Err()
		case <-timer.C:
		}
	}
}

func (g hostGit) remoteBranch(ctx context.Context, dir, branch string) (string, error) {
	ref := "refs/heads/" + branch
	remote, err := g.run(ctx, dir, "ls-remote", "--heads", "origin", ref)
	if err != nil || remote == "" {
		return "", err
	}
	fields := strings.Fields(remote)
	if len(fields) != 2 || fields[1] != ref {
		return "", errors.New("invalid remote branch response")
	}
	return fields[0], nil
}

func (g hostGit) checkout(ctx context.Context, job Job, dir string) (string, error) {
	return g.checkoutWithDepth(ctx, job, dir, false)
}

func (g hostGit) checkoutWithDepth(ctx context.Context, job Job, dir string, shallow bool) (string, error) {
	args := []string{"clone", "--no-checkout"}
	if shallow {
		args = append(args, "--depth=1", "--no-local")
	}
	args = append(args, "--", cloneURL(job), dir)
	err := retryGit(ctx, func() error {
		if err := os.RemoveAll(dir); err != nil {
			return err
		}
		_, err := g.run(ctx, "", args...)
		return err
	})
	if err != nil {
		return "", err
	}
	base, err := g.run(ctx, dir, "rev-parse", "--verify", "refs/remotes/origin/HEAD^{commit}")
	if err != nil {
		return "", err
	}
	if _, err := g.run(ctx, dir, "checkout", "--detach", base, "--"); err != nil {
		return "", err
	}
	return base, nil
}

// applyCandidate only operates on a fresh trusted checkout, never the guest's .git.
func (g hostGit) applyCandidate(ctx context.Context, dir, patch string, allowed []string) (string, error) {
	if _, err := g.run(ctx, dir, "apply", "--index", "--", patch); err != nil {
		return "", err
	}
	out, err := g.command(ctx, dir, "diff", "--cached", "--raw", "--no-renames", "-z").Output()
	if err != nil {
		return "", fmt.Errorf("inspect candidate: %w", err)
	}
	entries := strings.Split(strings.TrimSuffix(string(out), "\x00"), "\x00")
	if len(entries) == 1 && entries[0] == "" {
		entries = nil
	}
	if len(entries)%2 != 0 {
		return "", errors.New("invalid git diff entries")
	}
	for i := 0; i < len(entries); i += 2 {
		fields := strings.Fields(entries[i])
		name := entries[i+1]
		if len(fields) != 5 {
			return "", errors.New("invalid git diff metadata")
		}
		if !slices.Contains(allowed, name) {
			return "", fmt.Errorf("candidate changes disallowed path %q", name)
		}
		for part := range strings.SplitSeq(name, "/") {
			if strings.EqualFold(part, ".git") {
				return "", errors.New("candidate changes Git metadata")
			}
		}
		for _, mode := range []string{strings.TrimPrefix(fields[0], ":"), fields[1]} {
			if mode != "000000" && mode != "100644" && mode != "100755" {
				return "", fmt.Errorf("candidate uses disallowed mode for %q", name)
			}
		}
	}
	return g.run(ctx, dir, "write-tree")
}

func copySource(src, dst string) error {
	return filepath.WalkDir(src, func(name string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}

		rel, err := filepath.Rel(src, name)
		if err != nil {
			return err
		}
		if rel == ".git" {
			return filepath.SkipDir
		}

		target := filepath.Join(dst, rel)
		info, err := entry.Info()
		if err != nil {
			return err
		}

		switch {
		case info.IsDir():
			if err := os.MkdirAll(target, 0755); err != nil {
				return err
			}
			return os.Chmod(target, 0755)
		case info.Mode().IsRegular():
			source, err := os.Open(name)
			if err != nil {
				return err
			}
			mode := os.FileMode(0644)
			if info.Mode()&0111 != 0 {
				mode = 0755
			}
			targetFile, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, mode)
			if err != nil {
				return errors.Join(err, source.Close())
			}
			_, copyErr := io.Copy(targetFile, source)
			closeErr := targetFile.Close()
			if err := errors.Join(copyErr, closeErr, source.Close()); err != nil {
				return err
			}
			return os.Chmod(target, mode)
		case info.Mode()&os.ModeSymlink != 0:
			link, err := os.Readlink(name)
			if err != nil {
				return err
			}
			return os.Symlink(link, target)
		default:
			return fmt.Errorf("unsupported source file %q", rel)
		}
	})
}

func (g hostGit) publish(ctx context.Context, job Job, dir, base, defaultBranch, patch, body string, api githubClient, run Run) (string, string, error) {
	var pr, publication string
	err := retryGit(ctx, func() error {
		var err error
		pr, publication, err = g.publishOnce(ctx, job, dir, base, defaultBranch, patch, body, api, run)
		return err
	})
	return pr, publication, err
}

func (g hostGit) publishOnce(ctx context.Context, job Job, dir, base, defaultBranch, patch, body string, api githubClient, run Run) (prURL, publication string, resultErr error) {
	expected := run.ExpectedBranch
	if expected == nil && run.ExistingPR && run.StartCommit != "" {
		expected = &run.StartCommit
	}
	if expected == nil {
		return "", "", errors.New("publication requires a captured remote branch")
	}
	token, err := api.installationToken(ctx, job)
	if err != nil {
		return "", "", err
	}
	defer func() {
		cleanup, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		resultErr = errors.Join(resultErr, api.request(cleanup, http.MethodDelete, "/installation/token", token, nil, nil))
	}()
	g.token = token
	checkout := filepath.Join(dir, "publish")
	_, err = g.checkout(ctx, job, checkout)
	if err != nil {
		return "", "", err
	}
	if _, err := g.run(ctx, checkout, "checkout", "--detach", base, "--"); err != nil {
		return "", "", err
	}
	if defaultBranch == "" {
		branch, err := g.run(ctx, checkout, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
		if err != nil {
			return "", "", err
		}
		defaultBranch = strings.TrimPrefix(branch, "origin/")
	}

	tree, err := g.applyCandidate(ctx, checkout, patch, job.AllowedPaths)
	if err != nil {
		return "", "", err
	}
	baseTree, err := g.run(ctx, checkout, "rev-parse", base+"^{tree}")
	if err != nil {
		return "", "", err
	}
	if tree == baseTree {
		return "", "no_change", nil
	}
	ref := "refs/heads/" + job.Branch
	remote, err := g.remoteBranch(ctx, checkout, job.Branch)
	if err != nil {
		return "", "", err
	}
	if remote != "" {
		if _, err := g.run(ctx, checkout, "fetch", "--no-tags", "origin", ref); err != nil {
			return "", "", err
		}
		remoteTree, err := g.run(ctx, checkout, "rev-parse", "FETCH_HEAD^{tree}")
		if err != nil {
			return "", "", err
		}
		if remoteTree == tree {
			pr, err := api.pullRequest(ctx, job, token, defaultBranch, body)
			return pr, "unchanged", err
		}
	}
	if remote != *expected {
		return "", "", errors.New("remote branch changed since the run started")
	}
	title := job.Publish.Title
	if title == "" {
		title = job.Name
	}
	_, err = g.run(ctx, checkout, "-c", "user.name=Agent Jobs", "-c",
		"user.email=agent-jobs@users.noreply.github.com", "commit", "-m", title)
	if err != nil {
		return "", "", err
	}
	if _, err := g.run(ctx, checkout, "push", "--force-with-lease="+ref+":"+*expected, "origin", "HEAD:"+ref); err != nil {
		return "", "", err
	}
	pr, err := api.pullRequest(ctx, job, token, defaultBranch, body)
	return pr, "published", err
}
