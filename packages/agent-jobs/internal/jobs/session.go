package jobs

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

const (
	maxSessionEntry      = 16 << 20
	maxSessionPageBytes  = 1 << 20
	maxSessionPageEvents = 100
)

var errFileTooLarge = fmt.Errorf("file exceeds 64 MiB read limit")

type sessionEvent struct {
	Type      string
	Timestamp string
	Summary   string
	Text      string
	Detail    string
	Issue     string
}

// runFiles opens each directory without following agent-controlled symlinks.
func (s Store) runFiles(job, run string, dirs ...string) (*os.Root, error) {
	root, err := os.OpenRoot(s.Directory)
	if err != nil {
		return nil, err
	}
	for _, name := range append([]string{job, run}, dirs...) {
		info, e := root.Lstat(name)
		if e != nil {
			_ = root.Close()
			return nil, e
		}
		if !info.IsDir() {
			_ = root.Close()
			return nil, fs.ErrNotExist
		}
		next, e := root.OpenRoot(name)
		_ = root.Close()
		if e != nil {
			return nil, e
		}
		root = next
	}
	return root, nil
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

// fileRoot confines lookups to the run and rejects symlinks and special files.
func (s Store) fileRoot(job, run, name string) (*os.Root, string, error) {
	parts := strings.Split(filepath.ToSlash(name), "/")
	root, err := s.runFiles(job, run, parts[:len(parts)-1]...)
	if err != nil {
		return nil, "", err
	}
	base := parts[len(parts)-1]
	info, err := root.Lstat(base)
	if err == nil && !info.Mode().IsRegular() {
		err = fs.ErrNotExist
	}
	if err != nil {
		_ = root.Close()
		return nil, "", err
	}
	return root, base, nil
}

func (s Store) checkFile(job, run, name string) error {
	root, _, err := s.fileRoot(job, run, name)
	if err != nil {
		return err
	}
	return root.Close()
}

func (s Store) openFile(job, run, name string) (*os.File, error) {
	root, base, err := s.fileRoot(job, run, name)
	if err != nil {
		return nil, err
	}
	defer func() { _ = root.Close() }()
	file, err := root.Open(base)
	if err != nil {
		return nil, err
	}
	info, err := file.Stat()
	if err != nil {
		_ = file.Close()
		return nil, err
	}
	if !info.Mode().IsRegular() {
		_ = file.Close()
		return nil, fs.ErrNotExist
	}
	return file, nil
}

func (s Store) safeRead(job, run, name string) ([]byte, error) {
	file, err := s.openFile(job, run, name)
	if err != nil {
		return nil, err
	}
	defer func() { _ = file.Close() }()
	info, err := file.Stat()
	if err != nil {
		return nil, err
	}
	if info.Size() > 64<<20 {
		return nil, errFileTooLarge
	}
	data, err := io.ReadAll(io.LimitReader(file, (64<<20)+1))
	if err != nil {
		return nil, err
	}
	if len(data) > 64<<20 {
		return nil, errFileTooLarge
	}
	return data, nil
}

type sessionPage struct {
	Events  []sessionEvent
	Next    int
	HasNext bool
}

// scanSessionLine retains the newline so a malformed final line can be distinguished.
func scanSessionLine(data []byte, atEOF bool) (int, []byte, error) {
	if i := bytes.IndexByte(data, '\n'); i >= 0 {
		return i + 1, data[:i+1], nil
	}
	if atEOF && len(data) > 0 {
		return len(data), data, nil
	}
	return 0, nil, nil
}

func parseSession(reader io.Reader, offset int) sessionPage {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 4096), maxSessionEntry)
	scanner.Split(scanSessionLine)
	page := sessionPage{Next: offset}
	line, size := 0, 0
	for scanner.Scan() {
		line++
		if line <= offset {
			continue
		}
		raw := scanner.Bytes()
		incomplete := len(raw) == 0 || raw[len(raw)-1] != '\n'
		raw = bytes.TrimSuffix(raw, []byte("\n"))
		raw = bytes.TrimSuffix(raw, []byte("\r"))
		if len(page.Events) == maxSessionPageEvents || (len(page.Events) > 0 && size+len(raw) > maxSessionPageBytes) {
			page.HasNext = true
			return page
		}
		if len(raw) > maxSessionPageBytes {
			issue := fmt.Sprintf("Line %d: entry exceeds 1 MiB; download Raw JSONL to view it", line)
			page.Events = append(page.Events, sessionEvent{Issue: issue})
		} else {
			size += len(raw)
			page.Events = append(page.Events, parseSessionEntry(raw, line, incomplete))
		}
		page.Next = line
	}
	if err := scanner.Err(); err != nil {
		if len(page.Events) == maxSessionPageEvents {
			page.HasNext = true
		} else {
			issue := fmt.Sprintf("Line %d: entry exceeds %d bytes or cannot be read: %v", line+1, maxSessionEntry, err)
			page.Events = append(page.Events, sessionEvent{Issue: issue})
		}
	}
	return page
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
