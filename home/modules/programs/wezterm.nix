{ extraConfig ? "", ... }:

{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      -- Pull in the wezterm API
      local wezterm = require 'wezterm'

      -- This will hold the configuration.
      local config = wezterm.config_builder()
      
      config.color_scheme = 'Catppuccin Mocha'
      config.window_background_opacity = 0.6

      config.font = wezterm.font 'JetBrainsMono Nerd Font'
      config.font_size = 14.0

      ${extraConfig}

      return config
    '';
  };
}
