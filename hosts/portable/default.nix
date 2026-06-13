{ flakeRoot, pkgs, config, ... }:

let
  curlCaBundle = "/etc/ssl/certs/curl-ca-bundle.crt";
  frgCert = "/Users/sleroq/develop/frg/cert.crt";
in

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
  environment.variables = {
    NH_OS_FLAKE = flakeRoot;
    CURL_CA_BUNDLE = curlCaBundle;
  };

  system.activationScripts.extraActivation.text = ''
    install -d -m 0755 /etc/ssl/certs
    cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt ${frgCert} > ${curlCaBundle}
  '';

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
    logLevel = "warn";
  };

  # Tailscale? https://github.com/nix-darwin/nix-darwin/blob/b8c7ac030211f18bd1f41eae0b815571853db7a2/modules/services/tailscale.nix
  system.primaryUser = "sleroq";
  users.users.sleroq = {
    name = "sleroq";
    home = "/Users/sleroq";
  };
}
