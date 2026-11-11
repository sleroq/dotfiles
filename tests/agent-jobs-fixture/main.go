package main

import (
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return errors.New("fixture scenario required")
	}
	mode := args[0]
	if mode == "serve" {
		server := http.Server{Addr: ":18080", ReadHeaderTimeout: time.Second, Handler: http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			_, _ = fmt.Fprintln(w, "fixture reachable")
		})}
		return server.ListenAndServe()
	}

	prompt, err := os.ReadFile("/input/prompt")
	if err != nil {
		return err
	}
	if !strings.Contains(string(prompt), "/output/pr-body.md") {
		return errors.New("missing default PR description instruction")
	}

	sessions := "/output/sessions"
	for i := 1; i+1 < len(args); i++ {
		if args[i] == "--session-dir" {
			sessions = args[i+1]
		}
	}
	if err := os.MkdirAll(sessions, 0755); err != nil {
		return err
	}
	session := `{"type":"message","message":{"role":"assistant","content":"fixture complete"}}` + "\n"
	if err := os.WriteFile(filepath.Join(sessions, "fixture.jsonl"), []byte(session), 0644); err != nil {
		return err
	}
	fmt.Println("fixture output")

	if err := scenario(mode); err != nil {
		return err
	}
	if err := os.WriteFile("allowed.txt", []byte("updated\n"), 0644); err != nil {
		return err
	}
	return os.WriteFile("/output/pr-body.md", []byte("Update the fixture file.\n"), 0644)
}

func scenario(mode string) error {
	switch mode {
	case "timeout":
		time.Sleep(10 * time.Minute)
	case "failure":
		return errors.New("fixture failure")
	case "security":
		return checkIsolation()
	case "symlink":
		return os.Symlink("/etc/passwd", "/output/escape")
	case "bad-path":
		return os.WriteFile("forbidden.txt", []byte("forbidden\n"), 0644)
	case "success":
		return inspectNixStore()
	case "direnv":
		if os.Getenv("FIXTURE_ENV") != "root" {
			return errors.New("project environment was not loaded for the agent")
		}
		return nil
	default:
		return fmt.Errorf("unknown mode %q", mode)
	}
	return nil
}

func inspectNixStore() error {
	fmt.Printf("sandbox uid=%d gid=%d\n", os.Getuid(), os.Getgid())
	for _, name := range []string{"/nix/store", "/nix/var/nix/db", "/nix/var/nix/db/big-lock"} {
		info, err := os.Stat(name)
		if err != nil {
			return err
		}
		fmt.Printf("%s: mode=%s metadata=%+v\n", name, info.Mode(), info.Sys())
	}
	return nil
}

func checkIsolation() error {
	for _, name := range []string{"/var/run/docker.sock", "/run/credentials", "/var/lib/agent-jobs", "/var/lib/agent-jobs-work", "/run/host-canary", "/input/files/forbidden", "/dev/kvm"} {
		if _, err := os.Stat(name); err == nil {
			return fmt.Errorf("unexpected host path: %s", name)
		}
	}
	allowed, err := os.ReadFile("/input/files/allowed")
	if err != nil {
		return fmt.Errorf("read approved credential: %w", err)
	}
	if string(allowed) != "allowed fixture credential" {
		return errors.New("approved credential has unexpected contents")
	}

	// The same live listener is reachable at a public test address but not its LAN address.
	for _, address := range []string{"203.0.113.2:18080", "agent-jobs.fixture:18080"} {
		public, err := net.DialTimeout("tcp", address, 3*time.Second)
		if err != nil {
			return fmt.Errorf("public positive control %s: %w", address, err)
		}
		if err := public.Close(); err != nil {
			return err
		}
	}
	for _, address := range []string{"172.30.0.1:18080", "192.168.1.2:18080", "169.254.169.254:18080"} {
		connection, err := net.DialTimeout("tcp", address, time.Second)
		if err == nil {
			return errors.Join(fmt.Errorf("unexpected private connection: %s", address), connection.Close())
		}
	}
	return nil
}
