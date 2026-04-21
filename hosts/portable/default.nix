 { flakeRoot, pkgs, config, ... }:

{
  imports = [
    ./aerospace.nix
    ../../modules/sing-box.nix
  ];

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

  environment.systemPackages = with pkgs; [
    nh
    git-crypt # Required to build this nix repo...
  ];
  environment.variables.NH_OS_FLAKE = flakeRoot;

  system.defaults.NSGlobalDomain =  {
    NSWindowShouldDragOnGesture = true;
    NSAutomaticWindowAnimationsEnabled = false; # Disable windows opening animations
  };

  documentation.enable = false;

  age.identityPaths = [ "/var/lib/agenix-key.txt" ];
  age.secrets.sing-box-outbounds = {
    file = ../../shared/secrets/sing-box-outbounds.jsonc;
    mode = "0644";
  };

  sleroq.sing-box = {
    enable = true;
    outboundsFile = config.age.secrets.sing-box-outbounds.path;
    routeExcludeAddresses = [
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "83.69.209.222/32"
    ];
    settings = {
      # log.level = "warn";
    };
  };

  # Tailscale? https://github.com/nix-darwin/nix-darwin/blob/b8c7ac030211f18bd1f41eae0b815571853db7a2/modules/services/tailscale.nix
  system.primaryUser = "sleroq";
  users.users.sleroq = {
    name = "sleroq";
    home = "/Users/sleroq";
  };
}
