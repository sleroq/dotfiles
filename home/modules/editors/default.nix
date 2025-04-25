{ inputs, pkgs, pkgs-unstable, ... }:

{
  imports = [
    # ./emacs.nix
    ./neovim.nix
    ./helix.nix
  ];

  programs.vscode.enable = true;

  # TODO: Add zed configuration
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zed-editor.enable

  home.packages = [
    pkgs-unstable.code-cursor
    pkgs-unstable.zed-editor
    # inputs.zed.packages.${pkgs.system}.default
   # pkgs.jetbrains.goland
   # pkgs.jetbrains.gateway
  ];
}
