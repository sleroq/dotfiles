package jobs

import (
	"archive/tar"
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestExtractOutput(t *testing.T) {
	tests := []struct {
		name      string
		header    tar.Header
		body      string
		limit     int64
		wantError bool
	}{
		{"file", tar.Header{Name: "output/nested/file", Mode: 0777, Typeflag: tar.TypeReg}, "hello", 5, false},
		{"traversal", tar.Header{Name: "output/../outside", Typeflag: tar.TypeReg}, "x", 5, true},
		{"outside root", tar.Header{Name: "other/file", Typeflag: tar.TypeReg}, "x", 5, true},
		{"symlink", tar.Header{Name: "output/link", Typeflag: tar.TypeSymlink, Linkname: "/etc"}, "", 5, true},
		{"hardlink", tar.Header{Name: "output/link", Typeflag: tar.TypeLink, Linkname: "file"}, "", 5, true},
		{"oversize", tar.Header{Name: "output/file", Typeflag: tar.TypeReg}, "hello", 4, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {

			var data bytes.Buffer
			writer := tar.NewWriter(&data)
			tt.header.Size = int64(len(tt.body))
			if err := writer.WriteHeader(&tt.header); err != nil {
				t.Fatal(err)
			}
			if _, err := writer.Write([]byte(tt.body)); err != nil {
				t.Fatal(err)
			}
			if err := writer.Close(); err != nil {
				t.Fatal(err)
			}

			dir := t.TempDir()
			err := extractOutput(dir, &data, tt.limit)
			if (err != nil) != tt.wantError {
				t.Fatalf("error = %v, wantError %v", err, tt.wantError)
			}
			if !tt.wantError {
				got, err := os.ReadFile(filepath.Join(dir, "nested/file"))
				if err != nil || string(got) != tt.body {
					t.Fatalf("contents = %q, error = %v", got, err)
				}
			}
		})
	}
}

func TestContainerRestrictionsAndCleanup(t *testing.T) {
	dir := t.TempDir()
	fake := filepath.Join(dir, "docker")
	calls := filepath.Join(dir, "calls")
	archive := filepath.Join(dir, "output.tar")

	var data bytes.Buffer
	tw := tar.NewWriter(&data)
	if err := tw.WriteHeader(&tar.Header{Name: "output/candidate.patch", Typeflag: tar.TypeReg, Mode: 0644, Size: 1}); err != nil {
		t.Fatal(err)
	}
	if _, err := tw.Write([]byte("x")); err != nil {
		t.Fatal(err)
	}
	if err := tw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(archive, data.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}

	script := "#!/bin/sh\n" +
		"printf '%s\\n' \"$*\" >> '" + calls + "'\n" +
		"case \"$1\" in\nexec) if [ \"$4\" = archive ]; then cat '" + archive + "'; " +
		"else printf 'key=abc123'; fi ;;\nesac\n"
	if err := os.WriteFile(fake, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}

	if err := os.Symlink(fake, filepath.Join(dir, "chown")); err != nil {
		t.Fatal(err)
	}
	mountCalls := filepath.Join(dir, "mountpoint-calls")
	mountScript := "#!/bin/sh\nprintf '%s\\n' \"$*\" > '" + mountCalls + "'\n"
	if err := os.WriteFile(filepath.Join(dir, "mountpoint"), []byte(mountScript), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+":"+os.Getenv("PATH"))
	input := filepath.Join(dir, "input")
	output := filepath.Join(dir, "out")
	if err := os.Mkdir(input, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(output, 0755); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	out := &boundedWriter{writer: &stdout, remaining: 1024}
	errOut := &boundedWriter{writer: &stderr, remaining: 1024}
	duration := 0.0
	job := Job{
		Name: "fixture", Network: "agentjobs", Image: "sandbox", CPUs: 2,
		MemoryMB: 128, PIDs: 20, WorkspaceMB: 64, OutputMB: 1,
	}
	if err := runContainer(context.Background(), job, "test-id", input, output, out, errOut, 4096, &duration); err != nil {
		t.Fatal(err)
	}

	args, err := os.ReadFile(calls)
	if err != nil {
		t.Fatal(err)
	}
	text := string(args)
	mountArgs, err := os.ReadFile(mountCalls)
	if err != nil || string(mountArgs) != "-q /var/lib/agent-jobs-work/fixture/nix\n" {
		t.Fatalf("mountpoint args %q: %v", mountArgs, err)
	}
	required := []string{
		"create --name agent-jobs-test-id-source --pull=never --network none --entrypoint /bin/agent-jobs sandbox hold",
		"cp --archive agent-jobs-test-id-source:/nix/. /var/lib/agent-jobs-work/fixture/nix",
		"--recursive --no-dereference 1000:1000 /var/lib/agent-jobs-work/fixture/nix",
		"rm -f agent-jobs-test-id-source", "--runtime=runsc", "--network agentjobs",
		"run --detach --pull=never", "--read-only", "--cap-drop ALL", "--security-opt no-new-privileges", "--user 1000:1000",
		"--memory-swap 128m", "type=bind,src=/var/lib/agent-jobs-work/fixture/nix,dst=/nix",
		"dst=/input,readonly", "src=" + filepath.Join(input, "resolv.conf") + ",dst=/etc/resolv.conf,readonly", "rm -f agent-jobs-test-id",
	}
	for _, item := range required {
		if !strings.Contains(text, item) {
			t.Errorf("missing %q in %s", item, text)
		}
	}
	if strings.Contains(text, "type=volume") || strings.Contains(text, "src=/nix/store") || strings.Contains(text, "docker.sock") {
		t.Fatalf("unexpected host store or socket mount: %s", text)
	}
	if strings.Index(text, "rm -f agent-jobs-test-id-source") > strings.Index(text, "run --detach") {
		t.Fatalf("source container removed after sandbox started: %s", text)
	}
	if strings.Contains(text, "abc123") {
		t.Fatalf("secret passed via docker args: %q", text)
	}
	if _, err := os.Stat(filepath.Join(output, "candidate.patch")); err != nil {
		t.Fatal(err)
	}
}

func TestTimeoutRetainsPartialOutput(t *testing.T) {
	dir := t.TempDir()

	var data bytes.Buffer
	writer := tar.NewWriter(&data)
	content := []byte("partial session\n")
	header := &tar.Header{
		Name: "output/sessions/partial.jsonl", Typeflag: tar.TypeReg, Mode: 0644, Size: int64(len(content)),
	}
	if err := writer.WriteHeader(header); err != nil {
		t.Fatal(err)
	}
	if _, err := writer.Write(content); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	archive := filepath.Join(dir, "partial.tar")
	if err := os.WriteFile(archive, data.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
	calls := filepath.Join(dir, "calls")

	script := "#!/bin/sh\n" +
		"printf '%s\\n' \"$*\" >> '" + calls + "'\n" +
		"case \"$1\" in\nexec) if [ \"$4\" = archive ]; then cat '" + archive + "'; " +
		"else exec sleep 30; fi ;;\nesac\n"
	if err := os.WriteFile(filepath.Join(dir, "docker"), []byte(script), 0755); err != nil {
		t.Fatal(err)
	}

	if err := os.Symlink(filepath.Join(dir, "docker"), filepath.Join(dir, "chown")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "mountpoint"), []byte("#!/bin/sh\nexit 0\n"), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+":"+os.Getenv("PATH"))
	output := filepath.Join(dir, "output")
	if err := os.Mkdir(output, 0755); err != nil {
		t.Fatal(err)
	}

	var out, stderr bytes.Buffer
	stdoutLog := &boundedWriter{writer: &out, remaining: 1024}
	stderrLog := &boundedWriter{writer: &stderr, remaining: 1024}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	job := Job{
		Name: "timeout", Network: "agentjobs", Image: "sandbox", CPUs: 1,
		MemoryMB: 128, PIDs: 10, WorkspaceMB: 64, OutputMB: 1,
	}
	var duration float64
	err := runContainer(ctx, job, "timeout", dir, output, stdoutLog, stderrLog, 4096, &duration)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("expected deadline, got %v", err)
	}

	got, err := os.ReadFile(filepath.Join(output, "sessions/partial.jsonl"))
	if err != nil || !bytes.Equal(got, content) {
		commands, _ := os.ReadFile(calls)
		t.Fatalf("partial session %q: %v; commands %s; run error %v", got, err, commands, ctx.Err())
	}

	commands, err := os.ReadFile(calls)
	if err != nil {
		t.Fatal(err)
	}
	text := string(commands)
	if !strings.Contains(text, "exec agent-jobs-timeout /bin/agent-jobs archive") || !strings.Contains(text, "rm -f agent-jobs-timeout-source") || !strings.Contains(text, "rm -f agent-jobs-timeout\n") {
		t.Fatalf("missing copy or cleanup: %s", text)
	}
}

func TestStageInputExcludesHostPublicationSecrets(t *testing.T) {
	dir := t.TempDir()
	checkout := filepath.Join(dir, "checkout")
	if err := os.Mkdir(checkout, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(checkout, "file"), []byte("source"), 0644); err != nil {
		t.Fatal(err)
	}
	credential := filepath.Join(dir, "credential")
	if err := os.WriteFile(credential, []byte("guest-key"), 0600); err != nil {
		t.Fatal(err)
	}

	job := Job{
		Name: "example", Prompt: "do work", PiCommand: []string{"pi"}, OutputMB: 4,
		EnvironmentFiles: map[string]string{"FUMO_PI_KEY": credential}, ReadTokenFile: "/private/read-token",
		Publish: Publication{PrivateKeyFile: "/private/app-key", AppID: "123"},
	}
	input, err := stageInput(context.Background(), dir, checkout, "", job, Run{})
	if err != nil {
		t.Fatal(err)
	}
	prompt, err := os.ReadFile(filepath.Join(input, "prompt"))
	if err != nil {
		t.Fatal(err)
	}
	for _, instruction := range []string{job.Prompt, "/output/pr-body.md", "one or two short sentences"} {
		if !strings.Contains(string(prompt), instruction) {
			t.Errorf("staged prompt is missing %q", instruction)
		}
	}

	resolver := filepath.Join(input, "resolv.conf")
	contents, err := os.ReadFile(resolver)
	if err != nil || string(contents) != "nameserver 1.1.1.1\n" {
		t.Fatalf("resolver %q: %v", contents, err)
	}
	info, err := os.Stat(resolver)
	if err != nil || info.Mode().Perm() != 0444 {
		t.Fatalf("resolver permissions: %v, %v", info, err)
	}

	data, err := os.ReadFile(filepath.Join(input, "job.json"))
	if err != nil {
		t.Fatal(err)
	}
	for _, forbidden := range []string{credential, "/private/read-token", "/private/app-key", "guest-key"} {
		if bytes.Contains(data, []byte(forbidden)) {
			t.Fatalf("config exposes %q: %s", forbidden, data)
		}
	}
	if !bytes.Contains(data, []byte("/input/env/FUMO_PI_KEY")) {
		t.Fatalf("missing guest credential mapping: %s", data)
	}
	staged, err := os.ReadFile(filepath.Join(input, "env/FUMO_PI_KEY"))
	if err != nil || string(staged) != "guest-key" {
		t.Fatalf("credential %q: %v", staged, err)
	}
}

func TestContainerFailsWhenNixStoreIsNotMounted(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "mountpoint"), []byte("#!/bin/sh\nexit 1\n"), 0755); err != nil {
		t.Fatal(err)
	}
	calls := filepath.Join(dir, "docker-called")
	script := "#!/bin/sh\ntouch '" + calls + "'\n"
	if err := os.WriteFile(filepath.Join(dir, "docker"), []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+":"+os.Getenv("PATH"))

	var out bytes.Buffer
	log := &boundedWriter{writer: &out, remaining: 1024}
	var duration float64
	err := runContainer(context.Background(), Job{Name: "fixture"}, "id", dir, dir, log, log, 4096, &duration)
	if err == nil {
		t.Fatalf("expected mount failure, got %v", err)
	}
	if _, err := os.Stat(calls); !os.IsNotExist(err) {
		t.Fatalf("docker called without a mounted store: %v", err)
	}
}

