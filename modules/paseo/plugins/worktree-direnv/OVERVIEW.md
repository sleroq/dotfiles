# Worktree local files

Copies selected Git-ignored files from the source checkout into new Paseo worktrees before setup scripts, terminals, and agents start. Requires Paseo 0.15.0-beta.1 or later in the 0.15 series.

The shared policy lives in `server/copy-policy.json`. By default it includes all ignored files except `node_modules` and `.direnv` at every depth:

```json
{
  "include": ["**/*"],
  "exclude": [
    "**/node_modules",
    "**/node_modules/**",
    "**/.direnv",
    "**/.direnv/**"
  ]
}
```

Patterns are repository-relative Git glob pathspecs: `*` matches within one directory, `**` matches across directories, and dotfiles are included. Includes are combined; exclusions always win. An empty include list copies nothing. For a whitelist, replace `include` with patterns such as `["**/.env", "**/.env.*", "**/.envrc", "config/*.local.json"]`. Edit the tracked policy and deploy the host configuration to distribute it through NixOS, Home Manager, and Arch setup. No `.worktreeinclude` is needed.

The source is the checkout used to create the worktree, including when it is another worktree. Git's repository, local, and global ignore rules apply. Tracked and unignored source files are not copied. Existing destination files and symlinks are left alone. This plugin's exclusions do not override Paseo's independent `.worktreeinclude` copier; do not explicitly include excluded directories there.

Secrets and build caches are copied unless excluded. Copies use copy-on-write when the filesystem supports it, and symlinks retain their original link text. Ignored nested repositories cannot be copied. Copy failures, destination parent conflicts, or Paseo's 30-second hook timeout abort worktree creation.

An ignored `.envrc` is copied verbatim, not bridged to the original checkout. Its relative imports and `source_up` now run from the new worktree. Review it and run `direnv allow` there; the plugin never approves or evaluates environment files. An agent's direnv launcher or the shell hook must still load the environment.

Only new worktrees are prepared. Existing workspaces, agent resumes, and restored archived worktrees are not changed. The installation ID remains `worktree-direnv` so existing shared host configuration continues to enable it.
