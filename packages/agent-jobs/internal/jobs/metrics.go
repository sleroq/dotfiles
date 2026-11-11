package jobs

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

// WriteMetrics publishes one bounded set of samples per job with completed runs.
func WriteMetrics(store Store, filename string) error {
	runs, err := store.List()
	if err != nil {
		return err
	}

	last := map[string]Run{}
	success := map[string]Run{}
	for _, run := range runs {
		if run.FinishedAt.IsZero() || run.Status == "running" {
			continue
		}
		if old, ok := last[run.Job]; !ok || run.FinishedAt.After(old.FinishedAt) {
			last[run.Job] = run
		}
		if run.Status == "success" {
			if old, ok := success[run.Job]; !ok || run.FinishedAt.After(old.FinishedAt) {
				success[run.Job] = run
			}
		}
	}

	names := make([]string, 0, len(last))
	for name := range last {
		names = append(names, name)
	}
	sort.Strings(names)

	var buf bytes.Buffer
	for _, name := range names {
		run := last[name]
		succeeded := 0
		if run.Status == "success" {
			succeeded = 1
		}
		fmt.Fprintf(&buf, "agent_job_last_duration_seconds{agent_job=%q} %g\n", name, run.DurationSeconds)
		fmt.Fprintf(&buf, "agent_job_last_sandbox_duration_seconds{agent_job=%q} %g\n", name, run.SandboxDurationSeconds)
		fmt.Fprintf(&buf, "agent_job_last_nix_store_seed_bytes{agent_job=%q} %d\n", name, run.NixStoreSeedBytes)
		fmt.Fprintf(&buf, "agent_job_last_nix_store_setup_duration_seconds{agent_job=%q} %g\n",
			name, run.NixStoreSetupDurationSeconds)
		fmt.Fprintf(&buf, "agent_job_last_run_success{agent_job=%q} %d\n", name, succeeded)
		fmt.Fprintf(&buf, "agent_job_last_finished_timestamp_seconds{agent_job=%q} %d\n", name, run.FinishedAt.Unix())
		if latest, ok := success[name]; ok {
			fmt.Fprintf(&buf, "agent_job_last_success_timestamp_seconds{agent_job=%q} %d\n", name, latest.FinishedAt.Unix())
		}
	}

	file, err := os.CreateTemp(filepath.Dir(filename), ".agent-jobs-metrics-*")
	if err != nil {
		return err
	}
	defer func() { _ = os.Remove(file.Name()) }()
	if err := file.Chmod(0644); err != nil {
		return errors.Join(err, file.Close())
	}
	if _, err := file.Write(buf.Bytes()); err != nil {
		return errors.Join(err, file.Close())
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), filename)
}
