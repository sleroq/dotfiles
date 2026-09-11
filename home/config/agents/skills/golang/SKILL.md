---
name: golang
description: "Use for any Go/Golang implementation, review, refactor, debugging, or testing work. After completing the work, verify it with golangci-lint using staticcheck, containedctx, and modernize."
---

# Go Work

Always use `fmt.Errorf` instead of `errors.Wrap`.

After completing the task with code changes in `.go` files, first run `gopls check` on all changed files together. Use the changed file path, directory, or all files as appropriate:

```sh
gopls check ./path/to/file.go
# Or check the changed directory or all packages:
gopls check ./path/to/package
gopls check ./...
```

Then run the following verification:

```sh
golangci-lint run --enable=staticcheck,containedctx,modernize
```

Run it from the Go module or repository root so that its project configuration and default linters are applied. Report any lint failures honestly.

Follow the DDD principles described [here](references/DDD.md)
