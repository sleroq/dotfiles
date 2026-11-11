package jobs

import (
	"embed"
	"encoding/json"
	"errors"
	"html/template"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"slices"
	"sort"
	"strconv"
	"strings"
	"time"
)

//go:embed web/*
var viewerAssets embed.FS

type viewer struct {
	store     Store
	templates *template.Template
}
type page struct {
	Title               string
	Runs                []Run
	Run                 Run
	Jobs                []string
	Job, Status         string
	Limit, Offset, Next int
	HasNext             bool
	Sessions, Artifacts []string
	Session             string
	Artifact, Content   string
}

var artifactNames = []string{"stdout.log", "stderr.log", "output/candidate.patch", prBodyArtifact, "output/validation.log", "output/result.json"}

func NewViewer(store Store) (http.Handler, error) {
	t, err := template.New("viewer").Funcs(template.FuncMap{"query": url.QueryEscape}).ParseFS(viewerAssets, "web/*.html")
	if err != nil {
		return nil, err
	}
	return &viewer{store: store, templates: t}, nil
}
func (v *viewer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	csp := "default-src 'self'; script-src 'none'; object-src 'none'; frame-ancestors 'none'"
	w.Header().Set("Content-Security-Policy", csp)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Cache-Control", "no-store")
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		w.Header().Set("Allow", "GET, HEAD")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if r.URL.Path == "/assets/style.css" {
		b, _ := viewerAssets.ReadFile("web/style.css")
		w.Header().Set("Content-Type", "text/css; charset=utf-8")
		_, _ = w.Write(b)
		return
	}
	api := strings.HasPrefix(r.URL.Path, "/api/")
	path := strings.TrimPrefix(r.URL.Path, "/")
	if api {
		path = strings.TrimPrefix(path, "api/")
	}
	if path == "" && !api || api && path == "runs" {
		v.list(w, r, api)
		return
	}
	if api && path == "jobs" {
		runs, err := v.store.List()
		if err != nil {
			v.fail(w, err)
			return
		}
		writeJSON(w, jobNames(runs))
		return
	}
	v.runRoute(w, r, strings.Split(path, "/"), api)
}

func (v *viewer) runRoute(w http.ResponseWriter, r *http.Request, parts []string, api bool) {
	if len(parts) < 4 || parts[0] != "jobs" || parts[2] != "runs" {
		http.NotFound(w, r)
		return
	}
	job, id := parts[1], parts[3]
	if !Identifier(job) || !Identifier(id) {
		http.Error(w, "invalid identifier", http.StatusBadRequest)
		return
	}
	run, err := v.store.Get(job, id)
	if err != nil {
		v.fail(w, err)
		return
	}
	if len(parts) == 4 {
		if api {
			writeJSON(w, run)
		} else {
			v.detail(w, run)
		}
		return
	}

	switch parts[4] {
	case "sessions":
		v.sessionRoute(w, r, run, parts[5:], api)
	case "artifacts":
		v.artifactRoute(w, r, run, parts[5:], api)
	default:
		http.NotFound(w, r)
	}
}

func (v *viewer) sessionRoute(w http.ResponseWriter, r *http.Request, run Run, parts []string, api bool) {
	if len(parts) == 0 && api {
		names, err := v.store.sessions(run.Job, run.ID)
		if err != nil {
			v.fail(w, err)
			return
		}
		writeJSON(w, names)
		return
	}
	if len(parts) != 1 {
		http.NotFound(w, r)
		return
	}
	name := parts[0]
	if !sessionName(name) {
		http.Error(w, "invalid session name", http.StatusBadRequest)
		return
	}
	if api {
		v.serveFile(w, r, run, "output/sessions/"+name, "application/x-ndjson; charset=utf-8")
		return
	}
	v.sessionHTML(w, r, run, name)
}

func (v *viewer) sessionHTML(w http.ResponseWriter, r *http.Request, run Run, name string) {
	file, err := v.store.Open(run.Job, run.ID, "session-html/"+name+".html")
	if err == nil {
		defer func() { _ = file.Close() }()
		csp := "sandbox allow-scripts; default-src 'none'; script-src 'unsafe-inline'; " +
			"style-src 'unsafe-inline'; img-src data:; connect-src 'none'; " +
			"object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
		w.Header().Set("Content-Security-Policy", csp)
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		http.ServeContent(w, r, name+".html", time.Time{}, file)
		return
	}
	if !errors.Is(err, os.ErrNotExist) {
		v.fail(w, err)
		return
	}
	raw, err := v.store.Open(run.Job, run.ID, "output/sessions/"+name)
	if err != nil {
		v.fail(w, err)
		return
	}
	_ = raw.Close()
	v.render(w, "session.html", page{Title: name, Run: run, Session: name})
}

