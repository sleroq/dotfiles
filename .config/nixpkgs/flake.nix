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
    in
    {
      homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.

        modules = [
          ./home.nix
          ./modules/editors/emacs.nix
          ./modules/editors/neovim.nix
          ./modules/shell.nix
          ./modules/gaming.nix
          ./modules/development.nix
        ];
        
        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
        
        extraSpecialArgs = {
          emacs-overlay = self.inputs.emacs-overlay;
          opts = { zsh-integration = true; };
        };
      };
    };
}
