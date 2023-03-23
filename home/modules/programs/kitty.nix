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
        settings = {
          confirm_os_window_close = 0;
          enable_audio_bell = false;
        };
    };

    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    ];
  };
}
