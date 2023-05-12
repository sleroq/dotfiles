{ pkgs, ... }:

{
  imports = [
    ./emacs.nix
    ./neovim.nix
    ./helix.nix
  ];

  programs.vscode.enable = true;

  home.packages = with pkgs; [
    lapce
    jetbrains-toolbox
  ];
}
