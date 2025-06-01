{ pkgs, ... }:

let
  teamsApp = pkgs.writeShellScriptBin "teams-app" ''
    exec ${pkgs.chromium}/bin/chromium \
      --enable-features=VaapiVideoDecoder \
      --use-angle=vulkan \
      --ozone-platform=wayland \
      --enable-unsafe-webgpu \
      --app=https://teams.live.com/v2/ \
      --class="Microsoft Teams" \
      --user-data-dir="$HOME/.config/teams-app" \
      --test-type \
      "$@"
  '';

  teamsDesktopItem = pkgs.makeDesktopItem {
    name = "teams-app";
    desktopName = "Microsoft Teams";
    exec = "${teamsApp}/bin/teams-app";
    icon = "teams"; # You'll need to provide an icon
    categories = [ "Network" "InstantMessaging" ];
    comment = "Microsoft Teams Web App";
  };

  teamsAppPackage = pkgs.symlinkJoin {
    name = "teams-app";
    paths = [ teamsApp teamsDesktopItem ];
  };
in {
  programs.chromium.enable = true;
  
  home.packages = [ teamsAppPackage ];
}
