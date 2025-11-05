 { inputs', realConfigs, self, pkgs, ... }:

{
  imports = [ ./aerospace.nix ];

  system = {
    stateVersion = 6;
  };
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.optimise.automatic = true;
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  # programs.nh = {
  #   enable = true;
  #   flake = "/Users/sleroq/develop/other/dotfiles"; # TODO: infer from args
  # };

  system.primaryUser = "sleroq";
  users.users.sleroq = {
    name = "sleroq";
    home = "/Users/sleroq";
  };
}
