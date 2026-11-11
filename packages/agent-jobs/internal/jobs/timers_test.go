package jobs

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestTimerInventoryAndViewer(t *testing.T) {
	dir := t.TempDir()
	output := `Id=agent-job-later.timer
LoadState=loaded
ActiveState=active
UnitFileState=disabled
NextElapseUSecRealtime=@2000000200

Id=agent-job-earlier.timer
LoadState=loaded
ActiveState=active
UnitFileState=enabled
NextElapseUSecRealtime=@2000000100

Id=agent-job-stopped.timer
LoadState=loaded
ActiveState=inactive
UnitFileState=enabled
NextElapseUSecRealtime=@2000000050

Id=agent-job-unscheduled.timer
LoadState=loaded
ActiveState=active
UnitFileState=disabled
NextElapseUSecRealtime=n/a
`
	path := filepath.Join(dir, "systemctl")
	calls := filepath.Join(dir, "calls")
	script := "#!/bin/sh\nprintf '%s\\n' \"$LC_ALL $TZ $*\" >> '" + calls + "'\ncat <<'END'\n" + output + "END\n"
	if err := os.WriteFile(path, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	inventory := TimerInventory{Names: []string{"later", "earlier", "stopped", "unscheduled", "missing"}, Systemctl: path}
	upcoming, other := inventory.query(context.Background(), time.Unix(2000000000, 0))
	if len(upcoming) != 2 || upcoming[0].Name != "earlier" || upcoming[1].Name != "later" || upcoming[1].UnitFile != "disabled" || len(other) != 3 || other[0].Active != "inactive" || !other[1].Next.IsZero() || other[2].Available {
		t.Fatalf("upcoming=%+v other=%+v", upcoming, other)
	}
	store, _, _ := fixture(t)
	h, err := NewViewer(store, inventory)
	if err != nil {
		t.Fatal(err)
	}
	body := request(h, "GET", "/?job=later&status=failed").Body.String()
	for _, want := range []string{"<ol class=\"timeline\">", "<time datetime=", "later", "Unit file: disabled", "Status filters run history only", "No runs match"} {
		if !strings.Contains(body, want) {
			t.Errorf("missing %q", want)
		}
	}
	if strings.Contains(body, "agent-job-earlier") || strings.Contains(body, ">earlier</strong>") {
		t.Fatal(body)
	}
	before, _ := os.ReadFile(filepath.Join(dir, "calls"))
	request(h, "GET", "/api/runs")
	request(h, "GET", "/api/jobs")
	after, _ := os.ReadFile(filepath.Join(dir, "calls"))
	if string(before) != string(after) {
		t.Fatal("API invoked systemctl")
	}
	if !strings.Contains(string(after), "C UTC --system --no-pager --all --timestamp=unix") {
		t.Fatal(string(after))
	}
	inventory.Systemctl = filepath.Join(dir, "missing")
	upcoming, other = inventory.query(context.Background(), time.Now())
	if len(upcoming) != 0 || len(other) != 5 || other[0].Available {
		t.Fatal(upcoming, other)
	}
}

func TestLoadTimerInventory(t *testing.T) {
	path := filepath.Join(t.TempDir(), "jobs.json")
	if err := os.WriteFile(path, []byte(`["ok","../bad"]`), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadTimerInventory(path, "/bin/systemctl"); err == nil {
		t.Fatal("accepted invalid name")
	}
	if _, err := LoadTimerInventory("", "systemctl"); err == nil {
		t.Fatal("accepted relative executable")
	}
}

func TestRelativeDuration(t *testing.T) {
	tests := []struct {
		delta time.Duration
		want  string
	}{
		{0, "Due now"}, {400 * time.Millisecond, "Due now"}, {-400 * time.Millisecond, "Due now"},
		{26 * time.Hour, "In 1 day, 2 hours"}, {5 * time.Minute, "In 5 minutes"},
		{time.Second, "In 1 second"}, {72*time.Hour + 3*time.Minute, "In 3 days, 3 minutes"},
		{-26 * time.Hour, "Due 1 day, 2 hours ago"}, {-5 * time.Minute, "Due 5 minutes ago"},
		{time.Hour + time.Minute + time.Second, "In 1 hour, 1 minute"},
	}
	for _, test := range tests {
		t.Run(test.delta.String(), func(t *testing.T) {
			if got := relativeDuration(test.delta); got != test.want {
				t.Errorf("got %q, want %q", got, test.want)
			}
		})
	}
}
