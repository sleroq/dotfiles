package jobs

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestReadPRBody(t *testing.T) {
	limit := strings.Repeat("x", maxPRBodyBytes)
	for _, test := range []struct {
		name, contents, want string
		wantError            bool
	}{
		{"markdown", "\nUpdate **Helium** and its matching hash.\n", "Update **Helium** and its matching hash.", false},
		{"limit", limit, limit, false},
		{"missing", "", "", true},
		{"empty", " \n\t", "", true},
		{"oversized", limit + "x", "", true},
		{"invalid-utf8", string([]byte{0xff}), "", true},
	} {
		t.Run(test.name, func(t *testing.T) {
			store := Store{Directory: t.TempDir()}
			run, err := store.Create(Job{Name: "fixture"})
			if err != nil {
				t.Fatal(err)
			}
			filename := filepath.Join(store.Directory, run.Job, run.ID, prBodyArtifact)
			if err := os.MkdirAll(filepath.Dir(filename), 0750); err != nil {
				t.Fatal(err)
			}
			if test.name != "missing" {
				if err := os.WriteFile(filename, []byte(test.contents), 0640); err != nil {
					t.Fatal(err)
				}
			}

			body, err := readPRBody(store, run)
			if (err != nil) != test.wantError || body != test.want {
				t.Fatalf("body %q, error %v; want %q, error %t", body, err, test.want, test.wantError)
			}
		})
	}
}

func TestNoChangeDoesNotRequirePRBody(t *testing.T) {
	directory := t.TempDir()
	if err := os.Mkdir(filepath.Join(directory, "output"), 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(directory, "output", "candidate.patch"), nil, 0640); err != nil {
		t.Fatal(err)
	}
	run := Run{}
	execution := jobRun{job: Job{Publish: Publication{Enabled: true}}, directory: directory, run: &run}
	if err := execution.publish(context.Background()); err != nil {
		t.Fatal(err)
	}
	if run.Status != "success" || run.Publication != "no_change" {
		t.Fatalf("run: %+v", run)
	}
}

func TestRetryPublicationRequiresValidatedMatchingRun(t *testing.T) {
	job := Job{
		Name: "fixture", Repository: "owner/repo", Branch: "automation/fixture", AllowedPaths: []string{"file"},
		Image: "sandbox", Network: "agentjobs", PiCommand: []string{"pi"}, Prompt: "prompt", TimeoutSeconds: 5,
		MemoryMB: 128, CPUs: 1, PIDs: 10, WorkspaceMB: 64, OutputMB: 1,
		Publish: Publication{Enabled: true, AppID: "1", InstallationID: "2", PrivateKeyFile: "/not-accessed"},
	}

	for _, scenario := range []string{"sandbox", "success", "repository", "branch", "base", "disabled", "timed-out-publish", "timed-out-sandbox", "legacy-missing"} {
		t.Run(scenario, func(t *testing.T) {
			store := Store{Directory: t.TempDir()}
			run, err := store.Create(job)
			if err != nil {
				t.Fatal(err)
			}
			run.Status, run.Phase, run.BaseCommit = "failed", "publish", "base"
			snapshot := ""
			run.ExpectedBranch = &snapshot
			configured := job
			switch scenario {
			case "legacy-missing":
				run.ExpectedBranch = nil
			case "sandbox":
				run.Phase = "sandbox"
			case "success":
				run.Status = "success"
			case "repository":
				run.Repository = "other/repo"
			case "branch":
				run.Branch = "automation/other"
			case "base":
				run.BaseCommit = ""
			case "disabled":
				configured.Publish.Enabled = false
			case "timed-out-publish":
				run.Status = "timed_out"
			case "timed-out-sandbox":
				run.Status, run.Phase = "timed_out", "sandbox"
			}

			if err := store.Save(run); err != nil {
				t.Fatal(err)
			}
			err = RetryPublication(context.Background(), configured, store, run.ID)
			if scenario == "timed-out-publish" {
				var pathErr *os.PathError
				artifact := filepath.Join(store.Directory, run.Job, run.ID, prBodyArtifact)
				if !errors.As(err, &pathErr) || (pathErr.Path != artifact && !strings.HasPrefix(pathErr.Path, "/var/lib/agent-jobs-work")) {
					t.Fatalf("retry did not reach workspace or artifact: %v", err)
				}
				return
			}
			if !errors.Is(err, errPublicationNotRetryable) {
				t.Fatalf("unexpected retry result: %v", err)
			}

			retained, err := store.Get(job.Name, run.ID)
			if err != nil || !reflect.DeepEqual(retained, run) {
				t.Fatalf("rejected retry changed run: %+v: %v", retained, err)
			}
		})
	}
}
