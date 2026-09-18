{
  pkgs,
  lib,
  config,
  opts,
  ...
}:

let
  cfg = config.myHome.astGrep;
  svelteParser = pkgs.callPackage ../../packages/tree-sitter-htmlx-svelte.nix { };
in
{
  options.myHome.astGrep.enable = lib.mkEnableOption "shared ast-grep rules";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.ast-grep ];

    home.activation.astGrepConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.config"

      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "$HOME/develop/frg"
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "$HOME/.local/lib"

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${svelteParser}/lib/tree-sitter-svelte "$HOME/.local/lib/tree-sitter-svelte"

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/ast-grep "$HOME/.config/ast-grep"

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/sgconfig.yml "$HOME/sgconfig.yml"

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/ast-grep/sgconfig-frg.yml "$HOME/develop/frg/sgconfig.yml"
    '';
  };
}
