{ ... }:

{
  programs.mpv = {
    enable = true;
    config = {
      volume = 50;
      osd-font-size = 24;
      sub-font-size = 24;
    };
  };
}
