{ pkgs, ... } :
{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
  };

  home.packages = with pkgs; [
    # Theming
    lxappearance
    libsForQt5.qt5ct
    kdePackages.qt6ct
    libsForQt5.qtstyleplugins
    kdePackages.qtstyleplugin-kvantum
    catppuccin-kvantum
    # kora-icon-theme

    kdePackages.breeze-gtk
    lxqt.lxqt-config
    zuki-themes

    kdePackages.breeze
    catppuccin-qt5ct
    lxqt.lxqt-themes
    libsForQt5.kiconthemes
    libsForQt5.grantleetheme
    libsForQt5.qtstyleplugins
    libsForQt5.lightly
  ];
}
