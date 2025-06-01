{ pkgs, ... }:

{
  programs.mpv = {
    enable = true;
    package = pkgs.mpv;
    config = {
      volume = 50;
      osd-font-size = 24;
      sub-font-size = 24;
      screenshot-directory = "~/Pictures/Screenshots/mpv";
    };
  };
}
