{ pkgs, lib, config, ... }:

let
  cfg = config.myHome.programs.opencode;
in
{
  options.myHome.programs.opencode = {
    enable = lib.mkEnableOption "OpenCode AI coding assistant";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.opencode;
      description = "The opencode package to use. Set to null to only install configuration.";
    };

    ohMyOpencode = {
      enable = lib.mkEnableOption "oh-my-opencode plugin" // { default = true; };
      config = lib.mkOption {
        type = lib.types.attrs;
        default = {
          google_auth = false;
          agents = {
            Sisyphus = { model = "opencode/gemini-3-flash"; };
            librarian = { model = "opencode/gemini-3-flash"; };
            explore = { model = "opencode/gemini-3-flash"; };
            oracle = { model = "opencode/gemini-3-flash"; };
            frontend-ui-ux-engineer = { model = "opencode/gemini-3-pro"; };
            document-writer = { model = "opencode/gemini-3-flash"; };
            multimodal-looker = { model = "opencode/gemini-3-flash"; };
          };
        };
        description = "oh-my-opencode configuration";
      };
    };

    config = lib.mkOption {
      type = lib.types.attrs;
      default = {
        provider = {
          "llama.cpp" = {
            npm = "@ai-sdk/openai-compatible";
            name = "llama-server (local)";
            options = { baseURL = "http://127.0.0.1:8085/"; };
            models = { "qwen3-coder:a3b" = { name = "Qwen3-Coder-30B-A3B-Instruct-GGUF"; }; };
          };
        };
        plugin = [ "oh-my-opencode" ];
     };
      description = "opencode.json configuration";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf (cfg.package != null) {
      home.packages = [ cfg.package ];
    })

    {
      xdg.configFile."opencode/opencode.json".text = builtins.toJSON ({
        "$schema" = "https://opencode.ai/config.json";
      } // cfg.config);
    }

    (lib.mkIf cfg.ohMyOpencode.enable {
      xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON ({
        "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
      } // cfg.ohMyOpencode.config);

      home.activation.installOhMyOpencode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        PATH="${pkgs.bun}/bin:$HOME/.bun/bin:$PATH"
        if ! command -v oh-my-opencode &> /dev/null; then
          run ${pkgs.bun}/bin/bun install -g oh-my-opencode
        fi
      '';
    })
  ]);
}
