{
  description = "Unified NixOS and Home Manager configurations";

  inputs = {
    # these should not be used for any system and just for building. but I'm not verifying that anywhere
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    # Common NixOS flakes
    agenix.url = "github:ryantm/agenix";
    # hyprland.url = "github:hyprwm/Hyprland/dd220ef";
    # hy3.url = "github:outfoxxed/hy3/4b42544";
    hyprland.url = "github:hyprwm/Hyprland";
    hy3.url = "github:outfoxxed/hy3";
    hy3.inputs.hyprland.follows = "hyprland";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    caelestia_shell-interplanetary.url = "github:caelestia-dots/shell";
    caelestia_shell-interplanetary.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    caelestia_shell-international.url = "github:caelestia-dots/shell";
    caelestia_shell-international.inputs.nixpkgs.follows = "nixpkgs-international";

    # Per-host nixpkgs pins
    nixpkgs-interplanetary.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-international.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-cumserver.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-portable.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";

    # Interplanetary flakes
    aagl.url = "github:ezKEa/aagl-gtk-on-nix";
    aagl.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    home-manager-interplanetary.url = "github:nix-community/home-manager";
    home-manager-interplanetary.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    home-manager-international.url = "github:nix-community/home-manager";
    home-manager-international.inputs.nixpkgs.follows = "nixpkgs-international";

    # HM-related inputs used by home modules
    nix-gaming.url = "github:fufexan/nix-gaming";

    vicinae.url = "git+https://github.com/vicinaehq/vicinae?ref=refs/tags/v0.19.6"; # Lock version here to hit gh actions cache
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls?rev=45b855f7ec3dccea3c9a95df0b68e27dab842ae4";
    zed-interplanetary.url = "github:zed-industries/zed/nightly"; # Lock to hit the cache
    zed-international.url = "github:zed-industries/zed/nightly";

    scrcpyPkgs.url = "github:nixos/nixpkgs/77a0bdd";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-beans.url = "github:sleroq/nixpkgs/init-beans";

    # Cumserver flakes
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs-cumserver";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    mailserver.url = "git+https://gitlab.com/simple-nixos-mailserver/nixos-mailserver.git/";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    tuwunel.url = "github:matrix-construct/tuwunel"; # FIXME: switch to nixpkgs when they catch up (if they ever do)
    tuwunel.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    # FIXME: Maybe use overlays to avoid following everything?
    sleroq-link.url = "github:sleroq/sleroq.link";
    sleroq-link.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    cum-army.url = "github:sleroq/cum.army";
    cum-army.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    web-cum-army.url = "github:sleroq/web.cum.army";
    # web-cum-army.url = "/home/sleroq/develop/other/web.cum.army";
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

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs-portable";
    determinate.url = "github:DeterminateSystems/determinate";

    home-manager-portable.url = "github:nix-community/home-manager";
    home-manager-portable.inputs.nixpkgs.follows = "nixpkgs-portable";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.easy-hosts.flakeModule ];

      systems = [
        "x86_64-nixos"
        "aarch64-darwin"
      ];

      flake.overlays = import ./overlays/default.nix {
        inherit self nixpkgs;
        inherit (inputs) scrcpyPkgs nixpkgs-beans nixpkgs-master ;
      };

      # FIXME: This is a bit overengineered
      easy-hosts =
        let
          username = "sleroq";
          withNixpkgsFor =
            name: extra:
            let
              key = "nixpkgs-" + name;
            in
            extra
            // {
              # TODO: Refactor
              nixpkgs = if builtins.hasAttr key inputs then builtins.getAttr key inputs else inputs.nixpkgs;
              specialArgs = (extra.specialArgs or { }) // {
                easyHostsHost = name;
              };
            };
        in
        {
          hosts = {
            interplanetary = withNixpkgsFor "interplanetary" {
              tags = [ "linux-personal" ];

              specialArgs = {
                inherit username;
                flakeRoot = "/home/sleroq/develop/other/dotfiles";
              };
              modules = [
                inputs.home-manager-interplanetary.nixosModules.home-manager
                inputs.aagl.nixosModules.default
                {
                  home-manager.sharedModules = [
                    inputs.caelestia_shell-interplanetary.homeManagerModules.default
                  ];
                }
                { home-manager.users.${username}.imports = [ ./home/hosts/interplanetary.nix ]; }
              ];
            };

            international = withNixpkgsFor "international" {
              tags = [ "linux-personal" ];

              specialArgs = {
                inherit username;
                flakeRoot = "/home/sleroq/develop/other/dotfiles";
              };
              modules = [
                inputs.home-manager-international.nixosModules.home-manager
                {
                  home-manager.sharedModules = [
                    inputs.caelestia_shell-international.homeManagerModules.default
                  ];
                }
                { home-manager.users.${username}.imports = [ ./home/hosts/international.nix ]; }
              ];
            };

            cumserver = withNixpkgsFor "cumserver" {
              arch = "x86_64";
              tags = [ "server" ];

              specialArgs = {
                inherit inputs;
                secrets = import ./hosts/cumserver/secrets/default.nix;
              };
              modules = [
                (
                  { inputs, ... }:
                  {
                    nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
                  }
                )
                inputs.disko.nixosModules.disko
                inputs.mailserver.nixosModules.default
                inputs.reactor.nixosModules.reactor # TODO: Avoid using system modules for stuff like this
                inputs.sieve.nixosModules.sieve
                inputs.nixos-facter-modules.nixosModules.facter
                inputs.nix-minecraft.nixosModules.minecraft-servers
              ];
            };

            portable =
              let
                flakeRoot = "/Users/sleroq/develop/dotfiles";
              in
              withNixpkgsFor "portable" {
                tags = [ "macos" ];
                arch = "aarch64";
                class = "darwin";

                specialArgs = {
                  inherit username flakeRoot;
                };

                modules = [
                  inputs.determinate.darwinModules.default
                  inputs.agenix.darwinModules.default
                  inputs.home-manager-portable.darwinModules.home-manager
                  (
                    { inputs, inputsResolved', ... }:
                    {
                      home-manager = {
                        useGlobalPkgs = true;
                        useUserPackages = true;
                        sharedModules = [
                          inputs.agenix.homeManagerModules.default
                          ./home/modules/programs
                          ./home/modules/editors
                          ./home/modules/development.nix
                        ];
                        users.${username}.imports = [ ./home/hosts/portable.nix ];

                        extraSpecialArgs = {
                          inherit self;
                          inputs' = inputsResolved';
                          opts = rec {
                            inherit username;
                            flakeRoot = "/Users/sleroq/develop/dotfiles";
                            realConfigs = "${flakeRoot}/home/config";
                          };
                        };
                      };
                    }
                  )
                ];
              };
          };

          shared.modules = [
            (import ./lib/inputs-resolver.nix)
            (
              { inputs, ... }:
              {
                nixpkgs.overlays = [ inputs.self.overlays.default ];
              }
            )
          ];

          perTag = tag: {
            modules = builtins.concatLists [
              (nixpkgs.lib.optionals (tag == "linux-personal") [
                (
                  { inputs, inputsResolved', ... }@args:
                  (import ./home/default.nix) (
                    args
                    // rec {
                      agenixModule = inputs.agenix.homeManagerModules.default;
                      vicinae = inputs.vicinae.homeManagerModules.default;
                      inputs' = inputsResolved';
                      inherit (inputs) self;

                      # FIXME: Feels like this should really be per-host, without this confusing grouping
                      flakeRoot = "/home/sleroq/develop/other/dotfiles";
                      realConfigs = "${flakeRoot}/home/config";
                    }
                  )
                )

                ./shared
              ])
              (nixpkgs.lib.optionals (tag != "macos") [
                inputs.agenix.nixosModules.default
              ])
            ];

            specialArgs = nixpkgs.lib.optionalAttrs (tag == "linux-personal") {
              secrets = import ./shared/secrets/default.nix;
            };
          };
        };
    };
}
