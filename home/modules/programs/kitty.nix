_:

{
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Macchiato";
    keybindings = {
      "kitty_mod+t" = "new_tab_with_cwd";
      "cmd+t" = "new_tab_with_cwd";
    };
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = "14";
      background_opacity = "0.8";
      background = "#000000";
    };
  };
}
