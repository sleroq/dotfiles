{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.ghostty.packages.${pkgs.system}.default
  ];

  xdg.configFile."ghostty/config".text = ''
    window-decoration = false
    keybind = alt+w=toggle_window_decorations
  '';
}
