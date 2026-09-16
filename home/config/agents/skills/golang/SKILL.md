---
name: golang
description: "Use for any Go/Golang implementation, review, refactor, debugging, or testing work. After completing the work, verify it with gopls, golangci-lint, and deadcode."
---

# Go Work

After completing the task with code changes in `.go` files, first run `gopls check` on all changed files together. Use the changed file path, directory, or all files as appropriate:

```sh
gopls check ./path/to/file.go
# Or check the changed directory or all packages:
gopls check ./path/to/package
gopls check ./...
```

Then run the following verification:

```sh
golangci-lint run
deadcode -test ./...
```

Run these commands from the Go module or repository root so that project configuration and default linters are applied. Report any lint failures honestly.

Treat `dupl`, `funlen`, `gocognit`, `cyclop`, `gocyclo`, `maintidx`, and `nestif` as maintainability signals rather than automatic refactoring requirements. Resolve them when the change improves the code's clarity and structure; otherwise report the finding and preserve the clearer implementation.

Treat `deadcode` as an advisory reachability report, not a zero-finding gate. Investigate each finding and resolve only code that is genuinely unreachable in the project's supported applications and build configurations. Keep findings that make sense for externally consumed libraries, alternate build tags or platforms, framework entry points, or other execution paths outside the analyzed program.

Follow the DDD principles described [here](references/DDD.md).

Follow the Go codebase cleanup guidelines described [here](references/go-deslop.md).
