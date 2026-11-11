package jobs

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

type githubClient struct {
	baseURL string
	client  *http.Client
}

func githubJWT(appID, keyFile string, now time.Time) (string, error) {
	keyData, err := os.ReadFile(keyFile)
	if err != nil {
		return "", err
	}
	block, _ := pem.Decode(keyData)
	if block == nil {
		return "", errors.New("invalid GitHub app private key")
	}
	key, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		parsed, parseErr := x509.ParsePKCS8PrivateKey(block.Bytes)
		if parseErr != nil {
			return "", errors.New("invalid GitHub app private key")
		}
		var ok bool
		key, ok = parsed.(*rsa.PrivateKey)
		if !ok {
			return "", errors.New("GitHub app key is not RSA")
		}
	}
	encode := base64.RawURLEncoding.EncodeToString
	claims, err := json.Marshal(struct {
		Iss string `json:"iss"`
		Iat int64  `json:"iat"`
		Exp int64  `json:"exp"`
	}{appID, now.Add(-time.Minute).Unix(), now.Add(9 * time.Minute).Unix()})
	if err != nil {
		return "", err
	}
	message := encode([]byte(`{"alg":"RS256","typ":"JWT"}`)) + "." + encode(claims)
	hash := sha256.Sum256([]byte(message))
	signature, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, hash[:])
	if err != nil {
		return "", err
	}
	return message + "." + encode(signature), nil
}

type githubError struct{ status int }

func (e githubError) Error() string { return fmt.Sprintf("GitHub API returned HTTP %d", e.status) }

func (g githubClient) request(ctx context.Context, method, endpoint, token string, body any, result any) error {
	var encoded []byte
	if body != nil {
		var err error
		encoded, err = json.Marshal(body)
		if err != nil {
			return err
		}
	}

	for attempt := range 3 {
		retry, err := g.requestOnce(ctx, method, endpoint, token, encoded, body != nil, result)
		if !retry {
			return err
		}
		if attempt == 2 {
			return fmt.Errorf("GitHub request failed: %w", err)
		}
		timer := time.NewTimer(time.Duration(attempt+1) * time.Second)
		select {
		case <-ctx.Done():
			timer.Stop()
			return ctx.Err()
		case <-timer.C:
		}
	}
	return errors.New("GitHub request failed")
}

func (g githubClient) requestOnce(ctx context.Context, method, endpoint, token string, body []byte, hasBody bool, result any) (bool, error) {
	req, err := http.NewRequestWithContext(ctx, method, g.baseURL+endpoint, bytes.NewReader(body))
	if err != nil {
		return false, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	if hasBody {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := g.client.Do(req)
	if err != nil {
		if ctx.Err() != nil {
			return false, ctx.Err()
		}
		return true, err
	}
	data, readErr := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	closeErr := resp.Body.Close()
	if readErr != nil {
		return false, readErr
	}
	if closeErr != nil {
		return false, closeErr
	}
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		if result != nil {
			return false, json.Unmarshal(data, result)
		}
		return false, nil
	}
	return resp.StatusCode == 429 || resp.StatusCode >= 500, githubError{resp.StatusCode}
}

func (g githubClient) installationToken(ctx context.Context, job Job) (string, error) {
	jwt, err := githubJWT(job.Publish.AppID, job.Publish.PrivateKeyFile, time.Now())
	if err != nil {
		return "", err
	}
	repo := strings.Split(job.Repository, "/")[1]
	body := struct {
		Repositories []string          `json:"repositories"`
		Permissions  map[string]string `json:"permissions"`
	}{[]string{repo}, map[string]string{"contents": "write", "pull_requests": "write"}}
	var result struct {
		Token string `json:"token"`
	}
	endpoint := "/app/installations/" + url.PathEscape(job.Publish.InstallationID) + "/access_tokens"
	if err := g.request(ctx, http.MethodPost, endpoint, jwt, body, &result); err != nil {
		return "", err
	}
	if result.Token == "" {
		return "", errors.New("GitHub returned an empty installation token")
	}
	return result.Token, nil
}

type githubPullRequest struct {
	Number int    `json:"number"`
	URL    string `json:"html_url"`
	User   struct {
		Login string `json:"login"`
	} `json:"user"`
}

func (g githubClient) pullRequest(ctx context.Context, job Job, token, base, description string) (string, error) {
	parts := strings.Split(job.Repository, "/")
	endpoint := "/repos/" + url.PathEscape(parts[0]) + "/" + url.PathEscape(parts[1]) + "/pulls"

	query := url.Values{"state": {"open"}, "head": {parts[0] + ":" + job.Branch}, "base": {base}, "per_page": {"100"}}
	var pulls []githubPullRequest
	if err := g.request(ctx, http.MethodGet, endpoint+"?"+query.Encode(), token, nil, &pulls); err != nil {
		return "", err
	}

	title := job.Publish.Title
	if title == "" {
		title = job.Name
	}
	body := struct {
		Title string `json:"title"`
		Body  string `json:"body"`
		Head  string `json:"head,omitempty"`
		Base  string `json:"base,omitempty"`
	}{Title: title, Body: description}
	var pr githubPullRequest
	if len(pulls) == 0 {
		body.Head = job.Branch
		body.Base = base
		if err := g.request(ctx, http.MethodPost, endpoint, token, body, &pr); err != nil {
			return "", err
		}
	} else {
		pr.Number = pulls[0].Number
		if err := g.request(ctx, http.MethodPatch, fmt.Sprintf("%s/%d", endpoint, pr.Number), token, body, &pr); err != nil {
			return "", err
		}
	}

	if pr.Number == 0 || pr.URL == "" {
		return "", errors.New("GitHub returned invalid pull request")
	}

	if job.Publish.Reviewer != "" && !strings.EqualFold(job.Publish.Reviewer, pr.User.Login) {
		if err := g.request(ctx, http.MethodPost, fmt.Sprintf("%s/%d/requested_reviewers", endpoint, pr.Number), token, struct {
			Reviewers []string `json:"reviewers"`
		}{[]string{job.Publish.Reviewer}}, nil); err != nil {
			return "", err
		}
	}
	return pr.URL, nil
}
