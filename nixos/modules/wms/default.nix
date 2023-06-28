{ ... }:
{
  imports = [
    ./wayland/default.nix
    ./wayland/sway.nix
    ./x11/leftwm.nix
  ];
}
