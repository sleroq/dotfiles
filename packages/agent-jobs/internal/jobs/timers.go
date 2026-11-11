package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"
)

type TimerInventory struct {
	Names     []string
	Systemctl string
}
type timer struct {
	Name, Active, UnitFile, Load string
	Next                         time.Time
	Relative                     string
	Available                    bool
}

func LoadTimerInventory(path, systemctl string) (TimerInventory, error) {
	inventory := TimerInventory{Systemctl: systemctl}
	if path != "" {
		data, err := os.ReadFile(path)
		if err != nil {
			return inventory, err
		}
		if err := json.Unmarshal(data, &inventory.Names); err != nil {
			return inventory, err
		}
	}
	for _, name := range inventory.Names {
		if !Identifier(name) {
			return inventory, fmt.Errorf("invalid job name %q", name)
		}
	}
	if systemctl != "" && !filepath.IsAbs(systemctl) {
		return inventory, fmt.Errorf("systemctl path must be absolute")
	}
	return inventory, nil
}

func (inventory TimerInventory) query(ctx context.Context, now time.Time) (scheduled, other []timer) {
	if len(inventory.Names) == 0 {
		return nil, nil
	}
	args := []string{
		"--system", "--no-pager", "--all", "--timestamp=unix",
		"--property=Id,LoadState,ActiveState,UnitFileState,NextElapseUSecRealtime", "show",
	}
	for _, name := range inventory.Names {
		args = append(args, "agent-job-"+name+".timer")
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, inventory.Systemctl, args...)
	cmd.Env = append(os.Environ(), "LC_ALL=C", "TZ=UTC")
	output, err := cmd.Output()
	records := map[string]timer{}
	if err == nil {
		records = parseTimers(output)
	}

	for _, name := range inventory.Names {
		t, ok := records[name]
		if !ok {
			t = timer{Name: name}
		}
		if t.Available && t.Active == "active" && !t.Next.IsZero() {
			t.Relative = relativeDuration(t.Next.Sub(now))
			scheduled = append(scheduled, t)
		} else {
			other = append(other, t)
		}
	}
	slices.SortFunc(scheduled, func(a, b timer) int { return a.Next.Compare(b.Next) })
	return scheduled, other
}

func parseTimers(output []byte) map[string]timer {
	records := map[string]timer{}
	for block := range strings.SplitSeq(strings.TrimSpace(string(output)), "\n\n") {
		props := map[string]string{}
		for line := range strings.SplitSeq(block, "\n") {
			key, value, ok := strings.Cut(line, "=")
			if ok {
				props[key] = value
			}
		}
		id := props["Id"]
		if !strings.HasPrefix(id, "agent-job-") || !strings.HasSuffix(id, ".timer") {
			continue
		}
		name := strings.TrimSuffix(strings.TrimPrefix(id, "agent-job-"), ".timer")
		t := timer{Name: name, Active: props["ActiveState"], UnitFile: props["UnitFileState"], Load: props["LoadState"]}
		raw, exists := props["NextElapseUSecRealtime"]
		t.Available = exists && t.Active != "" && t.UnitFile != "" && t.Load == "loaded"
		if raw != "" && raw != "n/a" {
			seconds, err := strconv.ParseInt(strings.TrimPrefix(raw, "@"), 10, 64)
			if !strings.HasPrefix(raw, "@") || err != nil || seconds <= 0 {
				t.Available = false
			} else {
				t.Next = time.Unix(seconds, 0).UTC()
			}
		}
		records[name] = t
	}
	return records
}

func relativeDuration(delta time.Duration) string {
	delta = delta.Round(time.Second)
	if delta == 0 {
		return "Due now"
	}
	overdue := delta < 0
	if overdue {
		delta = -delta
	}
	units := []struct {
		duration time.Duration
		name     string
	}{
		{24 * time.Hour, "day"}, {time.Hour, "hour"}, {time.Minute, "minute"}, {time.Second, "second"},
	}
	var parts []string
	for _, unit := range units {
		count := delta / unit.duration
		if count == 0 {
			continue
		}
		name := unit.name
		if count != 1 {
			name += "s"
		}
		parts = append(parts, fmt.Sprintf("%d %s", count, name))
		delta %= unit.duration
		if len(parts) == 2 {
			break
		}
	}
	duration := strings.Join(parts, ", ")
	if overdue {
		return "Due " + duration + " ago"
	}
	return "In " + duration
}
