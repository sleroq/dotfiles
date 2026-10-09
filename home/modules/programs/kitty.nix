_:

{
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Macchiato";
    keybindings = {
      "kitty_mod+t" = "launch --type=tab --cwd=current --location=after";
      "cmd+t" = "launch --type=tab --cwd=current --location=after";
    };
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = "14";
      background_opacity = "0.8";
      background = "#000000";
    };
  };
}
