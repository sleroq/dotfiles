package jobs

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
)

const (
	maxSessionPageBytes  = 1 << 20
	maxSessionPageEvents = 100
)

type sessionEvent struct {
	Type      string
	Timestamp string
	Summary   string
	Text      string
	Detail    string
	Issue     string
}

func sessionName(name string) bool {
	return strings.HasSuffix(name, ".jsonl") && Identifier(strings.TrimSuffix(name, ".jsonl"))
}

func (s Store) sessions(job, run string) ([]string, error) {
	root, err := s.runFiles(job, run, "output", "sessions")
	if os.IsNotExist(err) {
		return []string{}, nil
	}
	if err != nil {
		return nil, err
	}
	defer func() { _ = root.Close() }()
	dir, err := root.Open(".")
	if err != nil {
		return nil, err
	}
	defer func() { _ = dir.Close() }()
	entries, err := dir.ReadDir(-1)
	if err != nil {
		return nil, err
	}
	names := []string{}
	for _, entry := range entries {
		if sessionName(entry.Name()) && entry.Type().IsRegular() {
			names = append(names, entry.Name())
		}
	}
	return names, nil
}

type sessionPage struct {
	Events  []sessionEvent
	Next    int
	HasNext bool
}

// readSessionLine retains the newline to identify incomplete trailing entries.
func readSessionLine(reader *bufio.Reader) ([]byte, bool, error) {
	var raw []byte
	oversized := false
	for {
		chunk, err := reader.ReadSlice('\n')
		if !oversized {
			if len(raw)+len(chunk) > maxSessionPageBytes+2 {
				raw = nil
				oversized = true
			} else {
				raw = append(raw, chunk...)
			}
		}
		if !errors.Is(err, bufio.ErrBufferFull) {
			return raw, oversized, err
		}
	}
}

func parseSession(reader io.Reader, offset int) sessionPage {
	lines := bufio.NewReader(reader)
	page := sessionPage{Next: offset}
	line, size := 0, 0
	for {
		raw, oversized, err := readSessionLine(lines)
		if err != nil && !errors.Is(err, io.EOF) {
			if len(page.Events) == maxSessionPageEvents {
				page.HasNext = true
			} else {
				issue := fmt.Sprintf("Line %d: cannot be read: %v", line+1, err)
				page.Events = append(page.Events, sessionEvent{Issue: issue})
			}
			return page
		}
		if errors.Is(err, io.EOF) && len(raw) == 0 && !oversized {
			return page
		}
		line++
		if line <= offset {
			continue
		}
		incomplete := len(raw) == 0 || raw[len(raw)-1] != '\n'
		raw = bytes.TrimSuffix(raw, []byte("\n"))
		raw = bytes.TrimSuffix(raw, []byte("\r"))
		oversized = oversized || len(raw) > maxSessionPageBytes
		if len(page.Events) == maxSessionPageEvents || (len(page.Events) > 0 && (oversized || size+len(raw) > maxSessionPageBytes)) {
			page.HasNext = true
			return page
		}
		if oversized {
			issue := fmt.Sprintf("Line %d: entry exceeds 1 MiB; download Raw JSONL to view it", line)
			page.Events = append(page.Events, sessionEvent{Issue: issue})
		} else {
			size += len(raw)
			page.Events = append(page.Events, parseSessionEntry(raw, line, incomplete))
		}
		page.Next = line
	}
}

func parseSessionEntry(raw []byte, line int, incomplete bool) sessionEvent {
	var entry map[string]json.RawMessage
	if err := json.Unmarshal(raw, &entry); err != nil {
		issue := fmt.Sprintf("Line %d: invalid JSON: %v", line, err)
		if incomplete {
			issue = fmt.Sprintf("Line %d: incomplete trailing entry", line)
		}
		return sessionEvent{Issue: issue, Detail: string(raw)}
	}
	var typ, timestamp string
	_ = json.Unmarshal(entry["type"], &typ)
	_ = json.Unmarshal(entry["timestamp"], &timestamp)
	event := sessionEvent{Type: typ, Timestamp: timestamp, Summary: typ, Detail: string(raw)}
	if typ == "message" {
		event.Summary, event.Text = sessionMessage(entry["message"])
	}
	return event
}

func sessionMessage(raw json.RawMessage) (string, string) {
	var msg struct {
		Role     string          `json:"role"`
		ToolName string          `json:"toolName"`
		IsError  bool            `json:"isError"`
		Content  json.RawMessage `json:"content"`
	}
	if err := json.Unmarshal(raw, &msg); err != nil {
		return "Invalid message", err.Error()
	}
	summary := msg.Role
	if msg.Role == "toolResult" {
		summary = "Tool result · " + msg.ToolName
		if msg.IsError {
			summary = "Tool error · " + msg.ToolName
		}
	}
	var text string
	if json.Unmarshal(msg.Content, &text) == nil {
		return summary, text
	}

	var blocks []struct {
		Type string `json:"type"`
		Text string `json:"text"`
		Name string `json:"name"`
	}
	if json.Unmarshal(msg.Content, &blocks) == nil {
		var parts, tools []string
		for _, block := range blocks {
			switch block.Type {
			case "text":
				parts = append(parts, block.Text)
			case "toolCall":
				tools = append(tools, block.Name)
			}
		}
		text = strings.Join(parts, "\n")
		if len(tools) > 0 {
			summary += " · " + strings.Join(tools, ", ")
		}
	}
	return summary, text
}
