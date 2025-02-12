{ pkgs, lib, ... }:

{
  home.activation.hyprpolkitagent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    systemctl --user enable --now hyprpolkitagent
  '';

  home.packages = with pkgs; [
    hyprpolkitagent
  ];
}
