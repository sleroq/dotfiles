{ pkgs, config, ... }:

let
  shareScreenshot = pkgs.writeShellScriptBin "share-screenshot" ''
    #!/bin/bash
    export XDG_CURRENT_DESKTOP=sway
    flameshot gui -r > /tmp/screenshot.png
    
    # Check if screenshot was taken (file exists and is not empty)
    if [ ! -s /tmp/screenshot.png ]; then
      echo "Screenshot cancelled or failed"
      exit 1
    fi
    
    # Show uploading notification
    notify-send "Screenshot" "Uploading screenshot..." --icon=camera-photo
    
    # Read auth token from agenix secret
    AUTH_TOKEN=$(cat ${config.age.secrets.flameshot-auth-token.path})
    
    # Upload to sharing service
    response=$(curl -H "authorization: $AUTH_TOKEN" \
      -H "x-zipline-folder: cmd49r9980003sp9r18zs5zaq" \
      https://share.cum.army/api/upload \
      -F file=@/tmp/screenshot.png \
      -H 'content-type: multipart/form-data' \
      --silent)
    
    if [ $? -eq 0 ]; then
      # Extract URL and copy to clipboard
      url=$(echo "$response" | jq -r '.files[0].url')
      if [ "$url" != "null" ] && [ -n "$url" ]; then
        echo "$url" | tr -d '\n' | wl-copy
        echo "Screenshot uploaded and URL copied to clipboard: $url"
        notify-send "Screenshot" "Screenshot uploaded! URL copied to clipboard." --icon=clipboard
      else
        echo "Failed to extract URL from response: $response"
        notify-send "Screenshot" "Failed to extract URL from response" --icon=dialog-error
        exit 1
      fi
    else
      echo "Failed to upload screenshot"
      notify-send "Screenshot" "Failed to upload screenshot" --icon=dialog-error
      exit 1
    fi
    
    # Clean up
    rm -f /tmp/screenshot.png
  '';
in
{
  age.secrets.flameshot-auth-token = {
    file = ../../secrets/flameshot-auth-token;
  };

  home.packages = with pkgs; [
    (flameshot.override {
      # Enable USE_WAYLAND_GRIM compile flag
      enableWlrSupport = true;
    })
    shareScreenshot
    curl
    jq
    wl-clipboard
    libnotify  # For notify-send notifications
  ];

  xdg.configFile."flameshot/flameshot.ini" = {
    text = ''
      [General]
      contrastOpacity=188
      disabledTrayIcon=true
      saveLastRegion=true
      savePath=/home/sleroq/Pictures/Screenshots
      showStartupLaunchMessage=false
      disabledGrimWarning=true
    '';
  };
}
