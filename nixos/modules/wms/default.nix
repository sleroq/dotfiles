{ pkgs,... }: 
let
  wayland-environment = ''
    export _JAVA_AWT_WM_NONREPARENTING=1;
    export XDG_SESSION_TYPE=wayland;
    export QT_QPA_PLATFORM=wayland;
    export QT_QPA_PLATFORMTHEME=qt6ct;
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1;
    export CLUTTER_BACKEND=wayland;
    export SDL_VIDEODRIVER=wayland;
    export MOZ_ENABLE_WAYLAND=1;
  '';

  # https://man.sr.ht/%7Ekennylevinsen/greetd/#how-to-set-xdg_session_typewayland
  sway-wrapper = pkgs.writeTextFile {
    name = "sway-wrapper";
    destination = "/bin/sway-wrapper";
    executable = true;
    text = wayland-environment + ''
      export XDG_CURRENT_DESKTOP=sway
      exec sway $@
    '';
  };

  hyprland-wrapper = pkgs.writeTextFile {
    name = "sway-wrapper";
    destination = "/bin/sway-wrapper";
    executable = true;
    text = wayland-environment + ''
      export XDG_CURRENT_DESKTOP=hyprland
      exec hyprland $@
    '';
  };
in
{
  imports = [
    ./lemurs.nix
    ./wayland/default.nix
    ./x11/leftwm.nix
    ./x11/default.nix
  ];

  environment.systemPackages = with pkgs; [
    sway-wrapper
    hyprland-wrapper
  ];
}
