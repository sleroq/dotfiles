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
  yaml = pkgs.formats.yaml { };
  configFor = ruleDirs: {
    inherit ruleDirs;
    customLanguages.svelte = {
      libraryPath = "${svelteParser}/lib/tree-sitter-svelte";
      extensions = [ "svelte" ];
      languageSymbol = "tree_sitter_svelte";
    };
    languageInjections = [
      {
        hostLanguage = "svelte";
        rule.pattern = "<script>$CONTENT</script>";
        injected = "javascript";
      }
      {
        hostLanguage = "svelte";
        rule.pattern = ''<script lang="ts">$CONTENT</script>'';
        injected = "typescript";
      }
    ];
  };
  homeConfig = yaml.generate "sgconfig.yml" (configFor [
    "${opts.realConfigs}/ast-grep/rules/common"
  ]);
  frgConfig = yaml.generate "sgconfig-frg.yml" (configFor [
    "${opts.realConfigs}/ast-grep/rules/common"
    "${opts.realConfigs}/ast-grep/rules/frg"
  ]);
in
{
  options.myHome.astGrep.enable = lib.mkEnableOption "shared ast-grep rules";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.ast-grep ];

    home.activation.astGrepConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.config"

      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "$HOME/develop/frg"

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/ast-grep "$HOME/.config/ast-grep"

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${homeConfig} "$HOME/sgconfig.yml"

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${frgConfig} "$HOME/develop/frg/sgconfig.yml"
    '';
  };
}
