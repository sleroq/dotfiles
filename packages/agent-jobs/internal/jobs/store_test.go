package jobs

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestStoreConfinesArtifactsAndRetainsRuns(t *testing.T) {
	store := Store{Directory: t.TempDir()}
	run, err := store.Create(Job{Name: "helium", Repository: "sleroq/dotfiles"})
	if err != nil {
		t.Fatal(err)
	}

	runs, err := store.List()
	if err != nil || len(runs) != 1 || runs[0].ID != run.ID {
		t.Fatalf("list runs: %v, %v", runs, err)
	}

	outside := filepath.Join(t.TempDir(), "credential")
	if err := os.WriteFile(outside, []byte("must not be served"), 0600); err != nil {
		t.Fatal(err)
	}
	directory := filepath.Join(store.Directory, run.Job, run.ID)
	if err := os.Symlink(outside, filepath.Join(directory, "escape")); err != nil {
		t.Fatal(err)
	}

	for _, name := range []string{"escape", "../../../credential", "/etc/passwd"} {
		file, err := store.Open(run.Job, run.ID, name)
		if err == nil {
			_ = file.Close()
			t.Errorf("opened forbidden artifact %q", name)
		}
	}

	if err := store.Prune(time.Now().Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Get(run.Job, run.ID); err != nil {
		t.Fatalf("pruned an active run: %v", err)
	}

	run.Status = "success"
	run.FinishedAt = time.Now().Add(-48 * time.Hour)
	if err := store.Save(run); err != nil {
		t.Fatal(err)
	}
	if err := store.Prune(time.Now().Add(-24 * time.Hour)); err != nil {
		t.Fatal(err)
	}
	runs, err = store.List()
	if err != nil || len(runs) != 0 {
		t.Fatalf("prune result: %v, %v", runs, err)
	}
}

func TestJobRejectsUnsafePublicationScope(t *testing.T) {
	job := Job{
		Name: "helium", Repository: "sleroq/dotfiles", Branch: "automation/helium",
		AllowedPaths: []string{"packages/helium.nix"}, Prompt: "Update Helium", Image: "agent:pin",
		Network: "agent-jobs", PiCommand: []string{"/bin/pi"}, TimeoutSeconds: 60,
		MemoryMB: 1024, CPUs: 1, PIDs: 64, WorkspaceMB: 512, OutputMB: 64,
	}
	if err := job.Check(); err != nil {
		t.Fatal(err)
	}
	for _, branch := range []string{"main", "automation/../../main", "automation/a\nmain", "-main"} {
		job.Branch = branch
		if err := job.Check(); err == nil {
			t.Errorf("accepted branch %q", branch)
		}
	}
	job.Branch = "automation/helium"
	for _, name := range []string{"../key", "/etc/passwd", ".git/config", ".", "packages/../key"} {
		job.AllowedPaths = []string{name}
		if err := job.Check(); err == nil {
			t.Errorf("accepted allowed path %q", name)
		}
	}
}
