# MacOS only config basically
_:
# { pkgs, ... }:

{
  programs.ghostty = {
    package = null;
    enable = true;
    settings = {
      # command = "${pkgs.nushell}/bin/nu";
      font-family = "JetBrainsMono Nerd Font";
      # theme = "Catppuccin Frappe";
      theme = "dark:Rose Pine,light:Rose Pine Dawn";
      font-size = 18;
      cursor-style = "block";

      keybind = [
        "alt+w=toggle_window_decorations"
        "ctrl+s>c=new_tab"
        "ctrl+s>x=close_surface"
        "ctrl+s>h=move_tab:-1"
        "ctrl+s>l=move_tab:1"
        "ctrl+s>1=goto_tab:1"
        "ctrl+s>2=goto_tab:2"
        "ctrl+s>3=goto_tab:3"
        "ctrl+s>4=goto_tab:4"
        "ctrl+s>5=goto_tab:5"
        "ctrl+s>6=goto_tab:6"
        "ctrl+s>7=goto_tab:7"
        "ctrl+s>8=goto_tab:8"
        "ctrl+s>9=goto_tab:9"
        "ctrl+s>0=goto_tab:10"
      ];
    };
  };
}
