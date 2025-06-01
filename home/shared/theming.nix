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
    cursorTheme.name = "Vimix-cursors";
    cursorTheme.package = pkgs.vimix-cursors;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  home.file = {
    ".icons/vimix-cursors".source = "${pkgs.vimix-cursors}/share/icons/Vimix-cursors";
    ".icons/Tela".source = "${pkgs.tela-icon-theme}/share/icons/Tela";
  };

  home.packages = [ pkgs.libsForQt5.qt5ct pkgs.qt6ct ];
}
