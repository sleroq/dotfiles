{ pkgs, pkgs-unstable, ... }:

{
  imports = [
    # ./emacs.nix
    ./neovim.nix
    ./helix.nix
  ];

  programs.vscode.enable = true;

  home.packages = [
   pkgs-unstable.zed-editor
   # jetbrains.goland
   # jetbrains.gateway
  ];
}
