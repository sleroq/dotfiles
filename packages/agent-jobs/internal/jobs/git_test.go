package jobs

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func gitTestRepo(t *testing.T) (hostGit, string) {
	t.Helper()
	home := t.TempDir()
	repo := filepath.Join(t.TempDir(), "repo")
	if err := os.Mkdir(repo, 0755); err != nil {
		t.Fatal(err)
	}
	g := hostGit{home: home}
	ctx := context.Background()
	for _, args := range [][]string{{"init", "-q"}, {"-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "base"}} {
		if _, err := g.run(ctx, repo, args...); err != nil {
			t.Fatal(err)
		}
	}
	return g, repo
}

func TestApplyCandidatePolicyAndHostConfig(t *testing.T) {
	for _, tc := range []struct {
		name, changed      string
		symlink, wantError bool
	}{{"allowed", "allowed.txt", false, false}, {"forbidden", "other.txt", false, true}, {"symlink", "allowed.txt", true, true}} {
		t.Run(tc.name, func(t *testing.T) {
			g, repo := gitTestRepo(t)
			ctx := context.Background()
			marker := filepath.Join(t.TempDir(), "executed")

			// Neither global configuration nor hooks from the operator's HOME may execute.
			hook := filepath.Join(g.home, "hooks")
			if err := os.Mkdir(hook, 0755); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(hook, "pre-commit"), []byte("#!/bin/sh\ntouch "+marker+"\n"), 0755); err != nil {
				t.Fatal(err)
			}
			config := []byte("[core]\n hooksPath = " + hook + "\n fsmonitor = " + marker + "\n")
			if err := os.WriteFile(filepath.Join(g.home, ".gitconfig"), config, 0644); err != nil {
				t.Fatal(err)
			}

			source := filepath.Join(repo, tc.changed)
			if tc.symlink {
				if err := os.Symlink("/etc/passwd", source); err != nil {
					t.Fatal(err)
				}
			} else if err := os.WriteFile(source, []byte("hello\n"), 0644); err != nil {
				t.Fatal(err)
			}
			if _, err := g.run(ctx, repo, "add", "-A"); err != nil {
				t.Fatal(err)
			}

			patch, err := g.command(ctx, repo, "diff", "--cached", "--binary").Output()
			if err != nil {
				t.Fatal(err)
			}
			patchFile := filepath.Join(t.TempDir(), "candidate.patch")
			if err := os.WriteFile(patchFile, patch, 0644); err != nil {
				t.Fatal(err)
			}
			if _, err := g.run(ctx, repo, "reset", "--hard", "HEAD"); err != nil {
				t.Fatal(err)
			}

			_, err = g.applyCandidate(ctx, repo, patchFile, []string{"allowed.txt"})
			if (err != nil) != tc.wantError {
				t.Fatalf("got error %v", err)
			}
			_, err = g.run(ctx, repo, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
				"commit", "--allow-empty", "-qm", "test")
			if err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(marker); !os.IsNotExist(err) {
				t.Fatalf("host configuration executed: %v", err)
			}
		})
	}
}

func TestCheckoutAndCopyDoesNotFollowSymlink(t *testing.T) {
	g, source := gitTestRepo(t)
	ctx := context.Background()
	if err := os.Symlink("/etc/passwd", filepath.Join(source, "outside")); err != nil {
		t.Fatal(err)
	}
	if _, err := g.run(ctx, source, "add", "outside"); err != nil {
		t.Fatal(err)
	}
	if _, err := g.run(ctx, source, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "link"); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(t.TempDir(), "checkout")
	base, err := g.checkout(ctx, Job{CloneURL: source}, target)
	if err != nil || base == "" {
		t.Fatalf("checkout %q: %v", base, err)
	}
	copy := filepath.Join(t.TempDir(), "input")
	if err := copySource(target, copy); err != nil {
		t.Fatal(err)
	}
	link, err := os.Readlink(filepath.Join(copy, "outside"))
	if err != nil || link != "/etc/passwd" {
		t.Fatalf("link %q: %v", link, err)
	}
	if _, err := os.Stat(filepath.Join(copy, ".git")); !os.IsNotExist(err) {
		t.Fatalf("metadata copied: %v", err)
	}
	if strings.Contains(base, "\n") {
		t.Fatalf("bad base %q", base)
	}
}

func TestGitProtocolOutputExcludesWarnings(t *testing.T) {
	git := hostGit{home: t.TempDir()}
	alias := "alias.fixture=!printf 'object refs/heads/automation/test\\n'; " +
		"printf 'warning: redirecting to https://github.com/owner/repo.git/\\n' >&2"
	out, err := git.run(context.Background(), "", "-c", alias, "fixture")
	if err != nil || out != "object refs/heads/automation/test" {
		t.Fatalf("protocol output %q: %v", out, err)
	}

	alias = "alias.fixture=!printf 'secret connection timed out\\n' >&2; exit 1"
	out, err = git.run(context.Background(), "", "-c", alias, "fixture")
	var transient transientGitError
	if out != "" || !errors.As(err, &transient) {
		t.Fatalf("failure output %q: %v", out, err)
	}
}

