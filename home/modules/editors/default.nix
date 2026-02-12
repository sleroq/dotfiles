{ inputs', pkgs, lib, config, opts, ... }:

let
  cfg = config.myHome.editors;
in
{
  options.myHome.editors = {
    vscode.enable = lib.mkEnableOption "Visual Studio Code";
    cursor.enable = lib.mkEnableOption "Cursor";
    datagrip.enable = lib.mkEnableOption "DataGrip";
    neovim = {
      enable = lib.mkEnableOption "Neovim";
      enableNeovide = lib.mkEnableOption "Neovide";
      default = lib.mkEnableOption "default env";
    };
    helix.enable = lib.mkEnableOption "Helix";
    zed = {
      enable = lib.mkEnableOption "Zed Editor";
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = inputs'.zed.packages.default;
        description = "The Zed package to use. Set to null to enable config without installing.";
      };
      default = lib.mkEnableOption "default env";
    };
    emacs.enable = lib.mkEnableOption "Emacs";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.vscode.enable {
      programs.vscode.enable = true;
    })

    # TODO: Get rid of package-toggle options?
    (lib.mkIf cfg.datagrip.enable {
      home.packages = [ pkgs.jetbrains.datagrip ];
    })

    (lib.mkIf cfg.cursor.enable {
      home.packages = [ pkgs.code-cursor ];
    })

    (lib.mkIf cfg.neovim.enable (import ./neovim.nix { inherit pkgs lib opts inputs'; }))
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

    (lib.mkIf cfg.zed.enable (import ./zed.nix { inherit pkgs lib opts inputs' config; }))
    (lib.mkIf (cfg.zed.enable && cfg.zed.default) {
      home.sessionVariables.EDITOR = "zed";
    })
  ];
}
