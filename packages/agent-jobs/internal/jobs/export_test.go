package jobs

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestExportSessions(t *testing.T) {
	for _, mode := range []string{"success", "failure", "timeout", "oversize"} {
		t.Run(mode, func(t *testing.T) {
			store, _, run := fixture(t)
			dir := filepath.Join(store.Directory, run.Job, run.ID)
			raw := filepath.Join(dir, "output/sessions/2025-01_test.jsonl")

			original, err := os.ReadFile(raw)
			if err != nil {
				t.Fatal(err)
			}
			if mode == "oversize" {
				f, err := os.OpenFile(raw, os.O_WRONLY, 0)
				if err != nil {
					t.Fatal(err)
				}
				if err = f.Truncate(maxSessionBytes + 1); err != nil {
					t.Fatal(err)
				}
				_ = f.Close()
			}

			script := `#!/bin/sh
[ "$1" = --export ] || exit 4
[ -z "$SECRET_TOKEN" ] || exit 5
printf changed >> "$2"
printf report > "$3"
`
			if mode == "failure" {
				script += "exit 2\n"
			}
			if mode == "timeout" {
				script += "exec /bin/sleep 5\n"
			}

			pi := filepath.Join(t.TempDir(), "pi")
			if err := os.WriteFile(pi, []byte(script), 0755); err != nil {
				t.Fatal(err)
			}
			t.Setenv("SECRET_TOKEN", "secret")

			ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
			defer cancel()
			err = store.exportSessions(ctx, run, pi)
			if (err == nil) != (mode == "success") {
				t.Fatalf("export: %v", err)
			}
			if mode != "oversize" {
				got, err := os.ReadFile(raw)
				if err != nil || string(got) != string(original) {
					t.Fatalf("raw changed: %v", err)
				}
			}

			output := filepath.Join(dir, "session-html/2025-01_test.jsonl.html")
			data, readErr := os.ReadFile(output)
			if mode == "success" {
				if readErr != nil || string(data) != "report" {
					t.Fatalf("report: %s %v", data, readErr)
				}
				info, _ := os.Stat(output)
				if info.Mode().Perm() != 0640 {
					t.Fatal(info.Mode())
				}
			} else if !os.IsNotExist(readErr) {
				t.Fatalf("unexpected report: %v", readErr)
			}

			entries, err := os.ReadDir(filepath.Dir(output))
			if err != nil {
				t.Fatal(err)
			}
			for _, e := range entries {
				if strings.HasPrefix(e.Name(), ".export-") {
					t.Fatal(e.Name())
				}
			}
		})
	}
}
