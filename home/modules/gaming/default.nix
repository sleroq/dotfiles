{ pkgs, ... }:

{
  imports = [ ./osu.nix ];

  config = {
    home.packages = with pkgs; [
      lutris
      gamemode

      # Steam - Installed in /etx/nixos/configuration.nix,
      #         because I don't want to fuck with Steam.
      #         But it's probabbly possible to install everything with home-manager
      # steam
      # steam-original
      # steam-runtime
    ];
  };
}
