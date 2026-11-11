package jobs

import (
	"errors"
	"io/fs"
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
		Prompt: "Update Helium", Image: "agent:pin",
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
}

func TestStoreRejectsInternalSymlinks(t *testing.T) {
	store := Store{Directory: t.TempDir()}
	run, err := store.Create(Job{Name: "helium"})
	if err != nil {
		t.Fatal(err)
	}
	dir := filepath.Join(store.Directory, run.Job, run.ID)
	if err := os.Mkdir(filepath.Join(dir, "real"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "real", "artifact"), []byte("content"), 0644); err != nil {
		t.Fatal(err)
	}
	for link, target := range map[string]string{"link": "real/artifact", "linked-dir": "real"} {
		if err := os.Symlink(target, filepath.Join(dir, link)); err != nil {
			t.Fatal(err)
		}
	}
	for _, name := range []string{"link", "linked-dir/artifact", ".", "", "real/../real/artifact", "real//artifact"} {
		t.Run(name, func(t *testing.T) {
			file, err := store.Open(run.Job, run.ID, name)
			if err == nil {
				_ = file.Close()
				t.Fatalf("Open accepted %q", name)
			}
			if _, err := store.Read(run.Job, run.ID, name); err == nil {
				t.Fatalf("Read accepted %q", name)
			}
		})
	}
	if data, err := store.Read(run.Job, run.ID, "real/artifact"); err != nil || string(data) != "content" {
		t.Fatalf("regular artifact: %q %v", data, err)
	}
	for _, ids := range [][2]string{{"../helium", run.ID}, {run.Job, "../" + run.ID}} {
		if _, err := store.Open(ids[0], ids[1], "real/artifact"); !errors.Is(err, fs.ErrNotExist) {
			t.Errorf("invalid identifiers %q: %v", ids, err)
		}
	}
}

func TestStoreReadLimit(t *testing.T) {
	store := Store{Directory: t.TempDir()}
	run, err := store.Create(Job{Name: "helium"})
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(store.Directory, run.Job, run.ID, "large")
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := file.Truncate((64 << 20) + 1); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Read(run.Job, run.ID, "large"); !errors.Is(err, errFileTooLarge) {
		t.Fatalf("Read limit: %v", err)
	}
	file, err = store.Open(run.Job, run.ID, "large")
	if err != nil {
		t.Fatal(err)
	}
	_ = file.Close()
}

func TestStoreIgnoresInterruptedStaging(t *testing.T) {
	store := Store{Directory: t.TempDir()}
	jobDir := filepath.Join(store.Directory, "helium")
	staging := filepath.Join(jobDir, ".run-interrupted")
	if err := os.MkdirAll(staging, 0750); err != nil {
		t.Fatal(err)
	}
	run, err := store.Create(Job{Name: "helium"})
	if err != nil {
		t.Fatal(err)
	}
	got, err := store.Get(run.Job, run.ID)
	if err != nil || got != run {
		t.Fatalf("created run: %+v, %v", got, err)
	}
	info, err := os.Stat(filepath.Join(jobDir, run.ID))
	if err != nil || info.Mode().Perm() != 0750 {
		t.Fatalf("run directory: %v, %v", info, err)
	}
	entries, err := os.ReadDir(jobDir)
	if err != nil || len(entries) != 2 {
		t.Fatalf("job entries: %v, %v", entries, err)
	}
	runs, err := store.List()
	if err != nil || len(runs) != 1 || runs[0].ID != run.ID {
		t.Fatalf("list: %v, %v", runs, err)
	}
	if err := WriteMetrics(store, filepath.Join(t.TempDir(), "metrics.prom")); err != nil {
		t.Fatal(err)
	}
	if err := store.Prune(time.Now()); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(staging); err != nil {
		t.Fatalf("staging removed: %v", err)
	}
}
