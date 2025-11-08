_:

{
  # https://nikitabobko.github.io/AeroSpace/guide#default-config
  services.aerospace = {
    # enable = true;
    settings = {
      after-startup-command = [];
      start-at-login = false;
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;
      # accordion-padding = 0;# 30;
      accordion-padding = 30;
      default-root-container-layout = "accordion"; #"tiles";
      default-root-container-orientation = "auto";
      on-focused-monitor-changed = ["move-mouse monitor-lazy-center"];
      automatically-unhide-macos-hidden-apps = false;
      key-mapping.preset = "qwerty";
      gaps = {
        inner = {
          horizontal = 0;
          vertical = 0;
        };
        outer = {
          left = 0;
          bottom = 0;
          top = 0;
          right = 0;
        };
      };
      mode.main.binding = {
        alt-slash = "layout tiles horizontal vertical";
        alt-comma = "layout accordion horizontal vertical";
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";
        alt-minus = "resize smart -50";
        alt-equal = "resize smart +50";

        alt-q = "workspace Q";
        alt-w = "workspace W";
        alt-e = "workspace E";
        alt-r = "workspace R";

        alt-a = "workspace A";
        alt-s = "workspace S";
        alt-d = "workspace D";
        alt-f = "workspace F";

        alt-shift-q = "move-node-to-workspace Q";
        alt-shift-w = "move-node-to-workspace W";
        alt-shift-e = "move-node-to-workspace E";
        alt-shift-r = "move-node-to-workspace R";

        alt-shift-a = "move-node-to-workspace A";
        alt-shift-s = "move-node-to-workspace S";
        alt-shift-d = "move-node-to-workspace D";
        alt-shift-f = "move-node-to-workspace F";

        alt-shift-semicolon = "mode service";
      };
      mode.service.binding = {
        esc = ["reload-config" "mode main"];
        r = ["flatten-workspace-tree" "mode main"];
        f = ["layout floating tiling" "mode main"];
        backspace = ["close-all-windows-but-current" "mode main"];
        alt-shift-h = ["join-with left" "mode main"];
        alt-shift-j = ["join-with down" "mode main"];
        alt-shift-k = ["join-with up" "mode main"];
        alt-shift-l = ["join-with right" "mode main"];
        down = "volume down";
        up = "volume up";
        shift-down = ["volume set 0" "mode main"];
      };
    };
  };
}
