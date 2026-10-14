{ pkgs, ... }:

{
  programs.lf = {
    enable = true;
    extraConfig =
      pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        set previewer ctpv
        set cleaner ctpvclear
        &ctpv -s $id
        &ctpvquit $id
      ''
      + ''
        map . set hidden!
        map D push :delete
      '';
  };

  programs.gpg.enable = true;

  home.packages = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux (
    with pkgs;
    [
      ctpv

      exiftool
      atool
      ffmpegthumbnailer
      colordiff
      elinks
      jq
      mdcat
      poppler-utils
      imagemagick
      highlight
      libtransmission_4
    ]
  );
}
