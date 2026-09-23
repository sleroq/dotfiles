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
  options.myHome.programs.opencode.enable = lib.mkEnableOption "OpenCode AI coding assistant";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { home.packages = [ pkgs.beans ]; }

      {
        home.activation.installOpencode2 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          PATH="${pkgs.bun}/bin:$HOME/.bun/bin:$PATH"
          run ${pkgs.bun}/bin/bun install -g --ignore-scripts @opencode/cli@latest

          if [ -z "$DRY_RUN_CMD" ]; then
            ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
              for binary in "$HOME"/.bun/install/global/node_modules/@opencode/cli-linux-*/bin/opencode; do
                case "$binary" in
                  *-musl/*) continue ;;
                esac

                ${pkgs.patchelf}/bin/patchelf \
                  --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} \
                  --set-rpath ${lib.makeLibraryPath [ pkgs.glibc ]} \
                  "$binary"
              done
            ''}

            ${pkgs.bun}/bin/bun \
              "$HOME/.bun/install/global/node_modules/@opencode/cli/postinstall.mjs"
          fi
        '';
      }

      {
        home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p $HOME/.config/opencode

          $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
              ${opts.realConfigs}/opencode/* $HOME/.config/opencode/

          if [ -z "$DRY_RUN_CMD" ]; then
            ${pkgs.bun}/bin/bun install --frozen-lockfile \
              --cwd ${opts.realConfigs}/opencode/plugins/direnv
          fi
        '';
      }
    ]
  );
}
