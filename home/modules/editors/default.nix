{ pkgs, ... }:

{
  imports = [
    ./emacs.nix
    ./neovim.nix
  ];

  home.packages = with pkgs; [
    # helix
    vscode-fhs
    # lapce
    jetbrains-toolbox
  ];
}
