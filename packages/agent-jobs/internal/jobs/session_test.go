package jobs

import (
	"bufio"
	"errors"
	"io"
	"strings"
	"testing"
)

func TestParseSession(t *testing.T) {
	data := `{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"hello"},{"type":"thinking","thinking":"hidden"}]}}` +
		"\n" + `{"type":"compaction","summary":"summary"}` + "\ninvalid\n" + `{"type":`
	events := parseSession(strings.NewReader(data), 0).Events
	if len(events) != 4 || !strings.Contains(events[0].Text, "hello") || !strings.Contains(events[0].Detail, "hidden") || events[1].Summary != "compaction" || !strings.Contains(events[2].Issue, "invalid JSON") || !strings.Contains(events[3].Issue, "incomplete") {
		t.Fatalf("%+v", events)
	}
}
func TestSessionToolLabels(t *testing.T) {
	data := `{"type":"message","message":{"role":"assistant","content":[{"type":"toolCall","name":"bash","arguments":{"command":"true"}}]}}` + "\n" +
		`{"type":"message","message":{"role":"toolResult","toolName":"bash","isError":true,"content":[{"type":"text","text":"command failed"}]}}`
	events := parseSession(strings.NewReader(data), 0).Events
	if events[0].Summary != "assistant · bash" || events[1].Summary != "Tool error · bash" || events[1].Text != "command failed" {
		t.Fatalf("tool events: %+v", events)
	}
}

func TestSessionEntryLimit(t *testing.T) {
	events := parseSession(strings.NewReader(strings.Repeat("x", (16<<20)+1)), 0).Events
	if len(events) != 1 || !strings.Contains(events[0].Issue, "exceeds") {
		t.Fatal(events)
	}
}

func TestSessionUnknownAndIncomplete(t *testing.T) {
	data := `{"type":"extension_event","payload":"<script>alert(1)</script>"}` + "\n" + `{"type":`
	events := parseSession(strings.NewReader(data), 0).Events
	if len(events) != 2 || events[0].Summary != "extension_event" || !strings.Contains(events[0].Detail, "payload") || !strings.Contains(events[1].Issue, "incomplete trailing entry") {
		t.Fatalf("events: %+v", events)
	}
}

func TestSessionDetailsPreserveRawJSON(t *testing.T) {
	payload := strings.Repeat("[", 1000) + `"value"` + strings.Repeat("]", 1000)
	data := `{"type":"extension_event","payload":` + payload + `}`
	events := parseSession(strings.NewReader(data), 0).Events
	if len(events) != 1 || events[0].Detail != data {
		t.Fatalf("details changed or expanded: events=%d", len(events))
	}
}

type countingReader struct {
	reader *strings.Reader
	read   int
}

func (r *countingReader) Read(p []byte) (int, error) {
	n, err := r.reader.Read(p)
	r.read += n
	return n, err
}

func TestSessionPageCountAndBoundedRead(t *testing.T) {
	data := strings.Repeat("{}\n", 1_000_000)
	reader := &countingReader{reader: strings.NewReader(data)}
	first := parseSession(reader, 0)
	if len(first.Events) != 100 || !first.HasNext || first.Next != 100 || reader.read >= len(data) {
		t.Fatalf("events=%d next=%d hasNext=%v read=%d", len(first.Events), first.Next, first.HasNext, reader.read)
	}
	second := parseSession(strings.NewReader(data), first.Next)
	if len(second.Events) != 100 || second.Next != 200 || !second.HasNext {
		t.Fatalf("second page: %+v", second)
	}
}

func TestSessionPageByteLimitAndOversize(t *testing.T) {
	entry := `{"payload":"` + strings.Repeat("a", 600<<10) + `"}`
	oversize := `{"payload":"` + strings.Repeat("b", maxSessionPageBytes) + `"}`
	data := entry + "\n" + entry + "\n" + oversize + "\n" + "{bad}\n"
	first := parseSession(strings.NewReader(data), 0)
	if len(first.Events) != 1 || first.Next != 1 || !first.HasNext {
		t.Fatalf("first: events=%d next=%d hasNext=%v", len(first.Events), first.Next, first.HasNext)
	}
	second := parseSession(strings.NewReader(data), first.Next)
	if len(second.Events) != 1 || second.Next != 2 || !second.HasNext {
		t.Fatalf("second: events=%d next=%d hasNext=%v", len(second.Events), second.Next, second.HasNext)
	}
	third := parseSession(strings.NewReader(data), second.Next)
	if len(third.Events) != 2 || third.Next != 4 || third.HasNext {
		t.Fatalf("third: events=%d next=%d hasNext=%v", len(third.Events), third.Next, third.HasNext)
	}
	if third.Events[0].Detail != "" || !strings.Contains(third.Events[0].Issue, "Raw JSONL") || !strings.Contains(third.Events[1].Issue, "Line 4: invalid JSON") {
		t.Fatalf("third page: %+v", third.Events)
	}
	firstOversize := parseSession(strings.NewReader(oversize+"\n{}\n"), 0)
	if len(firstOversize.Events) != 2 || firstOversize.Next != 2 || firstOversize.Events[0].Detail != "" || !strings.Contains(firstOversize.Events[0].Issue, "Raw JSONL") {
		t.Fatalf("oversize: %+v", firstOversize)
	}
}

func TestSessionHugeLinePagination(t *testing.T) {
	huge := strings.Repeat("x", (16<<20)+1)
	for _, ending := range []string{"\n{}\n", ""} {
		data := "{}\n" + huge + ending
		first := parseSession(strings.NewReader(data), 0)
		if len(first.Events) != 1 || first.Next != 1 || !first.HasNext {
			t.Fatalf("first page: %+v", first)
		}
		second := parseSession(strings.NewReader(data), first.Next)
		want := 1
		if ending != "" {
			want = 2
		}
		if len(second.Events) != want || second.Next != 1+want || second.HasNext || !strings.Contains(second.Events[0].Issue, "Line 2: entry exceeds") {
			t.Fatalf("second page: %+v", second)
		}
		if ending != "" {
			skipped := parseSession(strings.NewReader(data), 2)
			if len(skipped.Events) != 1 || skipped.Next != 3 || skipped.Events[0].Detail != "{}" {
				t.Fatalf("skipped page: %+v", skipped)
			}
		}
		raw, oversized, err := readSessionLine(bufio.NewReader(strings.NewReader(huge + ending)))
		if len(raw) != 0 || !oversized || (err != nil && !errors.Is(err, io.EOF)) {
			t.Fatalf("oversized line retained %d bytes, oversized=%v err=%v", len(raw), oversized, err)
		}
	}
}

func TestSessionCRLFEntryLimit(t *testing.T) {
	entry := `{"payload":"` + strings.Repeat("a", maxSessionPageBytes-len(`{"payload":""}`)) + `"}`
	for _, suffix := range []string{"\r\n", "\n", "\r", ""} {
		page := parseSession(strings.NewReader(entry+suffix), 0)
		if len(page.Events) != 1 || page.Events[0].Detail != entry || page.Events[0].Issue != "" {
			t.Fatalf("suffix %q: %+v", suffix, page.Events)
		}
	}
}

type failingSessionReader struct{}

func (failingSessionReader) Read([]byte) (int, error) { return 0, errors.New("read failure") }

func TestSessionReadError(t *testing.T) {
	page := parseSession(failingSessionReader{}, 0)
	if len(page.Events) != 1 || !strings.Contains(page.Events[0].Issue, "read failure") || strings.Contains(page.Events[0].Issue, "exceeds") {
		t.Fatalf("page: %+v", page)
	}
}
