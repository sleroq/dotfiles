package jobs

import (
	"strings"
	"testing"
)

func TestParseSession(t *testing.T) {
	data := `{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"hello"},{"type":"thinking","thinking":"hidden"}]}}` +
		"\n" + `{"type":"compaction","summary":"summary"}` + "\ninvalid\n" + `{"type":`
	events := parseSession([]byte(data))
	if len(events) != 4 || !strings.Contains(events[0].Text, "hello") || !strings.Contains(events[0].Detail, "hidden") || events[1].Summary != "compaction" || !strings.Contains(events[2].Issue, "invalid JSON") || !strings.Contains(events[3].Issue, "incomplete") {
		t.Fatalf("%+v", events)
	}
}
func TestSessionToolLabels(t *testing.T) {
	data := `{"type":"message","message":{"role":"assistant","content":[{"type":"toolCall","name":"bash","arguments":{"command":"true"}}]}}` + "\n" +
		`{"type":"message","message":{"role":"toolResult","toolName":"bash","isError":true,"content":[{"type":"text","text":"command failed"}]}}`
	events := parseSession([]byte(data))
	if events[0].Summary != "assistant · bash" || events[1].Summary != "Tool error · bash" || events[1].Text != "command failed" {
		t.Fatalf("tool events: %+v", events)
	}
}

func TestSessionEntryLimit(t *testing.T) {
	events := parseSession([]byte(strings.Repeat("x", maxSessionEntry+1)))
	if len(events) != 1 || !strings.Contains(events[0].Issue, "exceeds") {
		t.Fatal(events)
	}
}

func TestSessionUnknownAndIncomplete(t *testing.T) {
	data := `{"type":"extension_event","payload":"<script>alert(1)</script>"}` + "\n" + `{"type":`
	events := parseSession([]byte(data))
	if len(events) != 2 || events[0].Summary != "extension_event" || !strings.Contains(events[0].Detail, "payload") || !strings.Contains(events[1].Issue, "incomplete trailing entry") {
		t.Fatalf("events: %+v", events)
	}
}
