package jobs

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"
)

const prBodyArtifact = "output/pr-body.md"
const maxPRBodyBytes = 1024
const prBodyInstruction = `PR description artifact:
When you make changes, write /output/pr-body.md as UTF-8 Markdown: one or two short sentences describing what changed and why, at most 1 KiB. This text becomes the body of the new or existing PR. Do not include a title, logs, checklists, secrets, or claims of checks you did not run; keep detailed validation in your final response. Write the artifact outside /workspace, not as a repository change. No artifact is required when there are no changes.`

func readPRBody(store Store, run Run) (string, error) {
	file, err := store.Open(run.Job, run.ID, prBodyArtifact)
	if err != nil {
		return "", fmt.Errorf("PR description artifact: %w", err)
	}
	defer func() { _ = file.Close() }()
	data, err := io.ReadAll(io.LimitReader(file, maxPRBodyBytes+1))
	if err != nil {
		return "", fmt.Errorf("read PR description: %w", err)
	}
	if len(data) > maxPRBodyBytes {
		return "", errors.New("PR description exceeds the 1 KiB limit")
	}
	body := strings.TrimSpace(string(data))
	if body == "" || !utf8.ValidString(body) {
		return "", errors.New("PR description must be non-empty UTF-8 text")
	}
	return body, nil
}

var errPublicationNotRetryable = errors.New("publication retry requires an enabled job and a failed publication for its repository and branch")

// RetryPublication rechecks and publishes a retained candidate without rerunning the agent.
func RetryPublication(ctx context.Context, job Job, store Store, id string) (resultErr error) {
	if err := job.Check(); err != nil {
		return err
	}
	run, err := store.Get(job.Name, id)
	if err != nil {
		return err
	}
	if !job.Publish.Enabled || run.Status != "failed" || run.Phase != "publish" || run.Repository != job.Repository || run.Branch != job.Branch || run.BaseCommit == "" {
		return errPublicationNotRetryable
	}
	work, err := os.MkdirTemp("/var/lib/agent-jobs-work", "publish-")
	if err != nil {
		return err
	}
	defer func() { resultErr = errors.Join(resultErr, os.RemoveAll(work)) }()
	home := filepath.Join(work, "home")
	if err := os.Mkdir(home, 0700); err != nil {
		return err
	}
	remote, err := url.Parse(cloneURL(job))
	if err != nil {
		return err
	}

	run.Status = "running"
	run.Error = ""
	run.FinishedAt = time.Time{}
	if err := store.Save(run); err != nil {
		return err
	}
	defer func() {
		run.FinishedAt = time.Now().UTC()
		run.DurationSeconds = run.FinishedAt.Sub(run.StartedAt).Seconds()
		if resultErr != nil {
			run.Status = "failed"
			run.Error = resultErr.Error()
		} else {
			run.Status = "success"
			run.Phase = "finished"
		}
		resultErr = errors.Join(resultErr, store.Save(run))
	}()
	ctx, cancel := context.WithTimeout(ctx, job.Timeout())
	defer cancel()
	git := hostGit{home: home, credentialHost: remote.Host}
	api := githubClient{baseURL: "https://api.github.com", client: &http.Client{Timeout: 30 * time.Second}}
	patch := filepath.Join(store.Directory, run.Job, run.ID, "output", "candidate.patch")
	body, err := readPRBody(store, run)
	if err != nil {
		return err
	}
	run.PRURL, run.Publication, resultErr = git.publish(ctx, job, work, run.BaseCommit, "", patch, body, api, run)
	return resultErr
}
