package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type run struct {
	ID        string     `json:"id"`
	Status    string     `json:"status"`
	StartedAt time.Time  `json:"startedAt"`
	EndedAt   *time.Time `json:"endedAt"`
	Output    string     `json:"output"`
}

type schedule struct {
	ID        string     `json:"id"`
	Name      string     `json:"name"`
	Prompt    string     `json:"prompt"`
	Status    string     `json:"status"`
	NextRunAt *time.Time `json:"nextRunAt"`
	Runs      []run      `json:"runs"`
}

func (r run) outcome() (string, error) {
	switch r.Status {
	case "failed":
		return "failed", nil
	case "succeeded":
		var markers []string
		for line := range strings.SplitSeq(r.Output, "\n") {
			if marker, ok := strings.CutPrefix(strings.TrimSpace(line), "PASEO_SCHEDULE_RESULT="); ok {
				markers = append(markers, marker)
			}
		}
		if len(markers) == 1 {
			switch markers[0] {
			case "SUCCESS":
				return "success", nil
			case "BLOCKED":
				return "blocked", nil
			}
		}
		return "missing", nil
	default:
		return "", fmt.Errorf("run %s has unknown status %q", r.ID, r.Status)
	}
}

func paseoJSON(ctx context.Context, paseo string, result any, args ...string) error {
	cmd := exec.CommandContext(ctx, paseo, append(args, "--json")...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	data, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("paseo %s: %w: %s", strings.Join(args, " "), err, strings.TrimSpace(stderr.String()))
	}
	return json.Unmarshal(data, result)
}

func (s schedule) metrics(since time.Time) (string, error) {
	labels := fmt.Sprintf("schedule=%s,name=%s", strconv.Quote(s.ID), strconv.Quote(s.Name))

	active := 0
	switch s.Status {
	case "active":
		active = 1
	case "paused", "completed":
	default:
		return "", fmt.Errorf("schedule %s has unknown status %q", s.ID, s.Status)
	}
	var next, last int64
	if s.NextRunAt != nil {
		next = s.NextRunAt.Unix()
	}

	var lastSuccess time.Time
	for _, r := range s.Runs {
		if r.Status != "succeeded" || r.EndedAt == nil {
			continue
		}
		outcome, _ := r.outcome()
		if outcome == "success" || (outcome == "missing" && (!strings.Contains(s.Prompt, "PASEO_SCHEDULE_RESULT=") || r.StartedAt.Before(since))) {
			if r.EndedAt.After(lastSuccess) {
				lastSuccess = *r.EndedAt
			}
		}
	}

	var outcomes strings.Builder
	for _, r := range s.Runs {
		if r.StartedAt.Unix() > last {
			last = r.StartedAt.Unix()
		}
		if r.Status == "running" {
			fmt.Fprintf(&outcomes, "paseo_schedule_run_started_timestamp_seconds{%s,run=%s} %d\n",
				labels, strconv.Quote(r.ID), r.StartedAt.Unix())
			continue
		}
		outcome, err := r.outcome()
		if err != nil {
			return "", err
		}
		if outcome == "missing" && (!strings.Contains(s.Prompt, "PASEO_SCHEDULE_RESULT=") || r.StartedAt.Before(since)) {
			continue
		}
		if outcome != "success" {
			if r.EndedAt == nil || r.EndedAt.IsZero() {
				return "", fmt.Errorf("completed run %s has no end time", r.ID)
			}
			if !r.EndedAt.After(lastSuccess) {
				continue
			}
			fmt.Fprintf(&outcomes, "paseo_schedule_run_outcome{%s,run=%s,outcome=%s} %d\n",
				labels, strconv.Quote(r.ID), strconv.Quote(outcome), r.EndedAt.Unix())
		}
	}

	var result strings.Builder
	fmt.Fprintf(&result, "paseo_schedule_active{%s} %d\n", labels, active)
	fmt.Fprintf(&result, "paseo_schedule_last_run_timestamp_seconds{%s} %d\n", labels, last)
	fmt.Fprintf(&result, "paseo_schedule_next_run_timestamp_seconds{%s} %d\n", labels, next)
	result.WriteString(outcomes.String())
	return result.String(), nil
}

func collect(ctx context.Context, paseo string, since time.Time) (string, error) {
	var schedules []schedule
	if err := paseoJSON(ctx, paseo, &schedules, "schedule", "ls"); err != nil {
		return "", err
	}
	var metrics strings.Builder
	for _, entry := range schedules {
		var s schedule
		if err := paseoJSON(ctx, paseo, &s, "schedule", "inspect", entry.ID); err != nil {
			return "", err
		}
		text, err := s.metrics(since)
		if err != nil {
			return "", err
		}
		metrics.WriteString(text)
	}
	return metrics.String(), nil
}

func writeMetrics(path, text string) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".paseo-schedule-*.tmp")
	if err != nil {
		return err
	}
	defer func() { _ = os.Remove(f.Name()) }()
	if err := f.Chmod(0644); err != nil {
		_ = f.Close()
		return err
	}
	if _, err := f.WriteString(text); err != nil {
		_ = f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	return os.Rename(f.Name(), path)
}

func initializedAt(path string) (time.Time, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		now := time.Now().UTC()
		return now, os.WriteFile(path, []byte(now.Format(time.RFC3339Nano)), 0644)
	}
	if err != nil {
		return time.Time{}, err
	}
	return time.Parse(time.RFC3339Nano, strings.TrimSpace(string(data)))
}

func main() {
	paseo := flag.String("paseo", "paseo", "Paseo executable")
	output := flag.String("output", "", "Prometheus textfile path")
	state := flag.String("state", "", "persistent initialization timestamp file")
	flag.Parse()
	if *state == "" || *output == "" {
		fmt.Fprintln(os.Stderr, "-output and -state are required")
		os.Exit(2)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	since, collectErr := initializedAt(*state)
	var text string
	if collectErr == nil {
		text, collectErr = collect(ctx, *paseo, since)
	}
	cancel()
	success := 1
	if collectErr != nil {
		success = 0
	}
	text += fmt.Sprintf("paseo_schedule_checker_success %d\n", success)
	text += fmt.Sprintf("paseo_schedule_checker_timestamp_seconds %d\n", time.Now().Unix())
	if err := writeMetrics(*output, text); err != nil {
		fmt.Fprintln(os.Stderr, "write metrics:", err)
		os.Exit(1)
	}
	if collectErr != nil {
		fmt.Fprintln(os.Stderr, collectErr)
		os.Exit(1)
	}
}
