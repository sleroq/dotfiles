package jobs

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path"
	"regexp"
	"strings"
	"time"
)

// Job is trusted, administrator-owned configuration, never agent output.
type Job struct {
	Name             string            `json:"name"`
	Repository       string            `json:"repository"`
	CloneURL         string            `json:"clone_url,omitempty"`
	ReuseOpenPR      bool              `json:"reuse_open_pr,omitempty"`
	Branch           string            `json:"branch"`
	AllowedPaths     []string          `json:"allowed_paths"`
	Prompt           string            `json:"prompt"`
	Image            string            `json:"image"`
	Network          string            `json:"network"`
	PiCommand        []string          `json:"pi_command"`
	Model            string            `json:"model"`
	Thinking         string            `json:"thinking"`
	TimeoutSeconds   int               `json:"timeout_seconds"`
	MemoryMB         int               `json:"memory_mb"`
	CPUs             int               `json:"cpus"`
	PIDs             int               `json:"pids"`
	WorkspaceMB      int               `json:"workspace_mb"`
	OutputMB         int               `json:"output_mb"`
	EnvironmentFiles map[string]string `json:"environment_files,omitempty"`
	Files            map[string]string `json:"files,omitempty"`
	ReadTokenFile    string            `json:"read_token_file,omitempty"`
	Publish          Publication       `json:"publish"`
}

type Publication struct {
	Enabled        bool   `json:"enabled"`
	AppID          string `json:"app_id,omitempty"`
	InstallationID string `json:"installation_id,omitempty"`
	PrivateKeyFile string `json:"private_key_file,omitempty"`
	Title          string `json:"title"`
	Reviewer       string `json:"reviewer,omitempty"`
}

func LoadJob(filename string) (Job, error) {
	file, err := os.Open(filename)
	if err != nil {
		return Job{}, err
	}
	defer func() { _ = file.Close() }()
	var job Job
	decoder := json.NewDecoder(file)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&job); err != nil {
		return Job{}, fmt.Errorf("decode job: %w", err)
	}
	return job, job.Check()
}

func (j Job) Check() error {
	if err := j.checkScope(); err != nil {
		return err
	}
	if j.Image == "" || j.Network == "" || len(j.PiCommand) == 0 || j.Prompt == "" {
		return errors.New("image, network, pi_command, and prompt are required")
	}
	if j.TimeoutSeconds <= 0 || j.MemoryMB <= 0 || j.CPUs <= 0 || j.PIDs <= 0 || j.WorkspaceMB <= 0 || j.OutputMB <= 0 {
		return errors.New("timeout and resource limits must be positive")
	}

	for name := range j.EnvironmentFiles {
		if !Identifier(name) || strings.Contains(name, "-") {
			return fmt.Errorf("invalid environment name %q", name)
		}
	}
	for name := range j.Files {
		if !Identifier(name) {
			return fmt.Errorf("invalid credential filename %q", name)
		}
	}
	if j.ReuseOpenPR && !j.Publish.Enabled {
		return errors.New("reuse_open_pr requires publication")
	}
	if j.Publish.Enabled && (j.Publish.AppID == "" || j.Publish.InstallationID == "" || j.Publish.PrivateKeyFile == "") {
		return errors.New("publication requires app ID, installation ID, and private key file")
	}
	return nil
}

func (j Job) checkScope() error {
	if !Identifier(j.Name) {
		return errors.New("job name must contain only letters, digits, hyphens, and underscores")
	}

	parts := strings.Split(j.Repository, "/")
	if len(parts) != 2 || !Identifier(parts[0]) || !Identifier(strings.ReplaceAll(parts[1], ".", "_")) {
		return errors.New("repository must be owner/name")
	}
	if !strings.HasPrefix(j.Branch, "automation/") || strings.ContainsAny(j.Branch, "\x00\r\n ~^:?*[\\") || strings.Contains(j.Branch, "..") || strings.HasSuffix(j.Branch, "/") {
		return errors.New("publication branch must be a valid automation/ branch")
	}
	if len(j.AllowedPaths) == 0 {
		return errors.New("allowed_paths must not be empty")
	}

	for _, name := range j.AllowedPaths {
		if name == "." || path.Clean(name) != name || strings.HasPrefix(name, "/") || strings.HasPrefix(name, "../") || strings.ContainsAny(name, "\x00\r\n") || strings.Split(name, "/")[0] == ".git" {
			return fmt.Errorf("invalid allowed path %q", name)
		}
	}

	return nil
}

func (j Job) Timeout() time.Duration { return time.Duration(j.TimeoutSeconds) * time.Second }

var identifierPattern = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

func Identifier(value string) bool { return identifierPattern.MatchString(value) }
