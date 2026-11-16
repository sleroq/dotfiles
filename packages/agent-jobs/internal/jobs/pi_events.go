package jobs

import (
	"bytes"
	"encoding/json"
	"io"
)

// Pi can emit arbitrarily large tool results; neither a line nor an unfinished
// message may grow with the lifetime of the process.
const maxPiLine = 4 * 1024 * 1024
const maxPiPartial = 64 * 1024

type piEventLog struct {
	output           io.Writer
	line             []byte
	oversized        bool
	partial          []piPartialBlock
	partialBytes     int
	partialTruncated bool
}

type piPartialBlock struct {
	Index int    `json:"contentIndex"`
	Type  string `json:"type"`
	Text  string `json:"text"`
}

type piEvent struct {
	Type    string `json:"type"`
	Message struct {
		Role string `json:"role"`
	} `json:"message"`
	Update struct {
		Type  string `json:"type"`
		Index int    `json:"contentIndex"`
		Delta string `json:"delta"`
	} `json:"assistantMessageEvent"`
}

func (l *piEventLog) Write(p []byte) (int, error) {
	n := len(p)
	for len(p) > 0 {
		i := bytes.IndexByte(p, '\n')
		part := p
		if i >= 0 {
			part = p[:i]
		}
		if !l.oversized {
			if len(l.line)+len(part) > maxPiLine {
				l.line = nil
				l.oversized = true
			} else {
				l.line = append(l.line, part...)
			}
		}
		if i < 0 {
			break
		}
		if err := l.finishLine(); err != nil {
			return 0, err
		}
		p = p[i+1:]
	}
	return n, nil
}

func (l *piEventLog) finishLine() error {
	defer func() { l.line = nil; l.oversized = false }()
	if l.oversized {
		return l.writeRecord([]byte(`{"type":"log_warning","message":"oversized Pi event omitted"}`))
	}
	var event piEvent
	if err := json.Unmarshal(l.line, &event); err != nil || event.Type == "" {
		return l.writeRecord([]byte(`{"type":"log_warning","message":"malformed Pi event omitted"}`))
	}
	switch event.Type {
	case "message_start", "tool_execution_update", "turn_end", "agent_end":
		return nil
	case "message_update":
		l.addDelta(event)
		return nil
	case "message_end":
		l.partial = nil
		l.partialBytes = 0
		l.partialTruncated = false
		if event.Message.Role == "toolResult" {
			return nil
		}
	}
	var compact bytes.Buffer
	if err := json.Compact(&compact, l.line); err != nil {
		return err
	}
	return l.writeRecord(compact.Bytes())
}

func (l *piEventLog) addDelta(event piEvent) {
	update := event.Update
	switch update.Type {
	case "text_delta", "thinking_delta", "toolcall_delta":
	default:
		return
	}
	if update.Delta == "" {
		return
	}
	available := maxPiPartial - l.partialBytes
	if available < len(update.Delta) {
		update.Delta = update.Delta[:available]
		l.partialTruncated = true
	}
	if len(update.Delta) == 0 {
		return
	}
	for i := range l.partial {
		if l.partial[i].Index == update.Index && l.partial[i].Type == update.Type {
			l.partial[i].Text += update.Delta
			l.partialBytes += len(update.Delta)
			return
		}
	}
	// Bound per-block overhead as well as accumulated content.
	if len(l.partial) == 256 {
		l.partialTruncated = true
		return
	}
	l.partial = append(l.partial, piPartialBlock{Index: update.Index, Type: update.Type, Text: update.Delta})
	l.partialBytes += len(update.Delta)
}

func (l *piEventLog) writeRecord(record []byte) error {
	record = append(record, '\n')
	_, err := l.output.Write(record)
	return err
}

func (l *piEventLog) Close() error {
	if len(l.line) > 0 || l.oversized {
		if err := l.finishLine(); err != nil {
			return err
		}
	}
	if len(l.partial) == 0 && !l.partialTruncated {
		return nil
	}
	record, err := json.Marshal(struct {
		Type      string           `json:"type"`
		Content   []piPartialBlock `json:"content"`
		Truncated bool             `json:"truncated,omitempty"`
	}{Type: "message_partial", Content: l.partial, Truncated: l.partialTruncated})
	if err != nil {
		return err
	}
	return l.writeRecord(record)
}
