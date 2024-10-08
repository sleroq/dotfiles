{ ... }:

{
  programs.zellij = {
    enable = true;
    settings = {
      theme = "catppuccin-macchiato";
      themes."catppuccin-macchiato" = {
        bg = "#5b6078";
        fg = "#cad3f5";
        red = "#ed8796";
        green = "#a6da95";
        blue = "#8aadf4";
        yellow = "#eed49f";
        magenta = "#f5bde6";
        orange = "#f5a97f";
        cyan = "#91d7e3";
        black = "#1e2030";
        white = "#cad3f5";
      };
    };
  };
}
