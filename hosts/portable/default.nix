 { flakeRoot, pkgs, ... }:

{
  imports = [ ./aerospace.nix ];

  system = {
    stateVersion = 6;
  };
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  nix.enable = false; # Disabled nix in preference to determinate-nix
  determinateNix = {
    enable = true;
    determinateNixd.builder.state = "enabled";
  };

  environment.systemPackages = [ pkgs.nh ];
  environment.variables.NH_OS_FLAKE = flakeRoot;

  # Tailscale? https://github.com/nix-darwin/nix-darwin/blob/b8c7ac030211f18bd1f41eae0b815571853db7a2/modules/services/tailscale.nix
  system.primaryUser = "sleroq";
  users.users.sleroq = {
    name = "sleroq";
    home = "/Users/sleroq";
  };
}
