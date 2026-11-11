package jobs

import (
	"os"
	"strings"
)

func sessionName(name string) bool {
	return strings.HasSuffix(name, ".jsonl") && Identifier(strings.TrimSuffix(name, ".jsonl"))
}

func (s Store) sessions(job, run string) ([]string, error) {
	root, err := s.runFiles(job, run, "output", "sessions")
	if os.IsNotExist(err) {
		return []string{}, nil
	}
	if err != nil {
		return nil, err
	}
	defer func() { _ = root.Close() }()
	dir, err := root.Open(".")
	if err != nil {
		return nil, err
	}
	defer func() { _ = dir.Close() }()
	entries, err := dir.ReadDir(-1)
	if err != nil {
		return nil, err
	}
	names := []string{}
	for _, entry := range entries {
		if sessionName(entry.Name()) && entry.Type().IsRegular() {
			names = append(names, entry.Name())
		}
	}
	return names, nil
}
