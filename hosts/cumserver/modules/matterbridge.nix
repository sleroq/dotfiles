{ config, pkgs, lib, ... }:
let
  cfg = config.cumserver.matterbridge;
in
{
  options.cumserver.matterbridge.enable = lib.mkEnableOption "Matterbridge";

  config = lib.mkIf cfg.enable {
    age.secrets.matterbridge = {
      owner = "matterbridge";
      group = "matterbridge";
      file = ../secrets/matterbridge.toml;
    };

    services.matterbridge = {
      enable = true;
      package = pkgs.matterbridge.overrideAttrs (oldAttrs: rec {
        version = "1.26.0-fork-${builtins.substring 0 7 src.rev}";

        src = pkgs.fetchFromGitHub {
          owner = "bibanon";
          repo = "matterbridge";
          rev = "f32058598335f28b2187706cfa902f624f4d193c";
          hash = "sha256-7F0cAdnxUt2to+zhf/gtobbvPX1NnSpsLKbxy059CB0=";
        };
      });
      configPath = config.age.secrets.matterbridge.path;
    };
  };
}
