{ pkgs, ... }:

{
  config = {
    programs.lf = {
      enable = true;
      extraConfig = ''
        set previewer ctpv
        set cleaner ctpvclear
        &ctpv -s $id
        &ctpvquit $id

        map . set hidden!
      '';
    };

    programs.gpg.enable = true;

    home.packages = with pkgs; [
      # Waiting for https://github.com/NixOS/nixpkgs/pull/208559
      # ctpv

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
  };
}
