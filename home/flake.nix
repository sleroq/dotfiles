{
  description = "Home Manager configuration of Sleroq";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    nix-gaming.url = "github:fufexan/nix-gaming";
    prismlauncher.url = "github:PrismLauncher/PrismLauncher";
    paisa.url = "github:ananthakumaran/paisa";
    eww = {
      url = "github:elkowar/eww/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      url = "github:outfoxxed/hy3?ref=hl0.41.1";
      inputs.hyprland = {
        type = "git";
        url = "https://github.com/hyprwm/Hyprland";
        submodules = true;
        ref = "refs/tags/v0.41.1";
      };
    };
  };

  outputs =
    { self
    , nixpkgs
    , home-manager
    , ...
    }:
    let
      system = "x86_64-linux";
      user = "sleroq";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import ./overlays.nix self.inputs) ];
      };
      dotfiles = ../.;
      realDotfiles = "/home/" + user + "/develop/other/dotfiles";
    in
    {
      homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

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
        };
      };
    };
}
