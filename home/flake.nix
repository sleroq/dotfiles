{
  description = "Home Manager configuration of Sleroq";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nix-gaming.url = "github:fufexan/nix-gaming";
    prismlauncher.url = "github:PrismLauncher/PrismLauncher";
    paisa.url = "github:ananthakumaran/paisa";
    zig.url = "github:mitchellh/zig-overlay";

    # For old packages, like obinskit
    nixpkgs-old.url = "github:nixos/nixpkgs/1c37a89390481e809b9851781026bc9bb840dd90";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    hyprland.url = "github:hyprwm/Hyprland/0bd541f2fd902dbfa04c3ea2ccf679395e316887";

    hy3 = {
      url = "github:outfoxxed/hy3?ref=hl0.46.0";
      inputs.hyprland.follows = "hyprland";
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
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
    in
    {
      homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; };

        modules = [
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
          };
        };
      };
    };
}
