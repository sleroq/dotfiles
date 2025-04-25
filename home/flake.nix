{
  description = "Home Manager configuration of Sleroq";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # For old packages, like obinskit
    nixpkgs-old.url = "github:nixos/nixpkgs/1c37a89390481e809b9851781026bc9bb840dd90";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # zed.url = "github:zed-industries/zed";
    # zed.url = "github:AidanV/zed";

    nix-gaming.url = "github:fufexan/nix-gaming";
    # emacs-overlay.url = "github:nix-community/emacs-overlay";
    # prismlauncher.url = "github:PrismLauncher/PrismLauncher";
    # paisa.url = "github:ananthakumaran/paisa";
    zig.url = "github:mitchellh/zig-overlay";


    hyprland.url = "github:hyprwm/Hyprland/29e2e59";

    hy3 = {
      url = "github:outfoxxed/hy3";
      inputs.hyprland.follows = "hyprland";
    };

    ironbar = {
      url = "github:JakeStanger/ironbar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , home-manager
    , nixpkgs
    , nixpkgs-old
    , nixpkgs-unstable
    , ...
    }:
    let
      system = "x86_64-linux";
      user = "sleroq";
      dotfiles = ../.;
      realDotfiles = "/home/" + user + "/develop/other/dotfiles";
      myOverlay = final: prev: {
        zed-editor = prev.zed-editor.overrideAttrs (old: rec {
          version = "0.184.1-pre";
          src = prev.fetchFromGitHub {
            owner = "zed-industries";
            repo = "zed";
            tag = "v${version}";
            hash = "sha256-WqvjENci7JZ7jz3Lpz998X1XOTqdBrLcEMA5ExzjDWc=";
          };
          cargoDeps = final.rustPlatform.fetchCargoVendor {
            inherit src;
            hash = "sha256-egF9M9HJ9bqyNwMC0733CPr3Q149u1bsWp8ASW7TmLc=";
          };
        });
      };
    in
    {
      homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
        };

        modules = [
          self.inputs.ironbar.homeManagerModules.default
          ./home.nix
          ./modules/editors/default.nix
          ./modules/gaming/default.nix
          ./modules/programs/default.nix
          ./modules/wms/default.nix
          ./modules/development.nix
          ./modules/shell.nix
        ];

        extraSpecialArgs = {
          inputs = self.inputs;
          opts = {
            old-configs = dotfiles + /home/.config;
            configs = dotfiles + /home/config;
            dotfiles = dotfiles;
            realDotfiles = realDotfiles;
            realConfigs = realDotfiles + "/home/config";
          };
          pkgs-old = import nixpkgs-old {
            inherit system;
            config.allowUnfree = true;
            # For obinskit
            config.permittedInsecurePackages = [
              "electron-13.6.9"
            ];
          };
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
            overlays = [ myOverlay ];
          };
        };
      };
    };
}
