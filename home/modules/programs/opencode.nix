{
  pkgs,
  lib,
  config,
  opts,
  ...
}:

let
  cfg = config.myHome.programs.opencode;
in
{
  options.myHome.programs.opencode = {
    enable = lib.mkEnableOption "OpenCode AI coding assistant";

    useBun = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install opencode using activation script with bun instead of using nixpkgs package.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { home.packages = [ pkgs.beans ]; }

      (lib.mkIf (!cfg.useBun) {
        home.packages = [ pkgs.opencode ];
      })

      (lib.mkIf cfg.useBun {
        home.activation.installOpencode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          PATH="${pkgs.bun}/bin:$HOME/.bun/bin:$PATH"
          if ! command -v opencode &> /dev/null; then
            run ${pkgs.bun}/bin/bun install -g opencode
          fi
        '';
      })

      {
        home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p $HOME/.config/opencode

          $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
              ${opts.realConfigs}/opencode/* $HOME/.config/opencode/
        '';
      }
    ]
  );
}
