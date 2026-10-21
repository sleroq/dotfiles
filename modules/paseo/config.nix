{
  lib,
  listen,
  commands,
  relay ? { },
}:
let
  shared = builtins.fromJSON (builtins.readFile ../../home/config/paseo/config.json);
in
lib.recursiveUpdate shared {
  daemon = { inherit listen relay; };
  plugins.worktree-direnv = {
    source = "directory";
    path = "${./plugins/worktree-direnv}";
    enabled = true;
  };
  agents.providers = lib.mapAttrs (_: command: { inherit command; }) commands;
}
