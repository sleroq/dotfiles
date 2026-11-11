package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"agent-jobs/internal/jobs"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	err := execute(ctx, os.Args[1:])
	stop()
	if err != nil {
		slog.Error("agent job", "error", err)
		os.Exit(1)
	}
}

func execute(ctx context.Context, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: agent-jobs run|publish|serve|prune|metrics|sandbox|hold")
	}

	command := flag.NewFlagSet(args[0], flag.ContinueOnError)
	state := command.String("state", "/var/lib/agent-jobs", "Retained run directory")
	switch args[0] {
	case "run", "publish":
		config := command.String("config", "", "Administrator-owned job JSON")
		metrics := command.String("metrics", "", "Prometheus textfile destination")
		var runID *string
		if args[0] == "publish" {
			runID = command.String("run", "", "Failed publication run ID")
		}
		if err := command.Parse(args[1:]); err != nil {
			return err
		}
		job, err := jobs.LoadJob(*config)
		if err != nil {
			return err
		}
		store := jobs.Store{Directory: *state}
		var runErr error
		if runID != nil {
			runErr = jobs.RetryPublication(ctx, job, store, *runID)
		} else {
			runErr = jobs.RunJob(ctx, job, store)
		}
		if *metrics != "" {
			runErr = errors.Join(runErr, jobs.WriteMetrics(store, *metrics))
		}
		return runErr
	case "serve":
		listen := command.String("listen", "127.0.0.1:8787", "Loopback HTTP listen address")
		if err := command.Parse(args[1:]); err != nil {
			return err
		}
		return serve(ctx, jobs.Store{Directory: *state}, *listen)
	case "prune":
		days := command.Int("days", 30, "Days of completed runs to retain")
		if err := command.Parse(args[1:]); err != nil {
			return err
		}
		if *days < 1 {
			return errors.New("retention must be at least one day")
		}
		return (jobs.Store{Directory: *state}).Prune(time.Now().Add(-time.Duration(*days) * 24 * time.Hour))
	case "metrics":
		output := command.String("output", "", "Prometheus textfile destination")
		if err := command.Parse(args[1:]); err != nil {
			return err
		}
		return jobs.WriteMetrics(jobs.Store{Directory: *state}, *output)
	case "sandbox":
		if len(args) != 2 {
			return errors.New("usage: agent-jobs sandbox /input/job.json")
		}
		return jobs.RunSandbox(ctx, args[1])
	case "hold":
		return jobs.Hold(ctx)
	case "archive":
		return jobs.ArchiveOutput(os.Stdout)
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
}

func serve(ctx context.Context, store jobs.Store, address string) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return err
	}
	if ip := net.ParseIP(host); ip == nil || !ip.IsLoopback() {
		return errors.New("viewer must bind a loopback IP; use an authenticated HTTPS proxy or SSH tunnel")
	}
	handler, err := jobs.NewViewer(store)
	if err != nil {
		return err
	}
	listener, err := net.Listen("tcp", address)
	if err != nil {
		return err
	}
	server := &http.Server{
		Handler: handler, ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout: 30 * time.Second, WriteTimeout: 30 * time.Second,
		IdleTimeout: time.Minute,
	}
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdown); err != nil {
			slog.Error("stop viewer", "error", err)
		}
	}()
	slog.Info("run viewer listening", "address", listener.Addr())
	if err := server.Serve(listener); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
