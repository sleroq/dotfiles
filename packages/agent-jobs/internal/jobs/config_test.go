package jobs

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestLoadJobCredentialPaths(t *testing.T) {
	job := Job{
		Name: "fixture", Repository: "owner/repo", Branch: "automation/fixture",
		Image: "image", Network: "network", PiCommand: []string{"pi"}, Prompt: "$CREDENTIALS_DIRECTORY/prompt",
		TimeoutSeconds: 1, MemoryMB: 1, CPUs: 1, PIDs: 1, WorkspaceMB: 1, OutputMB: 1,
		EnvironmentFiles: map[string]string{"TOKEN": "$CREDENTIALS_DIRECTORY/env-TOKEN", "OTHER": "/absolute/$CREDENTIALS_DIRECTORY/file"},
		Files:            map[string]string{"file": "$CREDENTIALS_DIRECTORY/file-file"},
		ReadTokenFile:    "$CREDENTIALS_DIRECTORY/read-token",
		Publish:          Publication{PrivateKeyFile: "$CREDENTIALS_DIRECTORY/private-key"},
	}
	data, err := json.Marshal(job)
	if err != nil {
		t.Fatal(err)
	}
	filename := filepath.Join(t.TempDir(), "job.json")
	if err := os.WriteFile(filename, data, 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("CREDENTIALS_DIRECTORY", "/run/credentials/retry.service")
	loaded, err := LoadJob(filename)
	if err != nil {
		t.Fatal(err)
	}
	job.EnvironmentFiles["TOKEN"] = "/run/credentials/retry.service/env-TOKEN"
	job.Files["file"] = "/run/credentials/retry.service/file-file"
	job.ReadTokenFile = "/run/credentials/retry.service/read-token"
	job.Publish.PrivateKeyFile = "/run/credentials/retry.service/private-key"
	if !reflect.DeepEqual(loaded, job) {
		t.Fatalf("unexpected job: %+v", loaded)
	}
	t.Setenv("CREDENTIALS_DIRECTORY", "")
	if _, err := LoadJob(filename); err == nil {
		t.Fatalf("expected missing credential directory error, got %v", err)
	}
}
