# Worktree direnv

Makes an ignored repository `.envrc` available in Paseo-managed worktrees on this daemon. Supports Paseo 0.11.4 and 0.12.

When a workspace is created, or before an interactive agent session opens, the plugin creates a missing worktree `.envrc` containing `source_env '/path/to/repository/.envrc'`. It uses the workspace's configured project root as the source checkout. Paseo does not retain the exact source checkout when branching from another worktree.

Only existing, Git-ignored source files are imported. Tracked source files, tracked target paths, existing worktree files and symlinks are left alone. No secret values are copied or logged.

Review the generated file and run `direnv allow` inside each worktree. The plugin never approves or evaluates environment files. Direnv's shell hook or an agent's direnv launcher must still load the environment.

The original script runs in its original directory, including its `source_up` and relative file imports. This also means project-specific tool paths can refer to the original checkout. Once the bridge is approved, `source_env` does not separately check approval of the original script.

Workspace events are asynchronous: this is not a barrier before worktree setup scripts or a terminal's first prompt. Agent session opening waits for the bridge check. Existing terminal-only workspaces receive a bridge when an agent session next opens; existing processes do not refresh their environments automatically.
