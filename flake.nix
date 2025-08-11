{
  description = "Unified NixOS and Home Manager configurations";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    # Common NixOS flakes
    agenix.url = "github:ryantm/agenix";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/heads/main";
    hy3 = {
      url = "github:outfoxxed/hy3";
      inputs.hyprland.follows = "hyprland";
    };

    # Per-host nixpkgs pins
    nixpkgs-interplanetary.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-international.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-cumserver.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";

    # Interplanetary flakes
    aagl.url = "github:ezKEa/aagl-gtk-on-nix";
    aagl.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    home-manager-interplanetary.url = "github:nix-community/home-manager";
    home-manager-interplanetary.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    # International flakes
    home-manager-international.url = "github:nix-community/home-manager";
    home-manager-international.inputs.nixpkgs.follows = "nixpkgs-international";

    # HM-related inputs used by home modules
    nix-gaming.url = "github:fufexan/nix-gaming";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls?rev=45b855f7ec3dccea3c9a95df0b68e27dab842ae4";
    zed-interplanetary.url = "github:zed-industries/zed?submodules=1&ref=refs/tags/v0.199.3-pre";
    zed-international.url = "github:zed-industries/zed?submodules=1&ref=refs/tags/v0.199.3-pre";

    scrcpyPkgs.url = "github:nixos/nixpkgs/77a0bdd";
    nixpkgs-old.url = "github:nixos/nixpkgs/1c37a89390481e809b9851781026bc9bb840dd90";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    # Cumserver flakes
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs-cumserver";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    mailserver.url = "git+https://gitlab.com/simple-nixos-mailserver/nixos-mailserver.git/";
    sleroq-link = {
      url = "github:sleroq/sleroq.link";
      inputs.nixpkgs.follows = "nixpkgs-cumserver";
    };
    cum-army = {
      url = "github:sleroq/cum.army";
      inputs.nixpkgs.follows = "nixpkgs-cumserver";
    };
    web-cum-army = {
      # url = "github:sleroq/web.cum.army";
      url = "path:/home/sleroq/develop/other/web.cum.army";
      inputs.nixpkgs.follows = "nixpkgs-cumserver";
    };
    reactor = {
      url = "github:sleroq/reactor";
      inputs.nixpkgs.follows = "nixpkgs-cumserver";
    };
    sieve = {
      url = "git+ssh://git@github.com/sleroq/sieve";
      inputs.nixpkgs.follows = "nixpkgs-cumserver";
    };
    slusha = {
      url = "github:sleroq/slusha";
      inputs.nixpkgs.follows = "nixpkgs-cumserver";
    };
    bayan = {
      url = "github:sleroq/bayan";
      inputs.nixpkgs.follows = "nixpkgs-cumserver";
    };
    kopoka = {
      url = "git+ssh://git@github.com/sleroq/kopoka";
      inputs.nixpkgs.follows = "nixpkgs-cumserver";
    };
    spoiler-images = {
      url = "github:sleroq/spoiler-images";
      inputs.nixpkgs.follows = "nixpkgs-cumserver";
    };
  };

  outputs = { nixpkgs, ... }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.easy-hosts.flakeModule ];

      systems = [ "x86_64-nixos" ];

      easy-hosts =
        let
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
              tags = [ "desktop" "non-server" ];
            };

            international = withNixpkgsFor "international" {
              tags = [ "laptop" "non-server" ];
            };

            cumserver = withNixpkgsFor "cumserver" {
              arch = "x86_64";
              tags = [ "server" ];
              specialArgs = {
                inherit inputs;
                secrets = import ./hosts/cumserver/secrets/default.nix;
              };
            };
          };

        shared.modules = [
          # Resolver that computes inputsResolved' and inputFor.
          # Convention: an input named "foo-bar" is a host-specific override for base "foo" on host "bar".
          # If there is no "foo-${host}", we fall back to shared base "foo".
          ({ lib, inputs', easyHostsHost, ... }:
            let
              host = easyHostsHost;
              names = builtins.attrNames inputs';
              dashed = builtins.filter (n: builtins.match ".*-.*" n != null) names;
              baseOf = n: builtins.head (builtins.split "-" n);
              bases = lib.unique (builtins.map baseOf dashed);
              resolveFor = base:
                let hostKey = base + "-" + host; in
                if builtins.hasAttr hostKey inputs' then builtins.getAttr hostKey inputs'
                else if builtins.hasAttr base inputs' then builtins.getAttr base inputs'
                else null;
              aliasList = builtins.filter (a: a.value != null)
                (builtins.map (b: { name = b; value = resolveFor b; }) bases);
              aliasSet = lib.listToAttrs aliasList;
              resolved = inputs' // aliasSet;
              inputFor = name:
                let hostKey = name + "-" + host; in
                if builtins.hasAttr hostKey resolved then builtins.getAttr hostKey resolved
                else builtins.getAttr name resolved;
            in {
              _module.args."inputsResolved'" = resolved;
              _module.args.inputFor = inputFor;
            }
          )

          inputs.agenix.nixosModules.default
        ];

        perTag = tag:
          let
            system = "x86_64-linux"; # FIXME
            user = "sleroq"; # FIXME
            repoPath = ./.; # FIXME
            repoPathString = "/home/${user}/develop/other/dotfiles";
          in
          {
            modules = builtins.concatLists [
              (nixpkgs.lib.optionals (tag == "non-server") [
                ({ inputs, inputsResolved', inputFor, ... }:
                  {
                    home-manager =
                      {
                        useGlobalPkgs = true;
                        useUserPackages = true;
                        sharedModules = [
                          ./home/modules/wms/wayland
                          ./home/modules/programs
                          ./home/modules/editors
                          ./home/modules/gaming.nix
                          ./home/shared
                          inputs.agenix.homeManagerModules.default
                        ];

                        extraSpecialArgs = {
                          inherit inputs inputFor;
                          # pass host-resolved inputs' into Home Manager
                          "inputs'" = inputsResolved'; # TODO: not sure this is a best way

                          secrets = import ./home/secrets/default.nix;
                          opts = {
                            configs = repoPath + /home/config;
                            realConfigs = repoPathString + "/home/config";
                          };
                          pkgs-old = import inputs.nixpkgs-old {
                            inherit system;
                            config.allowUnfree = true;
                            config.permittedInsecurePackages = [ "electron-13.6.9" ];
                          };
                          pkgs-master = import inputs.nixpkgs-master { inherit system; config.allowUnfree = true; };
                          scrcpyPkgs = import inputs.scrcpyPkgs { inherit system; };
                        };
                      };
                  })
              ])

              (nixpkgs.lib.optionals (tag == "non-server") [ ./nixos/hosts/shared ])

              (nixpkgs.lib.optionals (tag == "laptop") [
                inputs.home-manager-international.nixosModules.home-manager
                {
                  home-manager.users.sleroq.imports = [ ./home/hosts/international.nix ]; # FIXME
                }
              ])

              (nixpkgs.lib.optionals (tag == "desktop") [
                inputs.home-manager-interplanetary.nixosModules.home-manager
                inputs.aagl.nixosModules.default
                { 
                  home-manager.users.sleroq.imports = [ ./home/hosts/interplanetary.nix ]; # FIXME
                }
              ])

              (nixpkgs.lib.optionals (tag == "server") [
                inputs.disko.nixosModules.disko
                inputs.mailserver.nixosModules.default
                inputs.reactor.nixosModules.reactor
                inputs.sieve.nixosModules.sieve
                inputs.slusha.nixosModules.slusha
                inputs.nixos-facter-modules.nixosModules.facter
              ])
            ];
          };
      };
    };
}
