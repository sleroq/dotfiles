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
  greetd-sway-wrapper = pkgs.writeTextFile {
    name = "greetd-sway-wrapper";
    destination = "/bin/greetd-sway-wrapper";
    executable = true;
    text = wayland-environment + ''
      exec sway $@
    '';
  };
  greetd-hyprland-wrapper = pkgs.writeTextFile {
    name = "greetd-sway-wrapper";
    destination = "/bin/greetd-sway-wrapper";
    executable = true;
    text = wayland-environment + ''
      exec hyprland $@
    '';
  };
in {

  imports = [
    ./wayland/default.nix
    ./x11/leftwm.nix
  ];

  services.greetd = {
    enable = true;
    settings = {
     default_session.command = ''
      ${pkgs.greetd.tuigreet}/bin/tuigreet \
        --time \
        --asterisks \
        --user-menu \
        --cmd ${greetd-sway-wrapper}/bin/greetd-sway-wrapper
    '';
     hyprland.command = ''
      ${pkgs.greetd.tuigreet}/bin/tuigreet \
        --time \
        --asterisks \
        --user-menu \
        --cmd ${greetd-hyprland-wrapper}/bin/greetd-hyprland-wrapper
    '';
    };
  };

  environment.etc."greetd/environments".text = ''
    sway
    hyprland
    leftwm
  '';

  environment.systemPackages = with pkgs; [
    greetd-sway-wrapper
  ];
}
