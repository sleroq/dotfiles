package jobs

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestInstallationTokenScopedAndSigned(t *testing.T) {

	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(t.TempDir(), "key.pem")
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})
	if err := os.WriteFile(file, keyPEM, 0600); err != nil {
		t.Fatal(err)
	}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" || r.URL.Path != "/app/installations/42/access_tokens" {
			t.Errorf("request %s %s", r.Method, r.URL.Path)
		}
		token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		parts := strings.Split(token, ".")
		if len(parts) != 3 {
			t.Errorf("invalid JWT")
			return
		}
		signature, err := base64.RawURLEncoding.DecodeString(parts[2])
		if err != nil {
			t.Error(err)
			return
		}
		hash := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
		if err := rsa.VerifyPKCS1v15(&key.PublicKey, crypto.SHA256, hash[:], signature); err != nil {
			t.Error(err)
		}

		payload, err := base64.RawURLEncoding.DecodeString(parts[1])
		if err != nil {
			t.Error(err)
			return
		}
		var claims struct {
			Iss string `json:"iss"`
			Iat int64  `json:"iat"`
			Exp int64  `json:"exp"`
		}
		if err := json.Unmarshal(payload, &claims); err != nil || claims.Iss != "123" || claims.Exp-claims.Iat > 600 {
			t.Errorf("claims %s: %v", payload, err)
		}

		var body struct {
			Repositories []string          `json:"repositories"`
			Permissions  map[string]string `json:"permissions"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Error(err)
		}
		if len(body.Repositories) != 1 || body.Repositories[0] != "repo" || len(body.Permissions) != 2 || body.Permissions["contents"] != "write" || body.Permissions["pull_requests"] != "write" {
			t.Errorf("scope: %+v", body)
		}
		_, _ = w.Write([]byte(`{"token":"installation-secret"}`))
	}))
	defer server.Close()

	client := githubClient{baseURL: server.URL, client: server.Client()}
	job := Job{Repository: "owner/repo", Publish: Publication{AppID: "123", InstallationID: "42", PrivateKeyFile: file}}
	token, err := client.installationToken(context.Background(), job)
	if err != nil || token != "installation-secret" {
		t.Fatalf("token %q: %v", token, err)
	}
}

func TestPublishUsesStableBranchAndRevokesToken(t *testing.T) {
	g, source := gitTestRepo(t)
	ctx := context.Background()
	if err := os.WriteFile(filepath.Join(source, "allowed.txt"), []byte("old\n"), 0644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"add", "allowed.txt"}, {"-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "initial"}} {
		if _, err := g.run(ctx, source, args...); err != nil {
			t.Fatal(err)
		}
	}
	base, err := g.run(ctx, source, "rev-parse", "HEAD")
	if err != nil {
		t.Fatal(err)
	}

	bare := filepath.Join(t.TempDir(), "remote.git")
	if _, err := g.run(ctx, "", "clone", "--bare", source, bare); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(source, "allowed.txt"), []byte("new\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := g.run(ctx, source, "add", "allowed.txt"); err != nil {
		t.Fatal(err)
	}

	patch, err := g.command(ctx, source, "diff", "--cached", "--binary").Output()
	if err != nil {
		t.Fatal(err)
	}
	patchFile := filepath.Join(t.TempDir(), "candidate.patch")
	if err := os.WriteFile(patchFile, patch, 0644); err != nil {
		t.Fatal(err)
	}

	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	keyFile := filepath.Join(t.TempDir(), "key")
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})
	if err := os.WriteFile(keyFile, keyPEM, 0600); err != nil {
		t.Fatal(err)
	}

	created, revoked, reviews := 0, 0, 0
	body := "Update the fixture content to **new**."

	server := httptest.NewServer(publicationHandler(t, &created, &revoked, &reviews, &body))
	defer server.Close()

	api := githubClient{baseURL: server.URL, client: server.Client()}
	job := Job{
		Name: "test", Repository: "owner/repo", CloneURL: bare, Branch: "automation/test",
		Publish: Publication{AppID: "123", InstallationID: "42", PrivateKeyFile: keyFile, Title: "Update", Reviewer: "reviewer"},
	}
	work := t.TempDir()
	branch, err := g.run(ctx, source, "symbolic-ref", "--short", "HEAD")
	if err != nil {
		t.Fatal(err)
	}

	absent := ""
	run := Run{ExpectedBranch: &absent}
	pr, publication, err := g.publish(ctx, job, work, base, branch, patchFile, body, api, run)
	if err != nil || publication != "published" || pr != "https://example.test/pr/7" {
		t.Fatalf("publish %q %q: %v", pr, publication, err)
	}

	first, err := g.run(ctx, bare, "rev-parse", "refs/heads/automation/test")
	if err != nil {
		t.Fatal(err)
	}

	body = "Keep the fixture content current without another commit."
	pr, publication, err = g.publish(ctx, job, work, base, "", patchFile, body, api, run)
	if err != nil || publication != "unchanged" || pr == "" {
		t.Fatalf("republish %q %q: %v", pr, publication, err)
	}

	second, err := g.run(ctx, bare, "rev-parse", "refs/heads/automation/test")
	if err != nil {
		t.Fatal(err)
	}
	if first != second || created != 1 || revoked != 2 || reviews != 2 {
		t.Fatalf("first=%s second=%s created=%d revoked=%d reviews=%d", first, second, created, revoked, reviews)
	}
	// A retry may accept an already-published tree even when the branch moved.
	stale := Run{ExistingPR: true, StartCommit: base}
	_, publication, err = g.publish(ctx, job, work, base, branch, patchFile, body, api, stale)
	if err != nil || publication != "unchanged" {
		t.Fatalf("retry identical tree: %q: %v", publication, err)
	}
	if err := os.WriteFile(filepath.Join(source, "allowed.txt"), []byte("different\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := g.run(ctx, source, "add", "allowed.txt"); err != nil {
		t.Fatal(err)
	}
	patch, err = g.command(ctx, source, "diff", "--cached", "--binary").Output()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(patchFile, patch, 0644); err != nil {
		t.Fatal(err)
	}
	if _, _, err := g.publish(ctx, job, work, base, branch, patchFile, body, api, stale); err == nil {
		t.Fatal("published over a moved branch")
	}
	// Both an absent snapshot and a different existing snapshot must reject a new tree.
	for _, expected := range []string{"", base} {
		if _, _, err := g.publish(ctx, job, work, base, branch, patchFile, body, api, Run{ExpectedBranch: &expected}); err == nil {
			t.Fatalf("published over changed branch with snapshot %q", expected)
		}
		got, err := g.run(ctx, bare, "rev-parse", "refs/heads/automation/test")
		if err != nil || got != first {
			t.Fatalf("branch changed: %s: %v", got, err)
		}
	}
	// An old branch that has not changed since preparation may be replaced.
	if _, err := g.run(ctx, bare, "update-ref", "refs/heads/automation/test", base); err != nil {
		t.Fatal(err)
	}
	_, publication, err = g.publish(ctx, job, work, base, branch, patchFile, body, api, Run{ExpectedBranch: &base})
	if err != nil || publication != "published" {
		t.Fatalf("publish over unchanged old branch: %q: %v", publication, err)
	}
}

func TestPullRequestDoesNotRequestReviewFromAuthor(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		pr := `{"number":27,"html_url":"https://example.test/pr/27","user":{"login":"owner"}}`
		switch {
		case r.Method == "GET" && r.URL.Path == "/repos/owner/repo/pulls":
			_, _ = w.Write([]byte("[" + pr + "]"))
		case r.Method == "PATCH" && r.URL.Path == "/repos/owner/repo/pulls/27":
			_, _ = w.Write([]byte(pr))
		default:
			t.Errorf("unexpected request %s %s", r.Method, r.URL.Path)
			w.WriteHeader(http.StatusUnprocessableEntity)
		}
	}))
	defer server.Close()

	api := githubClient{baseURL: server.URL, client: server.Client()}
	job := Job{Repository: "owner/repo", Branch: "automation/test", Publish: Publication{Reviewer: "Owner"}}
	pr, err := api.pullRequest(context.Background(), job, "secret", "main", "Update the fixture.")
	if err != nil || pr != "https://example.test/pr/27" {
		t.Fatalf("pull request %q: %v", pr, err)
	}
}

func publicationHandler(t *testing.T, created, revoked, reviews *int, expectedBody *string) http.Handler {
	t.Helper()
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if (r.Method == "POST" && r.URL.Path == "/repos/owner/repo/pulls") || (r.Method == "PATCH" && r.URL.Path == "/repos/owner/repo/pulls/7") {
			var body struct {
				Description string `json:"body"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Description != *expectedBody {
				t.Errorf("PR body %q, want %q: %v", body.Description, *expectedBody, err)
			}
		}

		switch {
		case r.URL.Path == "/app/installations/42/access_tokens":
			_, _ = w.Write([]byte(`{"token":"secret"}`))
		case r.URL.Path == "/installation/token" && r.Method == "DELETE":
			(*revoked)++
			w.WriteHeader(204)
		case r.URL.Path == "/repos/owner/repo/pulls" && r.Method == "GET":
			if r.URL.Query().Get("head") != "owner:automation/test" || r.URL.Query().Get("state") != "open" {
				t.Errorf("PR query %s", r.URL.RawQuery)
			}
			if *created == 0 {
				_, _ = w.Write([]byte(`[]`))
			} else {
				_, _ = w.Write([]byte(`[{"number":7,"html_url":"https://example.test/pr/7"}]`))
			}
		case r.URL.Path == "/repos/owner/repo/pulls" && r.Method == "POST":
			(*created)++
			_, _ = w.Write([]byte(`{"number":7,"html_url":"https://example.test/pr/7"}`))
		case r.URL.Path == "/repos/owner/repo/pulls/7" && r.Method == "PATCH":
			_, _ = w.Write([]byte(`{"number":7,"html_url":"https://example.test/pr/7"}`))
		case r.URL.Path == "/repos/owner/repo/pulls/7/requested_reviewers":
			(*reviews)++
			w.WriteHeader(201)
		default:
			t.Errorf("unexpected request %s %s", r.Method, r.URL)
			w.WriteHeader(404)
		}
	})
}

