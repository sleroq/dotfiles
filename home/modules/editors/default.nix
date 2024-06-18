{ pkgs, ... }:

{
  imports = [
    # ./emacs.nix
    ./neovim.nix
    ./helix.nix
  ];

  programs.vscode.enable = true;

  home.packages = with pkgs; [
    zed-editor
   # jetbrains.goland
   # jetbrains.gateway
  ];
}
