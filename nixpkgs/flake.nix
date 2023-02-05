{
  description = "Home Manager configuration of Sleroq";


  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay.url  = "github:nix-community/emacs-overlay";
    nix-gaming.url = "github:fufexan/nix-gaming";
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
      };
      dotfiles = ../.;
    in
    {
      homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./home.nix
          ./modules/editors/default.nix
          ./modules/gaming/default.nix
          ./modules/programs/default.nix
          ./modules/development.nix
          ./modules/shell.nix
          ./modules/wm.nix
        ];
        
        extraSpecialArgs = {
          inputs = self.inputs;
          opts = {
            zsh-integration = true;
            old-configs = dotfiles + /.config;
            configs = dotfiles + /nixpkgs/config;
            dotfiles = dotfiles;
            realConfigs = "/home/" + user + "/develop/other/dotfiles/nixpkgs/config";
          };
        };
      };
    };
}