func TestPullRequestReconcilesLostCreateResponse(t *testing.T) {
	created, reviews, updates := 0, 0, 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		pr := `{"number":7,"html_url":"https://example.test/pr/7","user":{"login":"author"}}`
		switch {
		case r.Method == "GET" && r.URL.Path == "/repos/owner/repo/pulls":
			if r.URL.Query().Get("head") != "owner:automation/test" || r.URL.Query().Get("base") != "main" || r.URL.Query().Get("state") != "open" {
				t.Errorf("unexpected query: %s", r.URL.RawQuery)
			}
			if created == 0 {
				_, _ = w.Write([]byte(`[]`))
			} else {
				_, _ = w.Write([]byte("[" + pr + "]"))
			}
		case r.Method == "POST" && r.URL.Path == "/repos/owner/repo/pulls":
			created++
			conn, _, err := w.(http.Hijacker).Hijack()
			if err != nil {
				t.Error(err)
				return
			}
			_ = conn.Close()
		case r.Method == "PATCH" && r.URL.Path == "/repos/owner/repo/pulls/7":
			updates++
			var body struct {
				Title string `json:"title"`
				Body  string `json:"body"`
				Head  string `json:"head"`
				Base  string `json:"base"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Title != "Update" || body.Body != "Description" || body.Head != "" || body.Base != "" {
				t.Errorf("update body %+v: %v", body, err)
			}
			_, _ = w.Write([]byte(pr))
		case r.Method == "POST" && r.URL.Path == "/repos/owner/repo/pulls/7/requested_reviewers":
			reviews++
			var body struct {
				Reviewers []string `json:"reviewers"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil || len(body.Reviewers) != 1 || body.Reviewers[0] != "reviewer" {
				t.Errorf("reviewers %+v: %v", body, err)
			}
			w.WriteHeader(http.StatusCreated)
		default:
			t.Errorf("unexpected request %s %s", r.Method, r.URL)
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer server.Close()

	api := githubClient{baseURL: server.URL, client: server.Client()}
	job := Job{
		Repository: "owner/repo", Branch: "automation/test",
		Publish: Publication{Title: "Update", Reviewer: "reviewer"},
	}
	pr, err := api.pullRequest(context.Background(), job, "secret", "main", "Description")
	if err != nil || pr != "https://example.test/pr/7" || created != 1 || updates != 1 || reviews != 1 {
		t.Fatalf("pr=%q error=%v created=%d updates=%d reviews=%d", pr, err, created, updates, reviews)
	}
}

func TestPullRequestCreateFailureWithoutMatch(t *testing.T) {
	created, lookups := 0, 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			lookups++
			_, _ = w.Write([]byte(`[]`))
		case http.MethodPost:
			created++
			w.WriteHeader(http.StatusUnprocessableEntity)
		default:
			t.Errorf("unexpected request %s", r.Method)
		}
	}))
	defer server.Close()

	api := githubClient{baseURL: server.URL, client: server.Client()}
	job := Job{Repository: "owner/repo", Branch: "test"}
	_, err := api.pullRequest(context.Background(), job, "secret", "main", "Description")
	if err == nil || created != 1 || lookups != 2 {
		t.Fatalf("error=%v created=%d lookups=%d", err, created, lookups)
	}
}

func TestPullRequestRetriesTransientCreateAfterLookup(t *testing.T) {
	created, lookups := 0, 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			lookups++
			_, _ = w.Write([]byte(`[]`))
		case http.MethodPost:
			created++
			if created == 1 {
				w.WriteHeader(http.StatusServiceUnavailable)
				return
			}
			if lookups != 2 {
				t.Errorf("retry occurred after %d lookups", lookups)
			}
			_, _ = w.Write([]byte(`{"number":7,"html_url":"https://example.test/pr/7"}`))
		default:
			t.Errorf("unexpected request %s", r.Method)
		}
	}))
	defer server.Close()

	api := githubClient{baseURL: server.URL, client: server.Client()}
	job := Job{Repository: "owner/repo", Branch: "test"}
	pr, err := api.pullRequest(context.Background(), job, "secret", "main", "Description")
	if err != nil || pr != "https://example.test/pr/7" || created != 2 || lookups != 2 {
		t.Fatalf("pr=%q error=%v created=%d lookups=%d", pr, err, created, lookups)
	}
}
