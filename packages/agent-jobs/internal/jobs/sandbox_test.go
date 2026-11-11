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

type historyCase struct {
	name                                                                                    string
	existing, advanced, rebase, change, commit, equalTree, wantEmpty, wantError, wantNoDiff bool
}

func TestHistoryCandidate(t *testing.T) {
	for _, tc := range []historyCase{
		{name: "existing unchanged", existing: true, wantEmpty: true},
		{name: "existing unchanged after base advances", existing: true, advanced: true, wantEmpty: true},
		{name: "incremental change preserves proposal", existing: true, change: true},
		{name: "advanced base requires rebase", existing: true, advanced: true, change: true, wantError: true},
		{name: "rebased proposal", existing: true, advanced: true, rebase: true, change: true},
		{name: "rebase changes head but not tree", existing: true, advanced: true, equalTree: true, wantError: true, wantNoDiff: true},
		{name: "changed head with equal tree still requires base", existing: true, advanced: true, equalTree: true, wantError: true},
		{name: "new proposal with committed change", commit: true},
		{name: "new proposal with uncommitted change", change: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			ctx := context.Background()
			git, source := gitTestRepo(t)
			run := func(dir string, args ...string) string {
				t.Helper()
				out, err := git.run(ctx, dir, args...)
				if err != nil {
					t.Fatalf("git %v: %v", args, err)
				}
				return out
			}

			write := func(dir, name, contents string) {
				t.Helper()
				if err := os.WriteFile(filepath.Join(dir, name), []byte(contents), 0644); err != nil {
					t.Fatal(err)
				}
			}

			commit := func(dir, message string) {
				t.Helper()
				run(dir, "add", "-A")
				run(dir, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", message)
			}
			base, start, bundle := historyBundle(t, tc, source, run, write, commit)

			workspace := t.TempDir()
			cfg := sandboxConfig{History: true, ExistingPR: tc.existing, BaseCommit: base, StartCommit: start, OutputMB: 1}
			if err := cfg.prepareGit(ctx, git, workspace, "", bundle); err != nil {
				t.Fatal(err)
			}
			if got := run(workspace, "rev-parse", "refs/remotes/origin/proposal"); got != start {
				t.Fatalf("missing proposal ref: %s", got)
			}
			if tc.rebase {
				run(workspace, "rebase", base)
			}
			if tc.equalTree {
				// A rewritten commit can retain the same tree while gaining the new base as parent.
				tree := run(workspace, "rev-parse", "HEAD^{tree}")
				parent := base
				if tc.wantError && !tc.wantNoDiff {
					parent = start
				}
				head := run(workspace, "commit-tree", tree, "-p", parent, "-m", "rebased")
				run(workspace, "checkout", "--detach", head)
			}
			if tc.change || tc.commit {
				write(workspace, "new", "new change\n")
			}
			if tc.commit {
				commit(workspace, "new change")
			}

			checkHistoryCandidate(t, tc, cfg, git, workspace, run)
		})
	}
}

func historyBundle(t *testing.T, tc historyCase, source string, run func(string, ...string) string, write func(string, string, string), commit func(string, string)) (base, start, bundle string) {
	t.Helper()
	base = run(source, "rev-parse", "HEAD")
	start = base
	if tc.existing {
		write(source, "proposal", "prior proposal\n")
		commit(source, "proposal")
		start = run(source, "rev-parse", "HEAD")
	}
	run(source, "update-ref", "refs/remotes/origin/proposal", start)
	if tc.advanced {
		run(source, "checkout", "--detach", base)
		if tc.equalTree {
			write(source, "proposal", "prior proposal\n")
		} else {
			write(source, "main", "advanced main\n")
		}
		commit(source, "advance base")
		base = run(source, "rev-parse", "HEAD")
		run(source, "update-ref", "refs/remotes/origin/main", base)
	}
	bundle = filepath.Join(t.TempDir(), "repository.bundle")
	run(source, "bundle", "create", bundle, "--all")
	return base, start, bundle
}

func checkHistoryCandidate(t *testing.T, tc historyCase, cfg sandboxConfig, git hostGit, workspace string, run func(string, ...string) string) {
	t.Helper()
	ctx := context.Background()
	base := cfg.BaseCommit
	patch := filepath.Join(t.TempDir(), "candidate.patch")
	err := cfg.writeCandidate(ctx, git, workspace, patch)
	if tc.wantError {
		if err == nil {
			t.Fatal("expected candidate error")
		}
		if tc.wantNoDiff && err.Error() != "existing PR now has no diff against the default base and needs operator attention" {
			t.Fatalf("expected no-diff error, got %v", err)
		}
		return
	}
	if err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(patch)
	if err != nil {
		t.Fatal(err)
	}
	if tc.wantEmpty {
		if len(data) != 0 {
			t.Fatalf("unexpected patch: %s", data)
		}
		return
	}
	if len(data) == 0 {
		t.Fatal("missing patch")
	}

	wantTree := run(workspace, "write-tree")
	run(workspace, "reset", "--hard", base)
	if len(data) > 0 {
		run(workspace, "apply", "--cached", "--binary", patch)
	}
	if got := run(workspace, "write-tree"); got != wantTree {
		t.Fatalf("candidate tree %s, want %s", got, wantTree)
	}
}

func TestHistoryCandidateRejectsUnfinishedConflict(t *testing.T) {
	ctx := context.Background()
	git, repo := gitTestRepo(t)
	run := func(args ...string) string {
		t.Helper()
		out, err := git.run(ctx, repo, args...)
		if err != nil {
			t.Fatalf("git %v: %v", args, err)
		}
		return out
	}
	write := func(contents string) {
		t.Helper()
		if err := os.WriteFile(filepath.Join(repo, "conflict"), []byte(contents), 0644); err != nil {
			t.Fatal(err)
		}
	}
	commit := func(message string) {
		t.Helper()
		run("add", "-A")
		run("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", message)
	}

	write("original\n")
	commit("original")
	base := run("rev-parse", "HEAD")
	write("proposal\n")
	commit("proposal")
	start := run("rev-parse", "HEAD")
	run("checkout", "--detach", base)
	write("main\n")
	commit("main")
	base = run("rev-parse", "HEAD")
	run("checkout", "--detach", start)
	if _, err := git.run(ctx, repo, "rebase", base); err == nil {
		t.Fatal("expected rebase conflict")
	}

	cfg := sandboxConfig{History: true, ExistingPR: true, BaseCommit: base, StartCommit: start, OutputMB: 1}
	patch := filepath.Join(t.TempDir(), "candidate.patch")
	check := func(want string) {
		t.Helper()
		if err := cfg.writeCandidate(ctx, git, repo, patch); err == nil || err.Error() != want {
			t.Fatalf("expected %q error, got %v", want, err)
		}
		if _, err := os.Stat(patch); !os.IsNotExist(err) {
			t.Fatalf("candidate patch exists or cannot be checked: %v", err)
		}
	}
	check("cannot write candidate while a rebase is in progress")
	if run("ls-files", "--unmerged") == "" {
		t.Fatal("candidate staged unresolved conflict")
	}
	write("resolved\n")
	run("add", "conflict")
	check("cannot write candidate while a rebase is in progress")
	run("rebase", "--abort")
	if _, err := git.run(ctx, repo, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "merge", base); err == nil {
		t.Fatal("expected merge conflict")
	}
	check("cannot write candidate with unresolved index entries")
	if run("ls-files", "--unmerged") == "" {
		t.Fatal("candidate staged unresolved merge conflict")
	}
}
