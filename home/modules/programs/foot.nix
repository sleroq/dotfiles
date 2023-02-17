{ pkgs, ... }:

{
  config = {
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

        colors = {
          background = "22272e";
          foreground = "768390";
          regular0 = "545d68";
          regular1 = "f47067";
          regular2 = "57ab5a";
          regular3 = "c69026";
          regular4 = "539bf5";
          regular5 = "b083f0";
          regular6 = "39c5cf";
          regular7 = "909dab";
          bright0 = "636e7b";
          bright1 = "ff938a";
          bright2 = "6bc46d";
          bright3 = "daaa3f";
          bright4 = "6cb6ff";
          bright5 = "dcbdfb";
          bright6 = "56d4dd";
          bright7 = "cdd9e5";
        };

        # colors = {
        #   background = "1c1c1c";
        #   foreground = "eeeeee";
        #   regular0 = "1c1c1c";
        #   regular1 = "af005f";
        #   regular2 = "5faf00";
        #   regular3 = "d7af5f";
        #   regular4 = "5fafd7";
        #   regular5 = "808080";
        #   regular6 = "d7875f";
        #   regular7 = "d0d0d0";
        #   bright0 = "bcbcbc";
        #   bright1 = "5faf5f";
        #   bright2 = "afd700";
        #   bright3 = "af87d7";
        #   bright4 = "ffaf00";
        #   bright5 = "ff5faf";
        #   bright6 = "00afaf";
        #   bright7 = "5f8787";

        #   # selection-foreground = "1c1c1c";
        #   # selection-background = "af87d7";
        # };
      };
    };

    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    ];
  };
}
