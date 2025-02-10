{ pkgs, ... }: {
  home.packages = [
    pkgs.ghostty
  ];

  xdg.configFile."ghostty/config".text = ''
    theme = catppuccin-mocha
    cursor-style = block
    window-decoration = false
    background-opacity = 0.9
    gtk-tabs-location = hidden

    keybind = alt+w=toggle_window_decorations

    keybind = ctrl+s>c=new_tab
    keybind = ctrl+s>x=close_surface

    keybind = ctrl+s>h=move_tab:-1
    keybind = ctrl+s>l=move_tab:1

    keybind = ctrl+s>1=goto_tab:1
    keybind = ctrl+s>2=goto_tab:2
    keybind = ctrl+s>3=goto_tab:3
    keybind = ctrl+s>4=goto_tab:4
    keybind = ctrl+s>5=goto_tab:5
    keybind = ctrl+s>6=goto_tab:6
    keybind = ctrl+s>7=goto_tab:7
    keybind = ctrl+s>8=goto_tab:8
    keybind = ctrl+s>9=goto_tab:9
    keybind = ctrl+s>0=goto_tab:10
  '';
}
