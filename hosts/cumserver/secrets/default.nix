# This file contains some stuff I don't really want to commit on github,
# but it's for it to end up in the nix store
# Use `git update-index --skip-worktree ./secrets/default.nix`
# to ignore the file locally, so you don't commit it by accident
# see https://github.com/NixOS/nix/issues/7107

{
  ipv4 = "";
  ipv6 = "";
  mailUsers = [];
  marzbanNode1IP = "";
  marzbanNode2IP = "";
}
