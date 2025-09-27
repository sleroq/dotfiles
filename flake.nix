{
  description = "Unified NixOS and Home Manager configurations";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    # Common NixOS flakes
    agenix.url = "github:ryantm/agenix";
    hyprland.url = "github:hyprwm/Hyprland";
    hy3.url = "github:outfoxxed/hy3";
    hy3.inputs.hyprland.follows = "hyprland";

    quickshell.url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
    quickshell.inputs.nixpkgs.follows = "nixpkgs";

    # Per-host nixpkgs pins
    nixpkgs-interplanetary.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-international.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-cumserver.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";

    # Interplanetary flakes
    aagl.url = "github:ezKEa/aagl-gtk-on-nix";
    aagl.inputs.nixpkgs.follows = "nixpkgs-interplanetary";
    winapps.url = "github:winapps-org/winapps";
    winapps.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    zenbrowser-interplanetary.url = "github:youwen5/zen-browser-flake";
    zenbrowser-interplanetary.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    home-manager-interplanetary.url = "github:nix-community/home-manager";
    home-manager-interplanetary.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    # International flakes
    zenbrowser-international.url = "github:youwen5/zen-browser-flake";
    zenbrowser-international.inputs.nixpkgs.follows = "nixpkgs-international";

    home-manager-international.url = "github:nix-community/home-manager";
    home-manager-international.inputs.nixpkgs.follows = "nixpkgs-international";

    # HM-related inputs used by home modules
    nix-gaming.url = "github:fufexan/nix-gaming";
    vicinae.url = "git+https://github.com/vicinaehq/vicinae?ref=refs/tags/v0.13.0"; # Lock version here to hit gh actions cache
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls?rev=45b855f7ec3dccea3c9a95df0b68e27dab842ae4";
    zed-interplanetary.url = "git+https://github.com/zed-industries/zed?ref=nightly&rev=bcc814926361932ab682452154fd96b15eedf37f"; # Lock to hit the cache
    zed-international.url = "github:zed-industries/zed/nightly";

    scrcpyPkgs.url = "github:nixos/nixpkgs/77a0bdd";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    # Cumserver flakes
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs-cumserver";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    mailserver.url = "git+https://gitlab.com/simple-nixos-mailserver/nixos-mailserver.git/";

    # FIXME: Maybe use overlays to avoid following everything?
    sleroq-link.url = "github:sleroq/sleroq.link";
    sleroq-link.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    cum-army.url = "github:sleroq/cum.army";
    cum-army.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    web-cum-army.url = "github:sleroq/web.cum.army";
    web-cum-army.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    reactor.url = "github:sleroq/reactor";
    reactor.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    sieve.url = "git+ssh://git@github.com/sleroq/sieve";
    sieve.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    bayan.url = "github:sleroq/bayan";
    bayan.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    kopoka.url = "git+ssh://git@github.com/sleroq/kopoka";
    kopoka.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    spoiler-images.url = "github:sleroq/spoiler-images";
    spoiler-images.inputs.nixpkgs.follows = "nixpkgs-cumserver";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.easy-hosts.flakeModule ];

      systems = [ "x86_64-nixos" ];

      flake.overlays = import ./overlays/default.nix {
        inherit self nixpkgs;
        inherit (inputs) scrcpyPkgs nixpkgs-master;
      };

      easy-hosts =
        let
          realConfigs = "/home/sleroq/develop/other/dotfiles/home/config";
          withNixpkgsFor = name: extra:
            let key = "nixpkgs-" + name; in
            extra // {
              nixpkgs = if builtins.hasAttr key inputs then builtins.getAttr key inputs else inputs.nixpkgs;
              specialArgs = (extra.specialArgs or { }) // { easyHostsHost = name; };
            };
        in
        {
          hosts = {
            interplanetary = withNixpkgsFor "interplanetary" {
              tags = [ "non-server" ];
              modules = [
                inputs.home-manager-interplanetary.nixosModules.home-manager
                inputs.aagl.nixosModules.default
                { home-manager.users.sleroq.imports = [ ./home/hosts/interplanetary.nix ]; }
              ];
            };

            international = withNixpkgsFor "international" {
              tags = [ "non-server" ];
              modules = [
                inputs.home-manager-international.nixosModules.home-manager
                { home-manager.users.sleroq.imports = [ ./home/hosts/international.nix ]; }
              ];
            };

            cumserver = withNixpkgsFor "cumserver" {
              arch = "x86_64";
              tags = [ "server" ];
              modules = [
                inputs.disko.nixosModules.disko
                inputs.mailserver.nixosModules.default
                inputs.reactor.nixosModules.reactor
                inputs.sieve.nixosModules.sieve
                inputs.nixos-facter-modules.nixosModules.facter
              ];
              specialArgs = {
                inherit inputs;
                secrets = import ./hosts/cumserver/secrets/default.nix;
              };
            };
          };

        shared.modules = [
          (import ./lib/inputs-resolver.nix)
          inputs.agenix.nixosModules.default
          ({ inputs, ... }: { nixpkgs.overlays = [ inputs.self.overlays.default ]; })
        ];

        perTag = tag:
          {
            modules = builtins.concatLists [
              (nixpkgs.lib.optionals (tag == "non-server") [
                ({ inputs, inputsResolved', ... } @ args:
                  (import ./home/default.nix)
                    (args // {
                      agenixModule = inputs.agenix.homeManagerModules.default;
                      vicinae = inputs.vicinae.homeManagerModules.default;
                      inputs' = inputsResolved';
                      inherit (inputs) self;
                      inherit realConfigs;
                    }))
                ./shared
              ])
            ];

            specialArgs =
              nixpkgs.lib.optionalAttrs (tag == "non-server") {
                secrets = import ./shared/secrets/default.nix;
              };
          };
      };
    };
}
