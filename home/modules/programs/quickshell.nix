{ pkgs, ... }:
{
  programs.quickshell = {
    enable = true;
    activeConfig = "shell.qml";
    configs = {
      "shell.qml" = ./quickshell/config.qml;
    };
  };

  home.packages = [
    pkgs.kdePackages.qtdeclarative
  ];
}
