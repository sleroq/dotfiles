{ flakeRoot, pkgs, config, ... }:

let
  curlCaBundle = "/etc/ssl/certs/curl-ca-bundle.crt";
  frgCert = "/Users/sleroq/develop/frg/cert.crt";
in

{
  imports = [
    ./aerospace.nix
    ../../shared/sing-box.nix
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
    sshfs
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
  sleroq.sing-box = {
    # The current proxy has no working IPv6 egress. Advertising an IPv6 TUN
    # makes libcurl/Nix prefer AAAA records and repeatedly hit that broken path.
    enableIPv6 = false;
    directDomains = [
      "zoom.us"
      "teams.microsoft.com"
      "teams.live.com"
      "skype.com"
      "skype.net"
      "cardlink.link"
    ];
    # Process matching is exact and platform-dependent.
    directProcessNames = [
      "steam_osx"
    ];
    # OS route bypasses for bootstrap/proxy endpoints, private LAN/VPN
    # destinations, link-local IPv6, and multicast traffic.
    routeExcludeAddresses = [
      "1.1.1.1/32" # Direct DNS bootstrap for proxy endpoint hostnames.
      "45.144.51.81/32" # node1.yamarkov.ru, selected proxy endpoint.
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "100.64.0.0/10"
      "224.0.0.0/4"
      "fc00::/7"
      "fe80::/10"
      "31.172.71.180/32"
    ];
  };

  # Tailscale? https://github.com/nix-darwin/nix-darwin/blob/b8c7ac030211f18bd1f41eae0b815571853db7a2/modules/services/tailscale.nix
  system.primaryUser = "sleroq";
  users.users.sleroq = {
    name = "sleroq";
    home = "/Users/sleroq";
  };
}
