{
  description = "Unified NixOS and Home Manager configurations";

  inputs = {
    # these should not be used for any system and just for building. but I'm not verifying that anywhere
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    tuwunel.url = "github:matrix-construct/tuwunel/v1.9.0";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    sb.url = "github:sleroq/proxy-helper";
    sb.inputs.nixpkgs.follows = "nixpkgs";

    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    # Common NixOS flakes
    agenix.url = "github:ryantm/agenix";
    hyprland.url = "github:hyprwm/Hyprland/v0.56.2";
    hyprland.inputs.nixpkgs.follows = "nixpkgs-interplanetary";
    hyprland.inputs.hyprutils.url = "github:hyprwm/hyprutils/v0.14.2";
    hyprland.inputs.xdph.url = "github:hyprwm/xdg-desktop-portal-hyprland/v1.4.1";
    hy3.url = "github:outfoxxed/hy3/hl0.56.0.1";
    hy3.inputs.hyprland.follows = "hyprland";
    dwl.url = "git+https://codeberg.org/dwl/dwl?ref=refs/tags/v0.9";
    dwl.flake = false;
    # Hyprland 0.56 requires Glaze 7; the host provides Glaze 8.
    glaze.url = "github:stephenberry/glaze/v7.2.0";
    glaze.flake = false;

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    caelestia_shell-interplanetary.url = "github:caelestia-dots/shell/v2.5.0";
    caelestia_shell-interplanetary.inputs.nixpkgs.follows = "nixpkgs-interplanetary";
    caelestia_shell-interplanetary.inputs.quickshell.url = "git+https://git.outfoxxed.me/quickshell/quickshell?ref=refs/tags/v0.3.2";

    # Per-host nixpkgs pins
    nixpkgs-interplanetary.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-cumserver.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-roundy.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-div.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-26.05&rev=b3fe9581c9061c749abef42b6d4ee7b7c05c33fa&shallow=1";
    nixpkgs-portable.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";

    # Interplanetary flakes
    aagl.url = "github:ezKEa/aagl-gtk-on-nix";
    aagl.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    home-manager-interplanetary.url = "github:nix-community/home-manager";
    home-manager-interplanetary.inputs.nixpkgs.follows = "nixpkgs-interplanetary";

    home-manager-cumserver.url = "github:nix-community/home-manager/f3a30376bb9eb2f6f61816be7d6ed954b6d2a3b9";
    home-manager-cumserver.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    cliamp.url = "github:bjarneo/cliamp";
    cliamp.inputs.nixpkgs.follows = "nixpkgs-portable";

    # HM-related inputs used by home modules
    nix-gaming.url = "github:fufexan/nix-gaming";

    vicinae.url = "git+https://github.com/vicinaehq/vicinae?ref=refs/tags/v0.20.1"; # Lock version here to hit gh actions cache
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls";
    zed-interplanetary.url = "github:zed-industries/zed/nightly"; # Lock to hit the cache

    scrcpyPkgs.url = "github:nixos/nixpkgs/77a0bdd";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    # Single-quality MoQ pilot; release source is copied to the build host.
    moq-box.url = "path:/nix/store/ylvjypxd1ajx918qk694wsdqff922asb-source";

    # Cumserver flakes
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs-cumserver";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    mailserver.url = "git+https://gitlab.com/simple-nixos-mailserver/nixos-mailserver.git/";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    # FIXME: Maybe use overlays to avoid following everything?
    sleroq-link.url = "github:sleroq/sleroq.link";
    sleroq-link.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    cum-army.url = "github:sleroq/cum.army";
    cum-army.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    reactor.url = "github:sleroq/reactor";

    # Immutable local release until Starflake is published; rooted on cumserver.
    starflake.url = "path:/nix/store/54cvmdx330v5f81d0b7gdrvb6qvy6kzl-source";
    starflake.inputs.nixpkgs.follows = "nixpkgs-cumserver";

    # Initial Roundy release until its native package is published upstream.
    roundy.url = "path:/nix/store/6g2pvnd4rqc1rjm9v2fli1clx5lg6h91-source";
    roundy.inputs.nixpkgs-stable.follows = "nixpkgs-roundy";

    music-link.url = "github:sleroq/music-link";
    # music-link.url = "path:/Users/sleroq/develop/music-link";

    # Keep the module pinned; the host overrides its package with the running legacy binary.
    # Future bot-split deployment (requires the new SIEVE_* credentials):
    # sieve.url = "git+ssh://git@github.com/sleroq/sieve";
    sieve.url = "git+ssh://git@github.com/sleroq/sieve?rev=7696c1bdc3c4f2e43b93a801d0b7012c3398be7e";

    bayan.url = "github:sleroq/bayan";

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
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, ... }:
        {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              age
              coreutils
              nixfmt
              python3
            ];
          };
        };

      flake.overlays = import ./overlays/default.nix {
        inherit self nixpkgs;
        inherit (inputs)
          scrcpyPkgs
          nixpkgs-master
          rust-overlay
          sb
          ;
      };

      flake.homeConfigurations."dev@cumserver" =
        inputs.home-manager-cumserver.lib.homeManagerConfiguration
          {
            pkgs = import inputs.nixpkgs-cumserver {
              system = "x86_64-linux";
              overlays = [ self.overlays.default ];
            };

            modules = [ ./home/hosts/cumserver-dev.nix ];

            extraSpecialArgs = {
              inherit self;
            };
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
                inputs.sb.nixosModules.default
                inputs.aagl.nixosModules.default
                {
                  home-manager.sharedModules = [
                    inputs.caelestia_shell-interplanetary.homeManagerModules.default
                  ];
                }
                { home-manager.users.${username}.imports = [ ./home/hosts/interplanetary.nix ]; }
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
                inputs.starflake.nixosModules.default
                inputs.sieve.nixosModules.sieve
                inputs.nixos-facter-modules.nixosModules.facter
                inputs.nix-minecraft.nixosModules.minecraft-servers
              ];
            };

            div = withNixpkgsFor "div" {
              arch = "x86_64";
              tags = [ "server" ];

              specialArgs = {
                inherit inputs;
              };

              modules = [
                inputs.disko.nixosModules.disko
                inputs.starflake.nixosModules.default
              ];
            };

            roundy = withNixpkgsFor "roundy" {
              arch = "x86_64";
              tags = [ "server" ];
              specialArgs = {
                inherit inputs;
                secrets = import ./hosts/roundy/secrets/default.nix;
              };
              modules = [ inputs.starflake.nixosModules.default ];
            };

            ru-relay = withNixpkgsFor "ru-relay" {
              arch = "x86_64";
              tags = [ "server" ];

              specialArgs.secrets = import ./hosts/ru-relay/secrets/default.nix;
              modules = [
                inputs.disko.nixosModules.disko
                inputs.moq-box.nixosModules.default
              ];
            };

            warsaw = withNixpkgsFor "warsaw" {
              arch = "x86_64";
              tags = [ "server" ];

              specialArgs.secrets = import ./hosts/warsaw/secrets/default.nix;
              modules = [ inputs.disko.nixosModules.disko ];
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
                  inputs.sb.darwinModules.default
                  inputs.home-manager-portable.darwinModules.home-manager
                  (
                    { inputs, inputsResolved', ... }:
                    {
                      home-manager = {
                        useGlobalPkgs = true;
                        useUserPackages = true;
                        backupFileExtension = "hm-bak";
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
