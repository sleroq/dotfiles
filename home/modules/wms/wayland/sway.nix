{ pkgs, opts, lib, self, ... }:

let
  # bash script to let dbus know about important env variables and
  # propagate them to relevent services run at the end of sway config
  # see
  # https://github.com/emersion/xdg-desktop-portal-wlr/wiki/"It-doesn't-work"-Troubleshooting-Checklist
  # note: this is pretty much the same as  /etc/sway/config.d/nixos.conf but also restarts  
  # some user services to make sure they have the correct environment variables
  dbus-sway-environment = pkgs.writeTextFile {
    name = "dbus-sway-environment";
    destination = "/bin/dbus-sway-environment";
    executable = true;

    text = ''
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
      systemctl --user stop pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr
      systemctl --user start pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr
    '';
  };
in
lib.mkMerge [
  (import ../../programs/eww.nix { inherit pkgs lib self; })
  (import ../../programs/swaycons.nix { inherit pkgs opts lib; })
  (import ../../programs/mic-mute.nix { inherit pkgs; })
  (with lib; {
    home.activation.sway = hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.config/sway

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/sway/* $HOME/.config/sway/
    '';

    programs.swaylock.enable = true;

    services = {
      swayidle.enable = true;
      swayosd.enable = true;
    };

    home.packages = with pkgs; [
      dbus-sway-environment

      swayidle
      swaykbdd
      swayr
      pango
    ];
  })
]
