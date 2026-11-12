package jobs

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestHistory(t *testing.T) {
	store := Store{Directory: t.TempDir()}
	at := func(ms int64) time.Time { return time.UnixMilli(ms).UTC() }
	runs := []Run{
		{ID: "a", Job: "alpha", Status: "failed", StartedAt: at(0), FinishedAt: at(100)},
		{ID: "b", Job: "beta", Status: "timed_out", StartedAt: at(200), FinishedAt: at(300)},
		{ID: "c", Job: "alpha-extra", Status: "success", StartedAt: at(120), FinishedAt: at(150)},
		{ID: "d", Job: "alpha", Status: "running", StartedAt: at(130)},
		{ID: "e", Job: "alpha", Status: "success", StartedAt: at(301), FinishedAt: at(400)},
	}

	for _, run := range runs {
		if err := os.MkdirAll(filepath.Join(store.Directory, run.Job, run.ID), 0750); err != nil {
			t.Fatal(err)
		}
		if err := store.Save(run); err != nil {
			t.Fatal(err)
		}
	}

	handler := NewHistory(store)
	tests := []struct {
		name, query string
		want        []historyRun
	}{
		{"inclusive boundaries and order", "from=100&to=200", []historyRun{{"alpha", "failed", at(0), at(100)}, {"alpha-extra", "success", at(120), at(150)}, {"beta", "timed_out", at(200), at(300)}}},
		{"full name regex", "from=100&to=200&job=" + url.QueryEscape("alpha|beta"), []historyRun{{"alpha", "failed", at(0), at(100)}, {"beta", "timed_out", at(200), at(300)}}},
		{"empty", "from=500&to=600", []historyRun{}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/runs?"+tt.query, nil))
			if w.Code != http.StatusOK {
				t.Fatalf("status %d: %s", w.Code, w.Body.String())
			}
			var got []historyRun
			if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %#v want %#v", got, tt.want)
			}
			if strings.Contains(w.Body.String(), "error") {
				t.Fatal("unexpected error field")
			}
		})
	}

	for _, query := range []string{"", "from=x&to=1", "from=1", "from=2&to=1", "from=1&to=2&job=%5B"} {
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/runs?"+query, nil))
		if w.Code != http.StatusBadRequest || w.Body.Len() != 0 {
			t.Errorf("query %q: %d %q", query, w.Code, w.Body.String())
		}
	}

	for _, tc := range []struct {
		method, path string
		status       int
	}{{"POST", "/runs", 405}, {"HEAD", "/runs", 405}, {"GET", "/", 404}, {"GET", "/api/runs", 404}} {
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, httptest.NewRequest(tc.method, tc.path, nil))
		if w.Code != tc.status || w.Body.Len() != 0 {
			t.Errorf("%s %s: %d %q", tc.method, tc.path, w.Code, w.Body.String())
		}
	}

	w := httptest.NewRecorder()
	missing := NewHistory(Store{Directory: filepath.Join(t.TempDir(), "missing")})
	missing.ServeHTTP(w, httptest.NewRequest("GET", "/runs?from=0&to=1", nil))
	if w.Code != 500 || w.Body.Len() != 0 {
		t.Errorf("read failure: %d %q", w.Code, w.Body.String())
	}
}