func TestFailedRunRetainsPhase(t *testing.T) {
	store := Store{Directory: t.TempDir()}
	job := Job{
		Name: "fixture", Repository: "owner/repo", Branch: "automation/fixture", Image: "sandbox", Network: "agentjobs", PiCommand: []string{"pi"}, Prompt: "prompt", TimeoutSeconds: 5,
		MemoryMB: 128, CPUs: 1, PIDs: 10, WorkspaceMB: 64, OutputMB: 1,
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := RunJob(ctx, job, store); err == nil {
		t.Fatal("expected canceled run to fail")
	}
	runs, err := store.List()
	if err != nil {
		t.Fatal(err)
	}
	if len(runs) != 1 || runs[0].Status != "failed" || runs[0].Phase != "prepare" {
		t.Fatalf("failed run metadata: %+v", runs)
	}
}

func TestPrepareOpenPR(t *testing.T) {
	ctx := context.Background()
	g, source := gitTestRepo(t)
	git := func(dir string, args ...string) string {
		t.Helper()
		out, err := g.run(ctx, dir, args...)
		if err != nil {
			t.Fatal(err)
		}
		return out
	}
	git(source, "branch", "-M", "main")
	base := git(source, "rev-parse", "HEAD")
	git(source, "checkout", "-b", "automation/test")
	git(source, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
		"commit", "--allow-empty", "-qm", "proposal")
	tip := git(source, "rev-parse", "HEAD")
	git(source, "checkout", "main")
	remote := filepath.Join(t.TempDir(), "remote.git")
	git("", "clone", "--bare", source, remote)
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	keyFile := filepath.Join(t.TempDir(), "key")
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})
	if err := os.WriteFile(keyFile, keyPEM, 0600); err != nil {
		t.Fatal(err)
	}

	for _, tc := range []struct {
		name, response          string
		status                  int
		move, wantPR, wantError bool
	}{
		{"open", fmt.Sprintf(`[{"head":{"sha":%q}}]`, tip), 200, false, true, false},
		{"none", `[]`, 200, false, false, false},
		{"lookup failure", ``, 403, false, false, true},
		{"api tip mismatch", fmt.Sprintf(`[{"head":{"sha":%q}}]`, base), 200, false, false, true},
		{"remote tip mismatch", fmt.Sprintf(`[{"head":{"sha":%q}}]`, tip), 200, true, false, true},
		{"invalid response", `[{"head":{}}]`, 200, false, false, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			git(remote, "update-ref", "refs/heads/automation/test", tip)
			checkout := filepath.Join(t.TempDir(), "checkout")
			job := Job{
				Repository: "owner/repo", Branch: "automation/test", CloneURL: remote,
				Publish: Publication{AppID: "1", InstallationID: "42", PrivateKeyFile: keyFile},
			}
			if _, err := g.checkout(ctx, job, checkout); err != nil {
				t.Fatal(err)
			}
			revoked := false
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
				switch {
				case req.Method == "POST" && req.URL.Path == "/app/installations/42/access_tokens":
					_, _ = fmt.Fprint(w, `{"token":"secret"}`)
				case req.Method == "GET" && req.URL.Path == "/repos/owner/repo/pulls":
					if req.URL.Query().Get("head") != "owner:automation/test" || req.URL.Query().Get("base") != "main" || req.URL.Query().Get("state") != "open" {
						t.Errorf("query: %s", req.URL.RawQuery)
					}
					if tc.move {
						git(remote, "update-ref", "refs/heads/automation/test", base)
					}
					w.WriteHeader(tc.status)
					_, _ = fmt.Fprint(w, tc.response)
				case req.Method == "DELETE" && req.URL.Path == "/installation/token":
					revoked = true
					w.WriteHeader(204)
				default:
					t.Errorf("unexpected request %s %s", req.Method, req.URL)
					w.WriteHeader(404)
				}
			}))
			defer server.Close()
			snapshot := tip
			if tc.move {
				snapshot = base
			}
			run := Run{BaseCommit: base, ExpectedBranch: &snapshot}
			r := jobRun{job: job, git: g, checkout: checkout, defaultBranch: "main", run: &run}
			err := r.prepareOpenPR(ctx, githubClient{baseURL: server.URL, client: server.Client()})
			if (err != nil) != tc.wantError {
				t.Fatalf("error: %v", err)
			}
			if !revoked {
				t.Error("token not revoked")
			}
			want := base
			if tc.wantPR {
				want = tip
			}
			if got := git(checkout, "rev-parse", "HEAD"); got != want {
				t.Errorf("HEAD = %s, want %s", got, want)
			}
			if !tc.wantError && (run.StartCommit != want || run.ExistingPR != tc.wantPR) {
				t.Errorf("run: %+v", run)
			}
		})
	}
}

