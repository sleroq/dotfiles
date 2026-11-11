package jobs

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestConfigureSandboxDirenv(t *testing.T) {
	git, repo := gitTestRepo(t)

	for _, name := range []string{"nested/.envrc", ` quoted"/.envrc`, "other.txt"} {
		file := filepath.Join(repo, name)
		if err := os.MkdirAll(filepath.Dir(file), 0755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(file, []byte("fixture"), 0644); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := git.run(context.Background(), repo, "add", "."); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(repo, "clone"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(repo, "clone", ".envrc"), []byte("untrusted"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := configureSandboxDirenv(context.Background(), git, repo); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(git.home, ".config", "direnv", "direnv.toml"))
	if err != nil {
		t.Fatal(err)
	}
	prefix := "[global]\nbash_path = \"/bin/bash\"\n[whitelist]\nexact = "
	if !strings.HasPrefix(string(data), prefix) {
		t.Fatalf("unexpected config: %s", data)
	}
	var paths []string
	if err := json.Unmarshal(bytes.TrimSpace(data[len(prefix):]), &paths); err != nil {
		t.Fatal(err)
	}
	want := []string{
		filepath.Join(repo, ".envrc"),
		filepath.Join(repo, ` quoted"/.envrc`),
		filepath.Join(repo, "nested/.envrc"),
	}
	if !reflect.DeepEqual(paths, want) {
		t.Fatalf("allowed paths %q, want %q", paths, want)
	}
}

func TestSandboxCommandPreservesArguments(t *testing.T) {
	env := []string{"BASH_ENV=/etc/agent-jobs/bash-env"}
	cmd := sandboxCommand(context.Background(), env, "tool", "arg with spaces", "$(false)")
	want := []string{"/bin/bash", "-c", `exec "$@"`, "agent-jobs", "tool", "arg with spaces", "$(false)"}
	if !reflect.DeepEqual(cmd.Args, want) || cmd.Dir != "/workspace" || !reflect.DeepEqual(cmd.Env, env) {
		t.Fatalf("command: %#v", cmd)
	}
}

func TestArchiveOutputRejectsSymlinks(t *testing.T) {
	dir := t.TempDir()
	if err := os.Mkdir(filepath.Join(dir, "sessions"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "sessions", "a.jsonl"), []byte("session"), 0644); err != nil {
		t.Fatal(err)
	}
	var archive bytes.Buffer
	if err := archiveOutput(dir, &archive); err != nil {
		t.Fatal(err)
	}
	dest := t.TempDir()
	if err := extractOutput(dest, &archive, 1024*1024); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dest, "sessions", "a.jsonl"))
	if err != nil || string(data) != "session" {
		t.Fatalf("got %q: %v", data, err)
	}
	if err := os.Symlink("/etc/passwd", filepath.Join(dir, "escape")); err != nil {
		t.Fatal(err)
	}
	archive.Reset()
	if err := archiveOutput(dir, &archive); err == nil {
		t.Fatal("accepted symlink")
	}
}
