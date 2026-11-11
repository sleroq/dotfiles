package jobs

import (
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"
)

type Run struct {
	ID                           string    `json:"id"`
	Job                          string    `json:"job"`
	Repository                   string    `json:"repository"`
	Branch                       string    `json:"branch"`
	Model                        string    `json:"model"`
	Status                       string    `json:"status"`
	Phase                        string    `json:"phase"`
	StartedAt                    time.Time `json:"started_at"`
	FinishedAt                   time.Time `json:"finished_at,omitzero"`
	DurationSeconds              float64   `json:"duration_seconds"`
	SandboxDurationSeconds       float64   `json:"sandbox_duration_seconds"`
	NixStoreSeedBytes            int64     `json:"nix_store_seed_bytes"`
	NixStoreSetupDurationSeconds float64   `json:"nix_store_setup_duration_seconds"`
	ExpectedBranch               *string   `json:"expected_branch,omitempty"`
	StartCommit                  string    `json:"start_commit,omitempty"`
	ExistingPR                   bool      `json:"existing_pr,omitempty"`
	BaseCommit                   string    `json:"base_commit,omitempty"`
	PRURL                        string    `json:"pr_url,omitempty"`
	Publication                  string    `json:"publication,omitempty"`
	Error                        string    `json:"error,omitempty"`
}

type Store struct{ Directory string }

var errFileTooLarge = errors.New("file exceeds 64 MiB read limit")

func (s Store) Create(job Job) (Run, error) {
	run := Run{
		ID:  time.Now().UTC().Format("20060102T150405") + "-" + rand.Text()[:10],
		Job: job.Name, Repository: job.Repository, Branch: job.Branch, Model: job.Model,
		Status: "running", Phase: "prepare", StartedAt: time.Now().UTC(),
	}
	if err := os.MkdirAll(filepath.Join(s.Directory, run.Job, run.ID), 0750); err != nil {
		return Run{}, err
	}
	return run, s.Save(run)
}

func (s Store) Save(run Run) error {
	directory := filepath.Join(s.Directory, run.Job, run.ID)
	data, err := json.MarshalIndent(run, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(directory, "result.json.tmp"), append(data, '\n'), 0640); err != nil {
		return err
	}
	return os.Rename(filepath.Join(directory, "result.json.tmp"), filepath.Join(directory, "result.json"))
}

func (s Store) Get(job, id string) (Run, error) {
	file, err := s.Open(job, id, "result.json")
	if err != nil {
		return Run{}, err
	}
	defer func() { _ = file.Close() }()
	var run Run
	if err := json.NewDecoder(file).Decode(&run); err != nil {
		return Run{}, fmt.Errorf("decode run %s/%s: %w", job, id, err)
	}
	if run.Job != job || run.ID != id {
		return Run{}, errors.New("run identity does not match its directory")
	}
	return run, nil
}

func (s Store) List() ([]Run, error) {
	jobs, err := os.ReadDir(s.Directory)
	if err != nil {
		return nil, err
	}

	runs := []Run{}
	for _, job := range jobs {
		if !job.IsDir() || !Identifier(job.Name()) {
			continue
		}
		entries, err := os.ReadDir(filepath.Join(s.Directory, job.Name()))
		if err != nil {
			return nil, err
		}
		for _, entry := range entries {
			if !entry.IsDir() || !Identifier(entry.Name()) {
				continue
			}
			run, err := s.Get(job.Name(), entry.Name())
			if err != nil {
				return nil, err
			}
			runs = append(runs, run)
		}
	}

	slices.SortFunc(runs, func(a, b Run) int { return b.StartedAt.Compare(a.StartedAt) })
	return runs, nil
}

// runFiles opens each directory without following agent-controlled symlinks.
func (s Store) runFiles(job, run string, dirs ...string) (*os.Root, error) {
	if !Identifier(job) || !Identifier(run) {
		return nil, fs.ErrNotExist
	}
	root, err := os.OpenRoot(s.Directory)
	if err != nil {
		return nil, err
	}
	for _, name := range append([]string{job, run}, dirs...) {
		info, e := root.Lstat(name)
		if e != nil {
			_ = root.Close()
			return nil, e
		}
		if !info.IsDir() {
			_ = root.Close()
			return nil, fs.ErrNotExist
		}
		next, e := root.OpenRoot(name)
		_ = root.Close()
		if e != nil {
			return nil, e
		}
		root = next
	}
	return root, nil
}

// Open opens a regular artifact without following symlinks in its run path.
func (s Store) Open(job, id, name string) (*os.File, error) {
	if !fs.ValidPath(name) || name == "." {
		return nil, fs.ErrNotExist
	}
	parts := strings.Split(name, "/")
	root, err := s.runFiles(job, id, parts[:len(parts)-1]...)
	if err != nil {
		return nil, err
	}
	defer func() { _ = root.Close() }()
	base := parts[len(parts)-1]
	info, err := root.Lstat(base)
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() {
		return nil, fs.ErrNotExist
	}
	file, err := root.Open(base)
	if err != nil {
		return nil, err
	}
	info, err = file.Stat()
	if err != nil {
		_ = file.Close()
		return nil, err
	}
	if !info.Mode().IsRegular() {
		_ = file.Close()
		return nil, fs.ErrNotExist
	}
	return file, nil
}

func (s Store) Read(job, id, name string) ([]byte, error) {
	file, err := s.Open(job, id, name)
	if err != nil {
		return nil, err
	}
	defer func() { _ = file.Close() }()
	info, err := file.Stat()
	if err != nil {
		return nil, err
	}
	const limit = 64 << 20
	if info.Size() > limit {
		return nil, errFileTooLarge
	}
	data, err := io.ReadAll(io.LimitReader(file, limit+1))
	if err != nil {
		return nil, err
	}
	if len(data) > limit {
		return nil, errFileTooLarge
	}
	return data, nil
}

func (s Store) Prune(before time.Time) error {
	runs, err := s.List()
	if err != nil {
		return err
	}
	for _, run := range runs {
		if run.Status != "running" && !run.FinishedAt.IsZero() && run.FinishedAt.Before(before) {
			if err := os.RemoveAll(filepath.Join(s.Directory, run.Job, run.ID)); err != nil {
				return err
			}
		}
	}
	return nil
}
