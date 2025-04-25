{ pkgs-unstable, ... }:

{
  programs.mpv = {
    enable = true;
    package = pkgs-unstable.mpv;
    config = {
      volume = 50;
      osd-font-size = 24;
      sub-font-size = 24;
    };
  };
}
