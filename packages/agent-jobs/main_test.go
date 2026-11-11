package main

import (
	"context"
	"testing"

	"agent-jobs/internal/jobs"
)

func TestViewerRefusesPublicBinding(t *testing.T) {
	for _, address := range []string{"0.0.0.0:8787", "[::]:8787", ":8787", "example.com:8787"} {
		err := serve(context.Background(), jobs.Store{Directory: t.TempDir()}, address, jobs.TimerInventory{})
		if err == nil {
			t.Errorf("serve %s: %v", address, err)
		}
	}
}

func TestCLIRejectsUnknownCommandAndInvalidRetention(t *testing.T) {
	if err := execute(context.Background(), []string{"delete"}); err == nil {
		t.Fatal("accepted a management command")
	}
	if err := execute(context.Background(), []string{"prune", "-days", "0"}); err == nil {
		t.Fatal("accepted zero-day retention")
	}
}
