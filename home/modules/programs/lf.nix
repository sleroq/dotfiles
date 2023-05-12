{ pkgs, ... }:

{
  programs.lf = {
    enable = true;
    extraConfig = ''
      set previewer ctpv
      set cleaner ctpvclear
      &ctpv -s $id
      &ctpvquit $id

      map . set hidden!
      map D push :delete
    '';
  };

  programs.gpg.enable = true;

  home.packages = with pkgs; [
    ctpv

    exiftool
    atool
    ffmpegthumbnailer
    colordiff
    elinks
    jq
    mdcat
    poppler_utils
    imagemagick
    highlight
    libtransmission
  ];
}
