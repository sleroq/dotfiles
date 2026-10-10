{
  noctalia,
  runCommand,
  imagemagick,
  tela-icon-theme,
}:
noctalia.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./noctalia-dwl/tray-menu-scale.patch ];
  passthru = (old.passthru or { }) // {
    trayIcons = runCommand "noctalia-dwl-tray-icons" { nativeBuildInputs = [ imagemagick ]; } ''
      mkdir -p "$out/24/panel"
      cp ${tela-icon-theme}/share/icons/Tela/index.theme "$out/index.theme"
      for name in blueman-tray blueman-tray-active blueman-tray-disabled gammastep-status-on gammastep-status-off; do
        asset="${tela-icon-theme}/share/icons/Tela/24/panel/$name.svg"
        bounds=$(magick -background none "$asset" -trim -format '%[fx:page.x] %[fx:page.y] %w %h' info:)
        sed "s/<svg /<svg viewBox=\"$bounds\" /" "$asset" > "$out/24/panel/$name.svg"
      done
    '';
  };
})
