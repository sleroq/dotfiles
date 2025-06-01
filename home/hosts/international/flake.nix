{
  description = "Home Manager configuration of Sleroq";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # For old packages, like obinskit
    nixpkgs-old.url = "github:nixos/nixpkgs/1c37a89390481e809b9851781026bc9bb840dd90";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    # paisa.url = "github:ananthakumaran/paisa";
    zig.url = "github:mitchellh/zig-overlay";

    hyprland.url = "github:hyprwm/Hyprland/29e2e59";

    hy3 = {
      url = "github:outfoxxed/hy3";
      inputs.hyprland.follows = "hyprland";
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
      host = "interplanetary";
      repoPath = ../../..;
      repoPathString = "/home/${user}/develop/other/dotfiles";
      myOverlay = final: prev: {
        zed-editor = prev.zed-editor.overrideAttrs (old: rec {
          version = "0.184.4-pre";
          src = prev.fetchFromGitHub {
            owner = "zed-industries";
            repo = "zed";
            tag = "v${version}";
            hash = "sha256-8YEuR8CfZsMq2pBBWVPEmZgIyO2724THP4yQhf7TkPA=";
          };
          cargoDeps = final.rustPlatform.fetchCargoVendor {
            inherit src;
            hash = "sha256-KU/pmdQm9OUPod7oWwtUlutk5V+odzg/ojJ/feL6icE=";
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
          ./home.nix
          ../../modules/wms/wayland
          ../../modules/programs
          ../../modules/editors
          ../../modules/gaming.nix
          ../../shared
        ];

        extraSpecialArgs = {
          inputs = self.inputs;
          opts = {
            inherit host repoPath repoPathString;
            old-configs = repoPath + /home/.config;
            configs = repoPath + /home/config;
            realConfigs = repoPathString + "/home/config";
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
