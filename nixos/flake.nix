{
  description = "Unified NixOS configurations for desktop hosts";

  inputs = {
    # Per-host nixpkgs to decouple updates
    nixpkgs-interplanetary.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-international.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-cumserver.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Default for follows
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/heads/main";
    agenix.url = "github:ryantm/agenix";
    aagl.url = "github:ezKEa/aagl-gtk-on-nix";
    aagl.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    mailserver.url = "git+https://gitlab.com/simple-nixos-mailserver/nixos-mailserver.git/";

    # HM-related inputs used by home modules
    nix-gaming.url = "github:fufexan/nix-gaming";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls?rev=45b855f7ec3dccea3c9a95df0b68e27dab842ae4";
    zed.url = "github:zed-industries/zed?submodules=1&ref=refs/tags/v0.198.0-pre";
    ghostty.url = "github:ghostty-org/ghostty";
    hy3 = {
      url = "github:outfoxxed/hy3";
      inputs.hyprland.follows = "hyprland";
    };
    scrcpyPkgs.url = "github:nixos/nixpkgs/77a0bdd";
    nixpkgs-old.url = "github:nixos/nixpkgs/1c37a89390481e809b9851781026bc9bb840dd90";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
  };

  outputs = { self, nixpkgs, nixpkgs-interplanetary, nixpkgs-international, nixpkgs-cumserver, agenix, aagl, home-manager, disko, nixos-facter-modules, mailserver, ... }@inputs:
  let
    system = "x86_64-linux";
    mkHost = { name, path, nixpkgsInput, extraModules ? [] }:
      nixpkgsInput.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; inherit (self) outputs; };
        modules = [
          path
          ./hosts/shared
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager =
              let
                user = "sleroq";
                repoPath = ../.;
                repoPathString = "/home/${user}/develop/other/dotfiles";
              in
              {
                useGlobalPkgs = true;
                useUserPackages = true;
                sharedModules = [
                  ../home/modules/wms/wayland
                  ../home/modules/programs
                  ../home/modules/editors
                  ../home/modules/gaming.nix
                  ../home/shared
                  inputs.agenix.homeManagerModules.default
                ];
                extraSpecialArgs = {
                  inherit inputs;
                  secrets = import ../home/secrets/default.nix;
                  opts = {
                    inherit repoPath repoPathString;
                    host = name;
                    old-configs = repoPath + /home/.config;
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
                users.sleroq = {
                  imports = [ ../home/hosts/${name}/home.nix ];
                };
              };
          }
        ] ++ extraModules;
      };
  in {
    nixosConfigurations = {
      sleroq-interplanetary = mkHost {
        name = "interplanetary";
        path = ./hosts/interplanetary/configuration.nix;
        nixpkgsInput = nixpkgs-interplanetary;
        extraModules = [ aagl.nixosModules.default ];
      };
      sleroq-international = mkHost {
        name = "international";
        path = ./hosts/international/configuration.nix;
        nixpkgsInput = nixpkgs-international;
        extraModules = [];
      };
      cumserver = nixpkgs-cumserver.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          secrets = import ./hosts/cumserver/secrets/default.nix;
        };
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          mailserver.nixosModules.default
          ./hosts/cumserver/configuration.nix
          nixos-facter-modules.nixosModules.facter
          { config.facter.reportPath = ./hosts/cumserver/facter.json; }
        ];
      };
    };
  };
}

