{ inputs', pkgs, pkgs-master, lib, config, opts, ... }:

let
  cfg = config.myHome.editors;
in
{
  options.myHome.editors = {
    vscode.enable = lib.mkEnableOption "Visual Studio Code";
    cursor.enable = lib.mkEnableOption "Cursor";
    neovim = {
      enable = lib.mkEnableOption "Neovim (imports ./neovim.nix)";
      enableNeovide = lib.mkEnableOption "Neovide";
      default = lib.mkEnableOption "default env";
    };
    helix.enable = lib.mkEnableOption "Helix (imports ./helix.nix)";
    zed.enable = lib.mkEnableOption "Zed Editor";
    emacs.enable = lib.mkEnableOption "Emacs (imports ./emacs.nix)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.vscode.enable {
      programs.vscode.enable = true;
    })

    (lib.mkIf cfg.cursor.enable {
      home.packages = [ pkgs-master.code-cursor ];
    })

    (lib.mkIf cfg.neovim.enable (import ./neovim.nix { inherit pkgs lib opts; }))
    (lib.mkIf (cfg.neovim.enable && cfg.neovim.default) {
      home.sessionVariables.EDITOR = "nvim";
    })

    (lib.mkIf (cfg.neovim.enable && cfg.neovim.enableNeovide) {
      programs.neovide = {
        enable = true;
        settings = {};
      };
    })

    (lib.mkIf cfg.helix.enable (import ./helix.nix { inherit pkgs; }))

    (lib.mkIf cfg.emacs.enable (import ./emacs.nix { inherit pkgs lib opts; }))

    (lib.mkIf cfg.zed.enable {
      home.packages = [ inputs'.zed.packages.default ];
    })
  ];
}
