{ pkgs, ... }:

{
  programs.mpv = {
    enable = true;
    package = pkgs.mpv;
    bindings = {
      "n" = "cycle_values af \"lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]\"";
    };
    config = {
      volume = 50;
      osd-font-size = 24;
      sub-font-size = 24;
      # TODO: make this configurable or auto-create directory
      screenshot-directory = "~/Pictures/Screenshots/mpv";
      alang = "eng";
      slang = "eng";
      vo = "gpu";
    };
  };
}
