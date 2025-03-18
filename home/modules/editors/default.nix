{ pkgs, pkgs-unstable, ... }:

{
  imports = [
    # ./emacs.nix
    ./neovim.nix
    ./helix.nix
  ];

  programs.vscode.enable = true;

  # TODO: Add zed configuration

  home.packages = [
   pkgs-unstable.zed-editor
   # jetbrains.goland
   # jetbrains.gateway
  ];
}
