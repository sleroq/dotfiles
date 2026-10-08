{
  pkgs,
  opts,
  lib,
  self,
  ...
}:

let
  sway-session-cleanup = pkgs.writeShellScriptBin "sway-session-cleanup" ''
    # Sway may close IPC before delivering shutdown, so EOF must also clean up.
    swaymsg -t subscribe '["shutdown"]'
    systemctl --user stop graphical-session.target graphical-session-pre.target
  '';
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
      sway-session-cleanup

      swayidle
      swaykbdd
      swayr
      pango
    ];
  })
]
