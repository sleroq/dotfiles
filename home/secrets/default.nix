# This file contains some stuff I don't really want to commit on github,
# but it's for it to end up in the nix store
# see https://github.com/NixOS/nix/issues/7107
# Use `git update-index --no-skip-worktree ./secrets/default.nix`
# to ignore the file locally, so you don't commit it by accident

{
  wezterm-ssh-domains = "";
}