func TestGitCredentialIsRestrictedToCloneHost(t *testing.T) {
	git := hostGit{home: t.TempDir(), token: "test-secret", credentialHost: "github.com"}
	for _, test := range []struct {
		host, protocol string
		allowed        bool
	}{{"github.com", "https", true}, {"elsewhere.example", "https", false}, {"github.com", "http", false}} {
		cmd := git.command(context.Background(), "", "credential", "fill")
		cmd.Stdin = strings.NewReader("protocol=" + test.protocol + "\nhost=" + test.host + "\n\n")
		data, err := cmd.Output()
		if test.allowed && err != nil {
			t.Fatal(err)
		}
		if strings.Contains(string(data), "test-secret") != test.allowed {
			t.Fatalf("host %s protocol %s output %q err %v", test.host, test.protocol, data, err)
		}
	}
}

func TestCheckoutDepthAndRemoteBranches(t *testing.T) {
	g, source := gitTestRepo(t)
	ctx := context.Background()
	old, err := g.run(ctx, source, "rev-parse", "HEAD")
	if err != nil {
		t.Fatal(err)
	}

	for _, args := range [][]string{{"branch", "other"}, {"-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "new"}} {
		if _, err := g.run(ctx, source, args...); err != nil {
			t.Fatal(err)
		}
	}
	branch, err := g.run(ctx, source, "symbolic-ref", "--short", "HEAD")
	if err != nil {
		t.Fatal(err)
	}

	for _, tc := range []struct {
		name, url string
		shallow   bool
	}{
		{"path shallow", source, true}, {"path full", source, false},
		{"file shallow", "file://" + source, true}, {"file full", "file://" + source, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			url, shallow := tc.url, tc.shallow
			dir := filepath.Join(t.TempDir(), "checkout")
			base, err := g.checkoutWithDepth(ctx, Job{CloneURL: url}, dir, shallow)
			if err != nil {
				t.Fatal(err)
			}
			tip, err := g.run(ctx, source, "rev-parse", "HEAD")
			if err != nil || base != tip {
				t.Fatalf("base %q, tip %q: %v", base, tip, err)
			}
			got, err := g.run(ctx, dir, "rev-parse", "--is-shallow-repository")
			if err != nil || got != strconv.FormatBool(shallow) {
				t.Fatalf("shallow %q: %v", got, err)
			}
			got, err = g.run(ctx, dir, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
			if err != nil || got != "origin/"+branch {
				t.Fatalf("default branch %q: %v", got, err)
			}
			if !shallow {
				got, err = g.run(ctx, dir, "rev-parse", "refs/remotes/origin/other")
				if err != nil || got != old {
					t.Fatalf("other branch %q: %v", got, err)
				}
			}
			_, err = g.run(ctx, dir, "rev-parse", "--verify", "HEAD^")
			if (err != nil) != shallow {
				t.Fatalf("parent error: %v", err)
			}
		})
	}
}

func TestPublishCheckoutRetainsPinnedBase(t *testing.T) {
	g, source := gitTestRepo(t)
	ctx := context.Background()
	base, err := g.run(ctx, source, "rev-parse", "HEAD")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := g.run(ctx, source, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
		"commit", "--allow-empty", "-qm", "advanced"); err != nil {
		t.Fatal(err)
	}

	patch := filepath.Join(t.TempDir(), "patch")
	patchData := "diff --git a/file b/file\nnew file mode 100644\nindex 0000000..ce01362\n" +
		"--- /dev/null\n+++ b/file\n@@ -0,0 +1 @@\n+hello\n"
	if err := os.WriteFile(patch, []byte(patchData), 0644); err != nil {
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
	body := "Update"
	server := httptest.NewServer(publicationHandler(t, &created, &revoked, &reviews, &body))
	defer server.Close()
	job := Job{
		Name: "test", Repository: "owner/repo", CloneURL: "file://" + source, Branch: "automation/test",
		AllowedPaths: []string{"file"}, Publish: Publication{AppID: "123", InstallationID: "42", PrivateKeyFile: keyFile},
	}
	work := t.TempDir()
	api := githubClient{baseURL: server.URL, client: server.Client()}
	_, publication, err := g.publish(ctx, job, work, base, "", patch, body, api, Run{})
	if err != nil || publication != "published" {
		t.Fatalf("publication %q: %v", publication, err)
	}

	parent, err := g.run(ctx, filepath.Join(work, "publish"), "rev-parse", "HEAD^")
	if err != nil || parent != base {
		t.Fatalf("publication parent %q: %v", parent, err)
	}
}
