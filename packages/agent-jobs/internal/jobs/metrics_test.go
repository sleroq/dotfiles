package jobs

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestWriteMetricsUsesLatestFinishedAndSuccess(t *testing.T) {
	store := Store{Directory: t.TempDir()}
	job := Job{Name: "sample"}
	first, err := store.Create(job)
	if err != nil {
		t.Fatal(err)
	}
	first.Status = "success"
	first.FinishedAt = time.Unix(100, 0)
	if err := store.Save(first); err != nil {
		t.Fatal(err)
	}
	last, err := store.Create(job)
	if err != nil {
		t.Fatal(err)
	}
	last.Status = "failed"
	last.FinishedAt = time.Unix(200, 0)
	last.DurationSeconds = 8
	last.SandboxDurationSeconds = 6
	last.NixStoreSeedBytes = 123456
	last.NixStoreSetupDurationSeconds = 2.5
	if err := store.Save(last); err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(t.TempDir(), "metrics.prom")
	if err := WriteMetrics(store, file); err != nil {
		t.Fatal(err)
	}
	content, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}

	for _, want := range []string{
		`agent_job_last_duration_seconds{agent_job="sample"} 8`,
		`agent_job_last_sandbox_duration_seconds{agent_job="sample"} 6`,
		`agent_job_last_nix_store_seed_bytes{agent_job="sample"} 123456`,
		`agent_job_last_nix_store_setup_duration_seconds{agent_job="sample"} 2.5`,
		`agent_job_last_run_success{agent_job="sample"} 0`,
		`agent_job_last_finished_timestamp_seconds{agent_job="sample"} 200`,
		`agent_job_last_success_timestamp_seconds{agent_job="sample"} 100`,
	} {
		if !strings.Contains(string(content), want) {
			t.Errorf("missing %s in %s", want, content)
		}
	}
}
