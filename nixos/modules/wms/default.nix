{ pkgs,... }: {
  imports = [
    # ./lemurs.nix
    # ./x11/leftwm.nix
    ./wayland/default.nix
    ./x11/default.nix
  ];
}
