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
in
{
  options.myHome.programs.pi = {
    enable = lib.mkEnableOption "Pi coding agent";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.activation.installPi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          PATH="${pkgs.bun}/bin:$HOME/.bun/bin:$PATH"
          installedVersion="$(pi --version 2>/dev/null || true)"
          oldestVersion="$(${pkgs.coreutils}/bin/printf '%s\n' ${minPiVersion} "$installedVersion" | ${pkgs.coreutils}/bin/sort -V | ${pkgs.coreutils}/bin/head -n 1)"
          if ! command -v pi &> /dev/null || [ "$oldestVersion" != "${minPiVersion}" ]; then
            run ${pkgs.bun}/bin/bun install -g @earendil-works/pi-coding-agent@latest
          fi
        '';
      }

      {
        home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p $HOME/.pi/agent

          $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
              ${opts.realConfigs}/pi/agent/* $HOME/.pi/agent/
        '';
      }
    ]
  );
}
