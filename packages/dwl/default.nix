{
  dwl,
  src,
  cairo,
  pango,
  libdrm,
}:

(dwl.override {
  configH = ./config.h;
  enableXWayland = true;
}).overrideAttrs
  (old: {
    inherit src;
    buildInputs = (old.buildInputs or [ ]) ++ [
      cairo
      pango
      libdrm
    ];
    patches = (old.patches or [ ]) ++ [
      ./patches/ipc.patch
      ./patches/desktop.patch
      ./patches/better-resize.patch
    ];
    postInstall = (old.postInstall or "") + ''
      substituteInPlace "$out/share/wayland-sessions/dwl.desktop" --replace-fail 'Exec=dwl' 'Exec=dwl -s "uwsm finalize"'
      echo 'DesktopNames=dwl' >> "$out/share/wayland-sessions/dwl.desktop"
    '';
  })
