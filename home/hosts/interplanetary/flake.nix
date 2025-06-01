{
  description = "Home Manager configuration of Sleroq";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:nixos/nixpkgs/1c37a89390481e809b9851781026bc9bb840dd90";
    secrets = {
      flake = false;
      url = "path:../../secrets";
    };

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    # paisa.url = "github:ananthakumaran/paisa";
    zig.url = "github:mitchellh/zig-overlay";
    zed.url = "github:zed-industries/zed";

    hyprland.url = "github:hyprwm/Hyprland/29e2e59";
  };

  outputs =
    { self
    , home-manager
    , nixpkgs
    , nixpkgs-old
    , secrets
    , ...
    }:
    let
      system = "x86_64-linux";
      user = "sleroq";
      host = "interplanetary";
      repoPath = ../../..;
      repoPathString = "/home/${user}/develop/other/dotfiles";
      myOverlay = final: prev: {};
    in
    {
      homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ myOverlay ];
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
        };
      };
    };
}
