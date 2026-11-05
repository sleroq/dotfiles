package main

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestOutcome(t *testing.T) {
	for _, tc := range []struct{ status, output, want string }{
		{"failed", "PASEO_SCHEDULE_RESULT=SUCCESS", "failed"},
		{"succeeded", "Done.\nPASEO_SCHEDULE_RESULT=SUCCESS\n", "success"},
		{"succeeded", "PASEO_SCHEDULE_RESULT=BLOCKED", "blocked"},
		{"succeeded", "Done", "missing"},
		{"succeeded", "PASEO_SCHEDULE_RESULT=OTHER", "missing"},
		{"succeeded", "PASEO_SCHEDULE_RESULT=SUCCESS\nPASEO_SCHEDULE_RESULT=BLOCKED", "missing"},
	} {
		got, err := (run{Status: tc.status, Output: tc.output}).outcome()
		if err != nil || got != tc.want {
			t.Errorf("%q %q: got %q, %v; want %q", tc.status, tc.output, got, err, tc.want)
		}
	}
	if _, err := (run{Status: "unknown"}).outcome(); err == nil {
		t.Error("unknown status accepted")
	}
}

func TestMetricsHistoricalAndNewRuns(t *testing.T) {
	start := time.Unix(1000, 0)
	end := time.Unix(1100, 0)
	earlier := time.Unix(1050, 0)
	s := schedule{ID: "123", Name: "test \"job\"", Status: "active", Runs: []run{
		{ID: "old-success", Status: "succeeded", StartedAt: start, EndedAt: &earlier},
		{ID: "old-failure", Status: "failed", StartedAt: start, EndedAt: &end},
		{ID: "running", Status: "running", StartedAt: start},
		{ID: "new-blocked", Status: "succeeded", StartedAt: start.Add(time.Hour), EndedAt: &end, Output: "PASEO_SCHEDULE_RESULT=BLOCKED"},
		{ID: "later-running", Status: "running", StartedAt: start.Add(2 * time.Hour)},
	}}
	got, err := s.metrics(start.Add(time.Minute))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{`name="test \"job\""`, `run="old-failure",outcome="failed"} 1100`, `run="running"} 1000`, `run="new-blocked",outcome="blocked"} 1100`, `paseo_schedule_last_run_timestamp_seconds`, `8200`} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in %s", want, got)
		}
	}
	if strings.Contains(got, "old-success") {
		t.Fatal("historic missing marker exposed")
	}
}

func TestSuccessClearsEarlierFailures(t *testing.T) {
	start := time.Unix(1000, 0)
	end := func(seconds int64) *time.Time { t := start.Add(time.Duration(seconds) * time.Second); return &t }
	failure := run{ID: "failure", Status: "failed", StartedAt: start, EndedAt: end(1)}
	blocked := run{
		ID: "blocked", Status: "succeeded", StartedAt: start.Add(2 * time.Second),
		EndedAt: end(3), Output: "PASEO_SCHEDULE_RESULT=BLOCKED",
	}
	success := run{
		ID: "success", Status: "succeeded", StartedAt: start.Add(4 * time.Second),
		EndedAt: end(5), Output: "PASEO_SCHEDULE_RESULT=SUCCESS",
	}
	for _, tc := range []struct {
		name string
		runs []run
		want bool
	}{
		{"failure remains during running", []run{failure, {ID: "running", Status: "running", StartedAt: start.Add(2 * time.Second)}}, true},
		{"blocked does not clear failure", []run{failure, blocked}, true},
		{"success clears failure", []run{success, failure}, false},
		{"missing marker does not clear failure", []run{failure, {ID: "missing", Status: "succeeded", StartedAt: start.Add(4 * time.Second), EndedAt: end(5)}}, true},
		{"later failure remains", []run{success, {ID: "later", Status: "failed", StartedAt: start.Add(6 * time.Second), EndedAt: end(7)}}, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s := schedule{ID: "abc", Name: "test", Status: "active", Prompt: "PASEO_SCHEDULE_RESULT=", Runs: tc.runs}
			text, err := s.metrics(start)
			if err != nil || strings.Contains(text, `outcome="failed"`) != tc.want {
				t.Fatalf("metrics: %s, %v; want failure=%v", text, err, tc.want)
			}
		})
	}
}

func TestInitializedAtPersists(t *testing.T) {
	path := filepath.Join(t.TempDir(), "initialized")
	first, err := initializedAt(path)
	if err != nil {
		t.Fatal(err)
	}
	second, err := initializedAt(path)
	if err != nil || !first.Equal(second) {
		t.Fatalf("initialization changed: %v, %v", second, err)
	}
	if err := os.WriteFile(path, []byte("invalid"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := initializedAt(path); err == nil {
		t.Fatal("invalid state accepted")
	}
}

func TestInspectAndAtomicMetrics(t *testing.T) {
	dir := t.TempDir()
	paseo := filepath.Join(dir, "paseo")
	script := `#!/bin/sh
case "$2" in
ls) echo '[{"id":"abc"},{"id":"xyz"}]' ;;
inspect) echo "{\"id\":\"$3\",\"name\":\"test\",\"status\":\"active\",\"runs\":[]}" ;;
esac
`
	if err := os.WriteFile(paseo, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	text, err := collect(context.Background(), paseo, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(text, `schedule="abc"`) || !strings.Contains(text, `schedule="xyz"`) {
		t.Fatalf("did not collect all schedules: %s", text)
	}
	path := filepath.Join(dir, "metrics.prom")
	if err := writeMetrics(path, text); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil || string(data) != text {
		t.Fatalf("metrics mismatch: %v", err)
	}
	info, err := os.Stat(path)
	if err != nil || info.Mode().Perm() != 0644 {
		t.Fatalf("metrics mode: %v, %v", info, err)
	}
}

func TestMissingMarkerOnlyForOptedInSchedules(t *testing.T) {
	start := time.Unix(1000, 0)
	end := start.Add(time.Minute)
	newEnd := end.Add(time.Second)
	blockedEnd := end.Add(time.Minute)
	s := schedule{ID: "abc", Name: "test", Status: "active", Runs: []run{
		{ID: "old", Status: "succeeded", StartedAt: start, EndedAt: &end},
		{ID: "new", Status: "succeeded", StartedAt: end, EndedAt: &newEnd},
		{ID: "blocked", Status: "succeeded", StartedAt: end, EndedAt: &blockedEnd, Output: "PASEO_SCHEDULE_RESULT=BLOCKED"},
	}}
	text, err := s.metrics(end)
	if err != nil || strings.Contains(text, `outcome="missing"`) || !strings.Contains(text, `outcome="blocked"`) {
		t.Fatalf("unmanaged outcome: %s, %v", text, err)
	}
	s.Prompt = "Report PASEO_SCHEDULE_RESULT=SUCCESS or BLOCKED"
	text, err = s.metrics(end)
	if err != nil || strings.Contains(text, `run="old"`) || !strings.Contains(text, `run="new",outcome="missing"`) {
		t.Fatalf("opted-in outcome: %s, %v", text, err)
	}
}
