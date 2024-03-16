{ pkgs,... }: {
  imports = [
    ./wayland.nix
    ./x11.nix
  ];

  environment.systemPackages = with pkgs; [
    xdg-utils
  ];
}
