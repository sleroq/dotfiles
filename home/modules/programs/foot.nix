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
    };
  };

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];
}
