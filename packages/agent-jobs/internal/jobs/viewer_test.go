package jobs

import (
	"crypto/sha256"
	"encoding/json"
	"io"
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
	run := Run{ID: "run-1", Job: "job_1", Status: "success", Phase: "sandbox", Model: "test", StartedAt: time.Now()}
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
	h, err := NewViewer(s, TimerInventory{})
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

	for _, path := range []string{base + "/artifacts/stdout.log"} {
		body := request(h, "GET", path).Body.String()
		if strings.Contains(body, "<script>alert") || !strings.Contains(body, "&lt;script&gt;") {
			t.Errorf("unescaped content: %s", body)
		}
	}

	body := request(h, "GET", base+"/sessions/2025-01_test.jsonl").Body.String()
	if !strings.Contains(body, "HTML session report unavailable") || !strings.Contains(body, "Raw JSONL") || strings.Contains(body, "<script>") {
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
func TestViewerLargeRawFiles(t *testing.T) {
	s, h, run := fixture(t)
	server := httptest.NewServer(h)
	defer server.Close()

	base := "/jobs/" + run.Job + "/runs/" + run.ID
	const size = (64 << 20) + 123
	for _, tc := range []struct {
		name, path, contentType string
	}{
		{"stdout.log", "/artifacts/stdout.log", "text/plain; charset=utf-8"},
		{"output/sessions/2025-01_test.jsonl", "/sessions/2025-01_test.jsonl", "application/x-ndjson; charset=utf-8"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			file, err := os.Create(filepath.Join(s.Directory, run.Job, run.ID, tc.name))
			if err != nil {
				t.Fatal(err)
			}
			if err := file.Truncate(size); err != nil {
				t.Fatal(err)
			}
			if _, err := file.WriteAt([]byte("end"), size-3); err != nil {
				t.Fatal(err)
			}
			if err := file.Close(); err != nil {
				t.Fatal(err)
			}

			original, err := os.Open(filepath.Join(s.Directory, run.Job, run.ID, tc.name))
			if err != nil {
				t.Fatal(err)
			}
			defer func() { _ = original.Close() }()
			want := sha256.New()
			if _, err := io.Copy(want, original); err != nil {
				t.Fatal(err)
			}

			resp, err := http.Get(server.URL + "/api" + base + tc.path)
			if err != nil {
				t.Fatal(err)
			}
			defer func() { _ = resp.Body.Close() }()
			got := sha256.New()
			n, err := io.Copy(got, resp.Body)
			if err != nil || resp.StatusCode != http.StatusOK || n != size || string(got.Sum(nil)) != string(want.Sum(nil)) || resp.Header.Get("Content-Type") != tc.contentType {
				t.Fatalf("GET: status=%d bytes=%d content-type=%q err=%v", resp.StatusCode, n, resp.Header.Get("Content-Type"), err)
			}

			head, err := http.Head(server.URL + "/api" + base + tc.path)
			if err != nil {
				t.Fatal(err)
			}
			defer func() { _ = head.Body.Close() }()
			body, err := io.ReadAll(head.Body)
			if err != nil || head.StatusCode != http.StatusOK || head.ContentLength != size || len(body) != 0 || head.Header.Get("Content-Type") != tc.contentType {
				t.Fatalf("HEAD: status=%d length=%d body=%d content-type=%q err=%v",
					head.StatusCode, head.ContentLength, len(body), head.Header.Get("Content-Type"), err)
			}

			rangeRequest := httptest.NewRequest(http.MethodGet, "/api"+base+tc.path, nil)
			rangeRequest.Header.Set("Range", "bytes=-3")
			w := httptest.NewRecorder()
			h.ServeHTTP(w, rangeRequest)
			if w.Code != http.StatusPartialContent || w.Body.String() != "end" {
				t.Fatalf("range: status=%d body=%q", w.Code, w.Body.String())
			}

			if w := request(h, http.MethodGet, base+tc.path); tc.name == "stdout.log" && w.Code != http.StatusRequestEntityTooLarge {
				t.Fatalf("HTML: status=%d body=%s", w.Code, w.Body.String())
			}
		})
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

func TestViewerTrustedSessionHTML(t *testing.T) {
	s, h, run := fixture(t)
	dir := filepath.Join(s.Directory, run.Job, run.ID)
	name := "2025-01_test.jsonl"
	path := "/jobs/" + run.Job + "/runs/" + run.ID + "/sessions/" + name
	if err := os.WriteFile(filepath.Join(dir, "output/sessions", name+".html"), []byte("malicious sandbox html"), 0644); err != nil {
		t.Fatal(err)
	}
	fallback := request(h, "GET", path)
	if strings.Contains(fallback.Body.String(), "malicious") || !strings.Contains(fallback.Body.String(), "Raw JSONL") {
		t.Fatal(fallback.Body.String())
	}
	if err := os.Mkdir(filepath.Join(dir, "session-html"), 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "session-html", name+".html"), []byte("<script>trusted report</script>"), 0640); err != nil {
		t.Fatal(err)
	}
	w := request(h, "GET", path)
	csp := w.Header().Get("Content-Security-Policy")
	for _, part := range []string{"sandbox allow-scripts", "default-src 'none'", "connect-src 'none'", "frame-ancestors 'none'"} {
		if !strings.Contains(csp, part) {
			t.Fatal(csp)
		}
	}
	if w.Body.String() != "<script>trusted report</script>" || w.Header().Get("Cache-Control") != "no-store" || w.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Fatal(w)
	}
}
