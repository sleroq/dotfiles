{ pkgs, inputs, ... }: {
  home.packages = with inputs.nixpkgs-wayland.packages.${pkgs.system}; [
    swww
  ];
}
