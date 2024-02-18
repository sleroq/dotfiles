{ pkgs, ... }:

{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        term = "xterm-256color";

        font = "JetBrainsMono Nerd Font Mono:size=9";
        dpi-aware = "yes";
      };

      mouse = {
        hide-when-typing = "yes";
      };

      cursor = {
        color = "1c1c1c eeeeee";
      };

      # Catpussy machiatto
      colors = {
        foreground = "cad3f5"; # Text
        background = "24273a"; # Base
        regular0 = "494d64";   # Surface 1
        regular1 = "ed8796";   # red
        regular2 = "a6da95";   # green
        regular3 = "eed49f";   # yellow
        regular4 = "8aadf4";   # blue
        regular5 = "f5bde6";   # pink
        regular6 = "8bd5ca";   # teal
        regular7 = "b8c0e0";   # Subtext 1
        bright0 = "5b6078";    # Surface 2
        bright1 = "ed8796";    # red
        bright2 = "a6da95";    # green
        bright3 = "eed49f";    # yellow
        bright4 = "8aadf4";    # blue
        bright5 = "f5bde6";    # pink
        bright6 = "8bd5ca";    # teal
        bright7 = "a5adcb";    # Subtext 0
      };

     # Catpussy mocha
     # colors = {
     #   foreground = "cdd6f4"; # Text
     #   background = "1e1e2e"; # Base
     #   regular0 = "45475a";   # Surface 1
     #   regular1 = "f38ba8";   # red
     #   regular2 = "a6e3a1";   # green
     #   regular3 = "f9e2af";   # yellow
     #   regular4 = "89b4fa";   # blue
     #   regular5 = "f5c2e7";   # pink
     #   regular6 = "94e2d5";   # teal
     #   regular7 = "bac2de";   # Subtext 1
     #   bright0 = "585b70";    # Surface 2
     #   bright1 = "f38ba8";    # red
     #   bright2 = "a6e3a1";    # green
     #   bright3 = "f9e2af";    # yellow
     #   bright4 = "89b4fa";    # blue
     #   bright5 = "f5c2e7";    # pink
     #   bright6 = "94e2d5";    # teal
     #   bright7 = "a6adc8";    # Subtext 0
     # };
    };
  };

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];
}
