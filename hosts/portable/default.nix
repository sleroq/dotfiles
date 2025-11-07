 { inputs', realConfigs, self, pkgs, ... }:

{
  imports = [ ./aerospace.nix ];

  system = {
    stateVersion = 6;
  };
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.optimise.automatic = true;
  nix = {
    # gc.automatic = true; # FIXME
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

  # Tailscale? https://github.com/nix-darwin/nix-darwin/blob/b8c7ac030211f18bd1f41eae0b815571853db7a2/modules/services/tailscale.nix
  system.primaryUser = "sleroq";
  users.users.sleroq = {
    name = "sleroq";
    home = "/Users/sleroq";
  };
}
