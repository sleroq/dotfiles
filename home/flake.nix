{
  description = "Unified Home Manager configurations for all hosts";

  inputs = {
    # Per-host nixpkgs to decouple updates
    nixpkgs-interplanetary.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-international.url = "github:nixos/nixpkgs/nixos-unstable";
    # Keep a default nixpkgs for inputs that require follows; not used for pkgs directly
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    scrcpyPkgs.url = "github:nixos/nixpkgs/77a0bdd";
    nixpkgs-old.url = "github:nixos/nixpkgs/1c37a89390481e809b9851781026bc9bb840dd90";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    secrets = {
      flake = false;
      url = "path:./secrets";
    };

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls?rev=45b855f7ec3dccea3c9a95df0b68e27dab842ae4";
    zed.url = "github:zed-industries/zed?submodules=1&ref=refs/tags/v0.198.0-pre";
    agenix.url = "github:ryantm/agenix";

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/heads/main";

    hy3 = {
      url = "github:outfoxxed/hy3";
      inputs.hyprland.follows = "hyprland";
    };

    ghostty.url = "github:ghostty-org/ghostty";
  };

  outputs =
    { self
    , home-manager
    , nixpkgs
    , nixpkgs-interplanetary
    , nixpkgs-international
    , nixpkgs-old
    , nixpkgs-master
    , secrets
    , scrcpyPkgs
    , ...
    }:
    let
      system = "x86_64-linux";
      user = "sleroq";
      repoPath = ../.; # repository root
      repoPathString = "/home/${user}/develop/other/dotfiles";
      myOverlay = final: prev: {};

      mkHome = { host, hostHomeModule, nixpkgsInput, withOverlay ? true }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgsInput {
            inherit system;
            overlays = (if withOverlay then [ myOverlay ] else []);
          };

          modules = [
            hostHomeModule
            ./modules/wms/wayland
            ./modules/programs
            ./modules/editors
            ./modules/gaming.nix
            ./shared
            self.inputs.agenix.homeManagerModules.default
          ];

          extraSpecialArgs = {
            inherit (self) inputs;
            secrets = import "${secrets}/default.nix";
            opts = {
              inherit host repoPath repoPathString;
              old-configs = repoPath + /home/.config;
              configs = repoPath + /home/config;
              realConfigs = repoPathString + "/home/config";
            };
            pkgs-old = import nixpkgs-old {
              inherit system;
              config.allowUnfree = true;
              # For ObinsKit
              config.permittedInsecurePackages = [
                "electron-13.6.9"
              ];
            };
            pkgs-master = import nixpkgs-master {
              inherit system;
              config.allowUnfree = true;
            };
            scrcpyPkgs = import scrcpyPkgs {
              inherit system;
            };
          };
        };
    in
    {
      # Use namespaced attributes to distinguish hosts
      homeConfigurations = {
        "sleroq@interplanetary" = mkHome {
          host = "interplanetary";
          hostHomeModule = ./hosts/interplanetary/home.nix;
          nixpkgsInput = nixpkgs-interplanetary;
          withOverlay = true;
        };

        "sleroq@international" = mkHome {
          host = "international";
          hostHomeModule = ./hosts/international/home.nix;
          nixpkgsInput = nixpkgs-international;
          withOverlay = false;
        };
      };
    };
}

