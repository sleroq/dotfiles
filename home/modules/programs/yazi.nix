{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkMerge [
    {
      programs.yazi.enable = true;
      programs.yazi.shellWrapperName = "y";
    }
    (lib.mkIf config.programs.yazi.enable {
      home.packages = with pkgs; [
        _7zz
        poppler-utils
        resvg
        ffmpeg
        imagemagick
        chafa
        exiftool
        glow
      ];

      programs.yazi = {
        plugins.piper = pkgs.yaziPlugins.piper;
        settings.plugin.prepend_previewers = [
          {
            url = "*.md";
            run = ''piper -- CLICOLOR_FORCE=1 glow -w "$w" -s "$t" "$1"'';
          }
          {
            url = "*.markdown";
            run = ''piper -- CLICOLOR_FORCE=1 glow -w "$w" -s "$t" "$1"'';
          }
        ];
        keymap.mgr.prepend_keymap = [
          {
            on = "M";
            run = "shell --block -- exiftool %h | less";
            desc = "Show file metadata";
          }
        ];
      };
    })
  ];
}
