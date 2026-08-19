---
name: golang
description: "Use for any Go/Golang implementation, review, refactor, debugging, or testing work. After completing the work, verify it with golangci-lint and the modernize linter."
---

# Go Work

Always use `fmt.Errorf` instead of `errors.Wrap`.

Run the following verification after completing the task with code changes in .go files:

```sh
golangci-lint run --enable=modernize
```

Run it from the Go module or repository root so that its project configuration is applied. Report any lint failures honestly.

Follow the DDD principles described [here](references/DDD.md)
