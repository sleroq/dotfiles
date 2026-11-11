package main

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestProxyOverridesAuthorizationAndStreams(t *testing.T) {
	release := make(chan struct{})
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer real-key" || r.Host == "attacker.example" {
			t.Error("upstream received untrusted authorization or host")
		}
		if r.URL.Path != "/v1/stream" {
			t.Errorf("path = %q", r.URL.Path)
		}
		_, _ = fmt.Fprintln(w, "first")
		w.(http.Flusher).Flush()
		<-release
		_, _ = fmt.Fprintln(w, "second")
	}))
	defer upstream.Close()

	handler, err := proxyHandler(upstream.URL, "real-key")
	if err != nil {
		t.Fatal(err)
	}
	proxy := httptest.NewServer(handler)
	defer proxy.Close()

	req, _ := http.NewRequest(http.MethodGet, proxy.URL+"/v1/stream", nil)
	req.Header.Set("Authorization", "Bearer attacker")
	req.Host = "attacker.example"

	client := &http.Client{Timeout: 3 * time.Second}
	response, err := client.Do(req)
	if err != nil {
		close(release)
		t.Fatal(err)
	}
	defer func() { _ = response.Body.Close() }()

	reader := bufio.NewReader(response.Body)
	first, err := reader.ReadString('\n')
	close(release)
	if err != nil || first != "first\n" {
		t.Fatalf("first chunk: %q %v", first, err)
	}
	rest, err := io.ReadAll(reader)
	if err != nil || strings.TrimSpace(string(rest)) != "second" {
		t.Fatalf("remaining chunk: %q %v", rest, err)
	}
}

func TestProxyUploadLimit(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.Copy(io.Discard, r.Body)
	}))
	defer upstream.Close()

	handler, err := proxyHandler(upstream.URL, "key")
	if err != nil {
		t.Fatal(err)
	}
	proxy := httptest.NewServer(handler)
	defer proxy.Close()
	for _, known := range []bool{true, false} {
		t.Run(fmt.Sprint("known=", known), func(t *testing.T) {
			body := strings.NewReader(strings.Repeat("x", maxProxyBody+1))
			req, err := http.NewRequest(http.MethodPost, proxy.URL, body)
			if err != nil {
				t.Fatal(err)
			}
			if !known {
				req.ContentLength = -1
			}
			resp, err := http.DefaultClient.Do(req)
			if err != nil {
				t.Fatal(err)
			}
			defer func() { _ = resp.Body.Close() }()
			if resp.StatusCode != http.StatusRequestEntityTooLarge {
				t.Fatalf("status = %s", resp.Status)
			}
		})
	}
}

func TestProxyConcurrencyReleasedOnClose(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	}))
	defer upstream.Close()

	handler, err := proxyHandler(upstream.URL, "key")
	if err != nil {
		t.Fatal(err)
	}
	proxy := httptest.NewServer(handler)
	defer proxy.Close()
	client := &http.Client{Timeout: 5 * time.Second}

	responses := make([]*http.Response, 0, maxProxyRequests)
	defer func() {
		for _, resp := range responses {
			_ = resp.Body.Close()
		}
	}()
	for range maxProxyRequests {
		resp, err := client.Get(proxy.URL)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("status = %s", resp.Status)
		}
		responses = append(responses, resp)
	}

	resp, err := client.Get(proxy.URL)
	if err != nil {
		t.Fatal(err)
	}
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("status = %s", resp.Status)
	}
	_ = responses[0].Body.Close()

	deadline := time.Now().Add(3 * time.Second)
	for {
		resp, err = client.Get(proxy.URL)
		if err != nil {
			t.Fatal(err)
		}
		_ = resp.Body.Close()
		if resp.StatusCode == http.StatusOK {
			break
		}
		if resp.StatusCode != http.StatusServiceUnavailable || time.Now().After(deadline) {
			t.Fatalf("capacity not released: %s", resp.Status)
		}
		time.Sleep(10 * time.Millisecond)
	}
}
