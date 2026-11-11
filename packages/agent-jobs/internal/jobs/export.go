package jobs

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
)

const maxSessionBytes = 64 << 20

func (s Store) exportSessions(ctx context.Context, run Run, pi string) error {
	names, err := s.sessions(run.Job, run.ID)
	if err != nil || len(names) == 0 {
		return err
	}
	dir := filepath.Join(s.Directory, run.Job, run.ID, "session-html")
	if err := os.Mkdir(dir, 0750); err != nil {
		return err
	}
	var errs []error
	for _, name := range names {
		if err := s.exportSession(ctx, run, pi, dir, name); err != nil {
			errs = append(errs, fmt.Errorf("%s: %w", name, err))
		}
		if ctx.Err() != nil {
			break
		}
	}
	return errors.Join(errs...)
}

func (s Store) exportSession(ctx context.Context, run Run, pi, dir, name string) error {
	if !sessionName(name) {
		return errors.New("invalid session name")
	}
	source, err := s.Open(run.Job, run.ID, "output/sessions/"+name)
	if err != nil {
		return err
	}
	defer func() { _ = source.Close() }()

	info, err := source.Stat()
	if err != nil {
		return err
	}
	if info.Size() > maxSessionBytes {
		return errFileTooLarge
	}

	work, err := os.MkdirTemp("", "agent-session-export-*")
	if err != nil {
		return err
	}
	defer func() { _ = os.RemoveAll(work) }()

	input := filepath.Join(work, "session.jsonl")
	copyFile, err := os.OpenFile(input, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	n, copyErr := io.Copy(copyFile, io.LimitReader(source, maxSessionBytes+1))
	closeErr := copyFile.Close()
	if err := errors.Join(copyErr, closeErr); err != nil {
		return err
	}
	if n > maxSessionBytes {
		return errFileTooLarge
	}

	output := filepath.Join(work, "session.html")
	cmd := exec.CommandContext(ctx, pi, "--export", input, output)
	cmd.Dir = work
	cmd.Env = []string{"HOME=" + work, "TMPDIR=" + work, "PATH=/usr/bin:/bin"}
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("pi export: %w", err)
	}

	result, err := os.Open(output)
	if err != nil {
		return err
	}
	defer func() { _ = result.Close() }()

	temp, err := os.CreateTemp(dir, ".export-*")
	if err != nil {
		return err
	}
	defer func() { _ = os.Remove(temp.Name()) }()
	_, copyErr = io.Copy(temp, result)
	if copyErr == nil {
		copyErr = temp.Chmod(0640)
	}
	closeErr = temp.Close()
	if err := errors.Join(copyErr, closeErr); err != nil {
		return err
	}
	return os.Rename(temp.Name(), filepath.Join(dir, name+".html"))
}
