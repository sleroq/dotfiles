package jobs

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func fixture(t *testing.T) (Store, http.Handler, Run) {
	t.Helper()
	s := Store{Directory: t.TempDir()}
	run := Run{ID: "run-1", Job: "job_1", Status: "success", Phase: "validate", Model: "test", StartedAt: time.Now()}
	dir := filepath.Join(s.Directory, run.Job, run.ID)
	if err := os.MkdirAll(filepath.Join(dir, "output", "sessions"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := s.Save(run); err != nil {
		t.Fatal(err)
	}
	put := func(name, content string) {
		t.Helper()
		if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0644); err != nil {
			t.Fatal(err)
		}
	}
	put("stdout.log", "<script>alert(1)</script>")
	session := `{"type":"message","message":{"role":"user","content":"<script>alert(1)</script>"}}
{bad}
{"type":`
	put("output/sessions/2025-01_test.jsonl", session)
	h, err := NewViewer(s)
	if err != nil {
		t.Fatal(err)
	}
	return s, h, run
}
func request(h http.Handler, method, path string) *httptest.ResponseRecorder {
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest(method, path, nil))
	return w
}
func TestViewer(t *testing.T) {
	_, h, run := fixture(t)
	base := "/jobs/" + run.Job + "/runs/" + run.ID
	api := "/api" + base
	for _, path := range []string{"/", base, base + "/sessions/2025-01_test.jsonl", base + "/artifacts/stdout.log", "/api/jobs", "/api/runs?job=job_1&status=success&limit=1&offset=0", api, api + "/sessions", api + "/sessions/2025-01_test.jsonl", api + "/artifacts/stdout.log", "/assets/style.css"} {
		w := request(h, "GET", path)
		if w.Code != 200 {
			t.Errorf("%s: %d %s", path, w.Code, w.Body.String())
		}
		if w.Header().Get("Cache-Control") != "no-store" || !strings.Contains(w.Header().Get("Content-Security-Policy"), "script-src 'none'") {
			t.Error("missing security headers")
		}
	}

	for _, path := range []string{base + "/sessions/2025-01_test.jsonl", base + "/artifacts/stdout.log"} {
		body := request(h, "GET", path).Body.String()
		if strings.Contains(body, "<script>alert") || !strings.Contains(body, "&lt;script&gt;") {
			t.Errorf("unescaped content: %s", body)
		}
	}

	body := request(h, "GET", base+"/sessions/2025-01_test.jsonl").Body.String()
	if !strings.Contains(body, "invalid JSON") || !strings.Contains(body, "incomplete trailing entry") {
		t.Error(body)
	}

	var runs []Run
	if err := json.Unmarshal(request(h, "GET", "/api/runs?status=failed").Body.Bytes(), &runs); err != nil || len(runs) != 0 {
		t.Fatalf("filter: %v %v", runs, err)
	}

	for _, path := range []string{"/api/runs?limit=101", "/api/runs?offset=-1", api + "/sessions/bad.name.jsonl"} {
		if w := request(h, "GET", path); w.Code != 400 {
			t.Errorf("%s: %d", path, w.Code)
		}
	}
	for _, path := range []string{"/", api, api + "/artifacts/stdout.log"} {
		if w := request(h, "POST", path); w.Code != 405 || w.Header().Get("Allow") != "GET, HEAD" {
			t.Errorf("POST %s: %d", path, w.Code)
		}
	}
	if w := request(h, "HEAD", base); w.Code != 200 {
		t.Fatal(w.Code)
	}
	if w := request(h, "GET", api+"/artifacts/result.json"); w.Code != 404 {
		t.Fatal(w.Code)
	}
}
func TestViewerRejectsSymlinks(t *testing.T) {
	s, h, run := fixture(t)
	dir := filepath.Join(s.Directory, run.Job, run.ID)
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret.jsonl"), []byte("secret"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(outside, "secret.jsonl"), filepath.Join(dir, "output/sessions/secret.jsonl")); err != nil {
		t.Fatal(err)
	}
	base := "/api/jobs/" + run.Job + "/runs/" + run.ID
	if w := request(h, "GET", base+"/sessions/secret.jsonl"); w.Code != 404 {
		t.Fatal(w.Code)
	}
	if strings.Contains(request(h, "GET", base+"/sessions").Body.String(), "secret") {
		t.Fatal("listed symlink")
	}
	if err := os.RemoveAll(filepath.Join(dir, "output")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(dir, "output")); err != nil {
		t.Fatal(err)
	}
	if w := request(h, "GET", base+"/sessions/secret.jsonl"); w.Code != 404 {
		t.Fatal(w.Code)
	}
}

func TestViewerRejectsArtifactSymlinks(t *testing.T) {
	s, h, run := fixture(t)
	dir := filepath.Join(s.Directory, run.Job, run.ID)
	outside := filepath.Join(t.TempDir(), "secret")
	if err := os.WriteFile(outside, []byte("secret outside run"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(dir, "output", "candidate.patch")); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(dir, "stdout.log")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(dir, "stdout.log")); err != nil {
		t.Fatal(err)
	}
	base := "/jobs/" + run.Job + "/runs/" + run.ID
	for _, path := range []string{base + "/artifacts/stdout.log", "/api" + base + "/artifacts/output/candidate.patch"} {
		w := request(h, "GET", path)
		if w.Code != http.StatusNotFound || strings.Contains(w.Body.String(), "secret outside run") {
			t.Fatalf("%s: %d %s", path, w.Code, w.Body.String())
		}
	}
	if body := request(h, "GET", base).Body.String(); strings.Contains(body, "candidate.patch") || strings.Contains(body, "stdout.log") {
		t.Fatal("listed symlink artifact")
	}
}

func TestUnknownSessionEscaped(t *testing.T) {
	s, h, run := fixture(t)
	filename := filepath.Join(s.Directory, run.Job, run.ID, "output/sessions/unknown.jsonl")
	data := `{"type":"extension_event","payload":"<script>alert(1)</script>"}` + "\n" + `{"type":`
	if err := os.WriteFile(filename, []byte(data), 0644); err != nil {
		t.Fatal(err)
	}
	path := "/jobs/" + run.Job + "/runs/" + run.ID + "/sessions/unknown.jsonl"
	body := request(h, "GET", path).Body.String()
	if !strings.Contains(body, "extension_event") || !strings.Contains(body, "payload") || !strings.Contains(body, "incomplete trailing entry") || strings.Contains(body, "<script>alert") {
		t.Fatal(body)
	}
}
