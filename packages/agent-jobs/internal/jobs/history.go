package jobs

import (
	"encoding/json"
	"net/http"
	"regexp"
	"slices"
	"strconv"
	"time"
)

type historyRun struct {
	Job    string    `json:"job"`
	Status string    `json:"status"`
	Start  time.Time `json:"start"`
	End    time.Time `json:"end"`
}

func NewHistory(store Store) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/runs" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if r.Method != http.MethodGet {
			w.Header().Set("Allow", "GET")
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		query := r.URL.Query()
		from, errFrom := strconv.ParseInt(query.Get("from"), 10, 64)
		to, errTo := strconv.ParseInt(query.Get("to"), 10, 64)
		if errFrom != nil || errTo != nil || from > to {
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		var job *regexp.Regexp
		if pattern := query.Get("job"); pattern != "" {
			var err error
			job, err = regexp.Compile("^(?:" + pattern + ")$")
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}
		}

		runs, err := store.List()
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		start, end := time.UnixMilli(from), time.UnixMilli(to)
		result := []historyRun{}
		for _, run := range runs {
			if run.Status == "running" || run.FinishedAt.IsZero() || run.StartedAt.After(end) || run.FinishedAt.Before(start) || (job != nil && !job.MatchString(run.Job)) {
				continue
			}
			result = append(result, historyRun{run.Job, run.Status, run.StartedAt, run.FinishedAt})
		}

		slices.SortFunc(result, func(a, b historyRun) int { return a.Start.Compare(b.Start) })
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(result)
	})
}
