# This file contains some stuff I don't really want to commit on github,
# but it's for it to end up in the nix store
# Use `git update-index --skip-worktree ./secrets/default.nix`
# to ignore the file locally, so you don't commit it by accident
# see https://github.com/NixOS/nix/issues/7107

{
  ipv4 = "5.9.179.224";
  ipv6 = "2a00:1450:4001:829::200e";
  mailUsers = [
    {
      name = "sleroq";
      passwordSecretName = "password1";
      isCatchAll = true;
    }
  ];
}
