package jobs

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
)

func TestPiEventLog(t *testing.T) {
	stream := strings.Join([]string{
		`{"type":"session","id":"one"}`,
		`{"type":"message_start","message":{"role":"assistant"}}`,
		`{"type":"message_update","assistantMessageEvent":{"type":"text_delta","contentIndex":0,"delta":"old"}}`,
		`{"type":"message_end","message":{"role":"assistant","content":"final"}}`,
		`{"type":"turn_end","message":"final"}`,
		`{"type":"tool_execution_start","toolName":"bash","args":{"command":"echo hi"}}`,
		`{"type":"tool_execution_update","partialResult":"intermediate"}`,
		`{"type":"tool_execution_end","result":"result"}`,
		`{"type":"message_end","message":{"role":"toolResult","content":"result"}}`,
		`{"type":"agent_end","messages":["final"]}`,
		`{"type":"message_update","assistantMessageEvent":{"type":"thinking_delta","contentIndex":1,"delta":"thinking"}}`,
		`{"type":"message_update","assistantMessageEvent":{"type":"text_delta","contentIndex":0,"delta":"unfinished"}}`,
		`{"type":"message_update","assistantMessageEvent":{"type":"text_delta","contentIndex":0,"delta":" response"}}`,
		`{"type":"message_end"`,
	}, "\n")

	var out bytes.Buffer
	log := &piEventLog{output: &out}
	for _, b := range []byte(stream) {
		if _, err := log.Write([]byte{b}); err != nil {
			t.Fatal(err)
		}
	}
	if err := log.Close(); err != nil {
		t.Fatal(err)
	}

	got := out.String()
	for _, want := range []string{`"id":"one"`, `"content":"final"`, `"command":"echo hi"`, `"result":"result"`, `"text":"thinking"`, `"text":"unfinished response"`, `malformed Pi event omitted`} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in %s", want, got)
		}
	}
	for _, unwanted := range []string{"old", "intermediate", "agent_end", "turn_end", "toolResult"} {
		if strings.Contains(got, unwanted) {
			t.Errorf("unexpected %q in %s", unwanted, got)
		}
	}
	if strings.Count(got, `"result":"result"`) != 1 {
		t.Errorf("duplicate result: %s", got)
	}

	for line := range strings.SplitSeq(strings.TrimSpace(got), "\n") {
		if !json.Valid([]byte(line)) {
			t.Errorf("invalid JSON: %s", line)
		}
	}
}

func TestPiEventLogBoundsAndDrains(t *testing.T) {
	var out bytes.Buffer
	bounded := &boundedWriter{writer: &out, remaining: 100}
	log := &piEventLog{output: bounded}
	stream := strings.Join([]string{
		`{"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"` + strings.Repeat("x", maxPiPartial+100) + `"}}`,
		strings.Repeat("x", maxPiLine+1),
		`{"type":"agent_settled"}`, "",
	}, "\n")
	n, err := log.Write([]byte(stream))
	if err != nil || n != len(stream) {
		t.Fatalf("write = %d, %v", n, err)
	}
	if err := log.Close(); err != nil {
		t.Fatal(err)
	}
	if out.Len() != 100 || !bounded.truncated {
		t.Fatalf("output length %d, truncated %v", out.Len(), bounded.truncated)
	}
	if log.partialBytes != maxPiPartial || !log.partialTruncated {
		t.Fatalf("partial bytes %d, truncated %v", log.partialBytes, log.partialTruncated)
	}
}
