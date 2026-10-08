{
  lib,
  config,
  opts,
  pkgs,
  ...
}:

let
  cfg = config.myHome.programs.pi;
  minPiVersion = "0.80.0";
  bunInstall = "${config.xdg.cacheHome}/.bun";
in
{
  options.myHome.programs.pi = {
    enable = lib.mkEnableOption "Pi coding agent";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.activation.installPi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          export BUN_INSTALL="${bunInstall}"
          PATH="${pkgs.bun}/bin:$BUN_INSTALL/bin:$PATH"
          if ! command -v pi > /dev/null ||
            ! ${pkgs.coreutils}/bin/printf '%s\n' '${minPiVersion}' "$(pi --version)" |
              ${pkgs.coreutils}/bin/sort --version-sort --check=quiet
          then
            run ${pkgs.bun}/bin/bun install -g @earendil-works/pi-coding-agent@latest
          fi
        '';
      }

      {
        home.sessionPath = lib.mkBefore [ "${bunInstall}/bin" ];
        home.sessionVariables = {
          BUN_INSTALL = bunInstall;
          PI_FFF_MODE = "override";
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          # OpenCode's built-in "done" sound at the same volume as opencode/tui.json.
          PI_MAIN_NOTIFY_SOUND_CMD = ''afplay -v 0.4 "$HOME/.pi/agent/sounds/bip-bop-01.mp3"'';
        };

        home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p $HOME/.pi/agent

          # OAuth refresh tokens rotate and must not be shared between hosts.
          if [ -L "$HOME/.pi/agent/auth.json" ]; then
            run install -m 600 "$HOME/.pi/agent/auth.json" "$HOME/.pi/agent/auth.json.tmp"
            run mv "$HOME/.pi/agent/auth.json.tmp" "$HOME/.pi/agent/auth.json"
          fi

          for path in ${opts.realConfigs}/pi/agent/*; do
            case "$path" in
              */auth.json) continue ;;
            esac
            $DRY_RUN_CMD ln -sfn $VERBOSE_ARG "$path" "$HOME/.pi/agent/"
          done
        '';
      }
    ]
  );
}
