{ pkgs, lib, ... } :
let
  catppuccinAccent = "Blue";
  catppuccinFlavor = "Macchiato";

  catppuccinKvantum = pkgs.catppuccin-kvantum.override {
    accent = "${lib.toLower catppuccinAccent}";
    variant = "${lib.toLower catppuccinFlavor}";
  };

  qtThemeName = "catppuccin-${lib.toLower catppuccinFlavor}-${lib.toLower catppuccinAccent}";
in {
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  xdg.configFile = {
    "Kvantum/${qtThemeName}".source = "${catppuccinKvantum}/share/Kvantum/${qtThemeName}";
    "Kvantum/kvantum.kvconfig".source = (pkgs.formats.ini {}).generate "kvantum.kvconfig" {
      General.theme = qtThemeName;
      General.icon_theme = "Tela";
    };
  };

  gtk = {
    enable = true;
    theme.name = "Orchis-Dark";
    theme.package = pkgs.orchis-theme;
    iconTheme.name = "Tela";
    iconTheme.package = pkgs.tela-icon-theme;
    # cursorTheme.name = "Vimix-cursors";
    # cursorTheme.package = pkgs.vimix-cursors;
    # gtk3.extraConfig = {
    #   gtk-application-prefer-dark-theme = true;
    # };
    # gtk4.extraConfig = {
    #   gtk-application-prefer-dark-theme = true;
    # };
  };

  home = {
    file = {
      ".icons/Tela".source = "${pkgs.tela-icon-theme}/share/icons/Tela";
    };

    pointerCursor = 
      let 
        getFrom = url: hash: name: {
            gtk.enable = true;
            x11.enable = true;
            hyprcursor.enable = true;
            inherit name;
            size = 24;
            package = 
              pkgs.runCommand "moveUp" {} ''
                mkdir -p $out/share/icons
                ln -s ${pkgs.fetchzip {
                  inherit url hash;
                }} $out/share/icons/${name}
            '';
          };
      in
        getFrom 
          "https://github.com/ful1e5/fuchsia-cursor/releases/download/v2.0.0/Fuchsia-Pop.tar.gz"
          "sha256-BvVE9qupMjw7JRqFUj1J0a4ys6kc9fOLBPx2bGaapTk="
          "Fuchsia-Pop";

    packages = [ pkgs.libsForQt5.qt5ct pkgs.qt6ct ];
  };
}