func TestStageInputHistory(t *testing.T) {
	ctx := context.Background()
	g, source := gitTestRepo(t)
	git := func(dir string, args ...string) string {
		t.Helper()
		out, err := g.run(ctx, dir, args...)
		if err != nil {
			t.Fatal(err)
		}
		return out
	}
	git(source, "branch", "-M", "main")
	base := git(source, "rev-parse", "HEAD")
	git(source, "checkout", "-b", "automation/test")
	git(source, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
		"commit", "--allow-empty", "-qm", "proposal")
	tip := git(source, "rev-parse", "HEAD")
	git(source, "update-ref", "refs/remotes/origin/main", base)
	git(source, "update-ref", "refs/remotes/origin/automation/test", tip)
	git(source, "remote", "add", "origin", "https://user:credential-secret@example.invalid/repo")

	for _, existing := range []bool{false, true} {
		t.Run(fmt.Sprint(existing), func(t *testing.T) {
			work := t.TempDir()
			start := base
			if existing {
				start = tip
			}
			git(source, "checkout", "--detach", start)
			job := Job{Name: "fixture", Branch: "automation/test", Prompt: "do work", ReuseOpenPR: true}
			run := Run{BaseCommit: base, StartCommit: start, ExistingPR: existing}
			input, err := stageInput(ctx, work, source, "main", job, run)
			if err != nil {
				t.Fatal(err)
			}
			data, err := os.ReadFile(filepath.Join(input, "job.json"))
			if err != nil {
				t.Fatal(err)
			}
			var cfg sandboxConfig
			if err := json.Unmarshal(data, &cfg); err != nil {
				t.Fatal(err)
			}
			if !cfg.History || cfg.BaseCommit != base || cfg.StartCommit != start || cfg.ExistingPR != existing {
				t.Fatalf("config: %+v", cfg)
			}
			bundle := filepath.Join(input, "repository.bundle")
			bytes, err := os.ReadFile(bundle)
			if err != nil {
				t.Fatal(err)
			}
			if strings.Contains(string(bytes), "credential-secret") {
				t.Fatal("bundle contains credentials")
			}
			if _, err := os.Stat(filepath.Join(input, "repo", ".git")); !os.IsNotExist(err) {
				t.Fatalf("Git metadata staged: %v", err)
			}
			dest := t.TempDir()
			if err := cfg.prepareGit(ctx, g, dest, filepath.Join(input, "repo"), bundle); err != nil {
				t.Fatal(err)
			}
			if got := git(dest, "rev-parse", "HEAD"); got != start {
				t.Errorf("HEAD = %s", got)
			}
			if got := git(dest, "rev-parse", "refs/remotes/origin/main"); got != base {
				t.Errorf("base ref = %s", got)
			}
			if got := git(dest, "rev-parse", "refs/remotes/origin/automation/test"); got != tip {
				t.Errorf("PR ref = %s", got)
			}
			prompt, err := os.ReadFile(filepath.Join(input, "prompt"))
			if err != nil {
				t.Fatal(err)
			}
			for _, want := range []string{"refs/remotes/origin/main", base} {
				if !strings.Contains(string(prompt), want) {
					t.Errorf("prompt missing %q", want)
				}
			}
			if existing {
				for _, want := range []string{"automation/test", tip, "make no edits and do not rebase", "before editing", "stash"} {
					if !strings.Contains(string(prompt), want) {
						t.Errorf("prompt missing %q", want)
					}
				}
			} else if !strings.Contains(string(prompt), "No open PR exists") || strings.Contains(string(prompt), "stash") {
				t.Errorf("no PR prompt: %s", prompt)
			}
		})
	}
	cancelled, cancel := context.WithCancel(ctx)
	cancel()
	if _, err := stageInput(cancelled, t.TempDir(), source, "main", Job{ReuseOpenPR: true}, Run{}); err == nil {
		t.Fatal("canceled bundle creation succeeded")
	}
}