func (v *viewer) artifactRoute(w http.ResponseWriter, r *http.Request, run Run, parts []string, api bool) {
	name := strings.Join(parts, "/")
	if !slices.Contains(artifactNames, name) {
		http.NotFound(w, r)
		return
	}
	if api {
		v.serveFile(w, r, run, name, "text/plain; charset=utf-8")
		return
	}
	data, err := v.store.Read(run.Job, run.ID, name)
	if err != nil {
		v.fail(w, err)
		return
	}
	p := page{Title: name, Run: run, Artifact: name, Content: string(data)}
	v.render(w, "artifact.html", p)
}
func (v *viewer) serveFile(w http.ResponseWriter, r *http.Request, run Run, name, contentType string) {
	file, err := v.store.Open(run.Job, run.ID, name)
	if err != nil {
		v.fail(w, err)
		return
	}
	defer func() { _ = file.Close() }()
	w.Header().Set("Content-Type", contentType)
	http.ServeContent(w, r, name, time.Time{}, file)
}

func jobNames(runs []Run) []string {
	m := map[string]bool{}
	for _, r := range runs {
		m[r.Job] = true
	}
	names := make([]string, 0, len(m))
	for n := range m {
		names = append(names, n)
	}
	sort.Strings(names)
	return names
}

type runFilter struct {
	job, status   string
	limit, offset int
}

func parseRunFilter(q url.Values) (runFilter, error) {
	filter := runFilter{job: q.Get("job"), status: q.Get("status"), limit: 50}
	if filter.job != "" && !Identifier(filter.job) || filter.status != "" && !Identifier(filter.status) {
		return filter, errors.New("invalid filter")
	}
	if q.Has("limit") {
		limit, err := strconv.Atoi(q.Get("limit"))
		if err != nil || limit < 1 || limit > 100 {
			return filter, errors.New("limit must be between 1 and 100")
		}
		filter.limit = limit
	}
	if q.Has("offset") {
		offset, err := strconv.Atoi(q.Get("offset"))
		if err != nil || offset < 0 || offset > 1000000 {
			return filter, errors.New("invalid offset")
		}
		filter.offset = offset
	}
	return filter, nil
}

func (v *viewer) list(w http.ResponseWriter, r *http.Request, api bool) {
	filter, err := parseRunFilter(r.URL.Query())
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	runs, err := v.store.List()
	if err != nil {
		v.fail(w, err)
		return
	}

	filtered := make([]Run, 0)
	for _, run := range runs {
		if (filter.job == "" || filter.job == run.Job) && (filter.status == "" || filter.status == run.Status) {
			filtered = append(filtered, run)
		}
	}
	start := min(filter.offset, len(filtered))
	end := min(start+filter.limit, len(filtered))
	selected := filtered[start:end]
	if api {
		writeJSON(w, selected)
		return
	}

	p := page{Title: "Runs", Runs: selected, Jobs: jobNames(runs), Job: filter.job, Status: filter.status,
		Limit: filter.limit, Offset: filter.offset, Next: filter.offset + filter.limit, HasNext: end < len(filtered)}
	v.render(w, "index.html", p)
}
func (v *viewer) detail(w http.ResponseWriter, run Run) {
	sessions, err := v.store.sessions(run.Job, run.ID)
	if err != nil {
		v.fail(w, err)
		return
	}
	artifacts := []string{}
	for _, name := range artifactNames {
		file, err := v.store.Open(run.Job, run.ID, name)
		if err == nil {
			_ = file.Close()
			artifacts = append(artifacts, name)
		} else if !errors.Is(err, fs.ErrNotExist) && !errors.Is(err, fs.ErrPermission) {
			v.fail(w, err)
			return
		}
	}
	p := page{Title: run.ID, Run: run, Sessions: sessions, Artifacts: artifacts}
	v.render(w, "run.html", p)
}
func (v *viewer) render(w http.ResponseWriter, name string, p page) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_ = v.templates.ExecuteTemplate(w, name, p)
}
func (v *viewer) fail(w http.ResponseWriter, err error) {
	if errors.Is(err, errFileTooLarge) {
		http.Error(w, err.Error(), http.StatusRequestEntityTooLarge)
		return
	}
	if errors.Is(err, os.ErrNotExist) || errors.Is(err, os.ErrPermission) {
		http.NotFound(w, nil)
		return
	}
	http.Error(w, "unable to read run data", 500)
}
func writeJSON(w http.ResponseWriter, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(value)
}
