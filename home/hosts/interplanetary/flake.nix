{
  description = "Home Manager configuration of Sleroq";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    scrcpyPkgs.url = "github:nixos/nixpkgs/77a0bdd";
    nixpkgs-old.url = "github:nixos/nixpkgs/1c37a89390481e809b9851781026bc9bb840dd90";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
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
    zls.url = "github:zigtools/zls";
    zed.url = "github:zed-industries/zed?submodules=1&ref=refs/tags/v0.193.1-pre";
    agenix.url = "github:ryantm/agenix";

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/v0.49.0";

    hy3 = {
      url = "github:outfoxxed/hy3?ref=hl0.49.0";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs =
    { self
    , home-manager
    , nixpkgs
    , nixpkgs-old
    , nixpkgs-master
    , secrets
    , scrcpyPkgs
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
          pkgs-master = import nixpkgs-master {
            inherit system;
            config.allowUnfree = true;
          };
          scrcpyPkgs = import scrcpyPkgs {
            inherit system;
          };
        };
      };
    };
}
