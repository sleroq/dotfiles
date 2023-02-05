
{ pkgs, ... }:

{
  config = {
    programs.kitty = {
        enable = true;
        font = {
          name = "JetBrainsMono";
          size = 14;
        };
        theme = "Chalk";
    };

    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    ];
  };
}
