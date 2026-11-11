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