func TestPrepareCapturesPublicationBranch(t *testing.T) {
	ctx := context.Background()
	g, source := gitTestRepo(t)
	base, err := g.run(ctx, source, "rev-parse", "HEAD")
	if err != nil {
		t.Fatal(err)
	}

	remote := filepath.Join(t.TempDir(), "remote.git")
	if _, err := g.run(ctx, "", "clone", "--bare", source, remote); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		name            string
		publish, exists bool
	}{
		{"absent", true, false}, {"old branch", true, true}, {"disabled", false, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			ref := "refs/heads/automation/test"
			if tc.exists {
				if _, err := g.run(ctx, remote, "update-ref", ref, base); err != nil {
					t.Fatal(err)
				}
			} else if _, err := g.run(ctx, remote, "update-ref", "-d", ref); err != nil {
				t.Fatal(err)
			}
			store := Store{Directory: t.TempDir()}
			credential := filepath.Join(t.TempDir(), "token")
			if err := os.WriteFile(credential, []byte("private-token"), 0600); err != nil {
				t.Fatal(err)
			}
			job := Job{
				Name: "fixture", CloneURL: remote, Branch: "automation/test", ReadTokenFile: credential,
				Publish: Publication{Enabled: tc.publish},
			}
			run, err := store.Create(job)
			if err != nil {
				t.Fatal(err)
			}
			r := jobRun{job: job, store: store, run: &run, work: t.TempDir()}
			if err := r.prepare(ctx); err != nil {
				t.Fatal(err)
			}
			saved, err := store.Get(job.Name, run.ID)
			if err != nil {
				t.Fatal(err)
			}
			data, err := os.ReadFile(filepath.Join(store.Directory, run.Job, run.ID, "result.json"))
			if err != nil || strings.Contains(string(data), "private-token") {
				t.Fatalf("credential leaked into run metadata: %v", err)
			}

			if !tc.publish {
				if saved.ExpectedBranch != nil {
					t.Fatal("non-publish job captured branch")
				}
				return
			}
			want := ""
			if tc.exists {
				want = base
			}
			if saved.ExpectedBranch == nil || *saved.ExpectedBranch != want {
				t.Fatalf("snapshot = %v, want %q", saved.ExpectedBranch, want)
			}
			shallow, err := g.run(ctx, r.checkout, "rev-parse", "--is-shallow-repository")
			if err != nil || shallow != "true" {
				t.Fatalf("shallow = %q: %v", shallow, err)
			}
		})
	}
}
