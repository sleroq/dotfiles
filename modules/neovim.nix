{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  neovim = import ../lib/neovim.nix { inherit pkgs inputs; };
  users = lib.filterAttrs (_: user: user.sleroq.neovim.enable) config.users.users;
  profile = (pkgs.formats.json { }).generate "neovim-profile.json" {
    files.".config/nvim" = "${../home/config/nvim}";
    links = { };
  };
in
{
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        {
          options.sleroq.neovim.enable = lib.mkEnableOption "the shared Neovim environment";
          config = lib.mkIf config.sleroq.neovim.enable {
            packages = neovim.packages;
          };
        }
      )
    );
  };

  config = lib.mkIf (users != { }) {
    system.activationScripts.neovim = {
      deps = [ "etc" ];
      text = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: user:
          "${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg name} -- "
          + "${pkgs.nodejs_24}/bin/node ${../lib/seed-profile.mjs} ${profile} ${lib.escapeShellArg user.home}"
        ) users
      );
    };
  };
}
