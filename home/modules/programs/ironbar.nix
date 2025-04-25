{ pkgs, lib, ... }:

let
  to-css =
    attrs:
    lib.strings.concatLines (
      lib.attrsets.mapAttrsToList (
        name: value:
        if (builtins.typeOf value == "set") then
          ''
            ${name} {
              ${to-css value}
            }
          ''
        else if (builtins.typeOf value == "list") then
          builtins.concatStringsSep "\n" (builtins.map (v: "${name} ${v}") value)
        else
          "${name}: ${builtins.toString value};"
      ) attrs
    );

  theme = {
    # Dark Blue
    base00 = "002451";
    # Extremely Dark Blue
    base01 = "001733";
    # Blue
    base02 = "003f8e";
    # Light Blue
    base03 = "7285b7";
    # Grey
    base04 = "949494";
    # White
    base05 = "ffffff";
    # Light Grey
    base06 = "e0e0e0";
    # White
    base07 = "ffffff";
    # Maroon Red
    base08 = "a92049";
    # Salmon
    base09 = "ff9da4";
    # Pastel Yellow
    base0A = "ffeead";
    # Light Lime
    base0B = "d1f1a9";
    # White
    base0C = "ffffff";
    # Peach
    base0D = "ffc58f";
    # Violet
    base0E = "d778ff";
    # Baby Poo Brown
    base0F = "cd9731";
    scheme = "Tomorrow Night Blue";
    slug = "tomorrow-night-blue";
    author = "tomorrow-night-blue";
  };
in {
  programs.ironbar = {
    enable = true;
    # systemd = true;
    config = {
      position = "top";
      height = 32;
      start = [
        {
          type = "label";
          label = "󱄅";
          name = "nix";
        }
        {
          type = "workspaces";
          all_monitors = false;
        }
        {
          type = "launcher";
          show_names = false;
          show_icons = true;
        }
      ];
      center = [
        {
          type = "clock";
          format = "%R - %a %d.";
        }
      ];
      end = [
        {
          type = "sys_info";
          format = [
            "   {cpu_percent}% | {temp_c:coretemp-Package-id-0}°C"
            "   {memory_percent}% | {memory_used} GB"
          ];
          interval = {
            cpu = 1;
            temps = 2;
            memory = 2;
          };
        }
        { type = "tray"; }
        {
          type = "volume";
          format = "{icon} {percentage}%";
          max_volume = 100;
          icons = {
            volume_high = "󰕾";
            volume_medium = "󰖀";
            volume_low = "󰕿";
            volume_muted = "󰝟";
          };
        }
        {
          type = "notifications";
          show_count = true;
          icons = {
            closed_none = "󰍥";
            closed_some = "󱥂";
            closed_dnd = "󱅯";
            open_none = "󰍡";
            open_some = "󱥁";
            open_dnd = "󱅮";
          };
        }
        {
          type = "custom";
          class = "power-menu";
          bar = [
            {
              type = "button";
              name = "power-btn";
              label = "";
              on_click = "!${pkgs.writeShellScript "power-btn" "${pkgs.procps}/bin/pkill wlogout || ${pkgs.wlogout}/bin/wlogout"}";
            }
          ];
        }
      ];
    };
    style = to-css {
      "@define-color" = [
        "color_bg #${theme.base00};"
        "color_bg_dark #${theme.base01};"
        "color_border #${theme.base03};"
        "color_border_active #${theme.base03};"
        "color_text #${theme.base05};"
        "color_urgent #${theme.base08};"
      ];

      "*" = {
        font-family = "Hack Nerd Font";
        font-size = "16px";
        border = "none";
        border-radius = 0;
      };
      "box, menubar, button" = {
        background-color = "@color_bg";
        background-image = "none";
        box-shadow = "none";
      };
      "button, label".color = "@color_text";
      "button:hover".background-color = "@color_bg_dark";
      "scale trough" = {
        min-width = "1px";
        min-height = "2px";
      };

      # -- Main styles --

      ".background".background-color = "transparent";
      "#bar" = {
        background-color = "@color_bg";
        border = "2px solid @color_border";
        border-radius = "8px";
        margin = "5px";
        padding = "2px";
        box-shadow = "0 4px 8px rgba(0, 0, 0, 0.3)";
      };
      "#bar #start, #bar #center, #bar #end" = {
        background-color = "transparent";
      };
      ".container".background-color = "transparent";
      ".widget-container".background-color = "transparent";
      ".widget" = {
        color = "@color_text";
        font-family = "Hack Nerd Font";
        font-size = "16px";
        padding = "0 8px";
      };

      ".popup" = {
        background-color = "@color_bg";
        border = "1px solid @color_border";
        border-radius = "8px";
        padding = "8px";
      };

      # Ensure widgets don't overflow the rounded corners
      "#bar>*".margin = "2px 0";

      # -- start section --
      "#nix" = {
        font-size = "1.5em";
        margin-left = "5px";
        padding = "5px";
        margin-right = "5px";
      };

      # -- clipboard --

      ".clipboard" = {
        margin-left = "5px";
        font-size = "1.1em";
      };

      ".popup-clipboard .item" = {
        padding-bottom = "0.3em";
        border-bottom = "1px solid @color_border";
      };

      # -- clock --

      ".clock" = {
        font-weight = "bold";
        margin-left = "5px";
      };

      ".popup-clock .calendar-clock" = {
        color = "@color_text";
        font-size = "2.5em";
        padding-bottom = "0.1em";
      };

      ".popup-clock .calendar" = {
        background-color = "@color_bg";
        color = "@color_text";
      };

      ".popup-clock .calendar .header" = {
        padding-top = "1em";
        border-top = "1px solid @color_border";
        font-size = "1.5em";
      };

      ".popup-clock .calendar:selected" = {
        background-color = "@color_border_active";
      };

      # -- launcher --

      ".launcher .item".margin-right = "4px";

      ".launcher .item:not(.focused):hover" = {
        background-color = "@color_bg_dark";
      };

      ".launcher .open".border-bottom = "1px solid @color_text";

      ".launcher .focused" = {
        border-bottom = "1px solid @color_border_active";
      };

      ".launcher .urgent".border-bottom-color = "@color_urgent";

      ".popup-launcher".padding = 0;

      ".popup-launcher .popup-item:not(:first-child)".border-top = "1px solid @color_border";

      # -- music --

      ".music:hover *".background-color = "@color_bg_dark";
      ".popup-music .album-art".margin-right = "1em";
      ".popup-music .icon-box".margin-right = "0.4em";
      ".popup-music .title .icon, .popup-music .title .label" = {
        font-size = "1.7em";
      };
      ".popup-music .controls *:disabled".color = "@color_border";
      ".popup-music .volume .slider slider".border-radius = "100%";
      ".popup-music .volume .icon".margin-left = "4px";
      ".popup-music .progress .slider slider".border-radius = "100%";

      # notifications

      ".notifications .count" = {
        font-size = "0.6rem";
        background-color = "@color_text";
        color = "@color_bg";
        border-radius = "100%";
        margin-right = "3px";
        margin-top = "3px";
        padding-left = "4px";
        padding-right = "4px";
        opacity = 0.7;
      };

      # -- script --

      ".script".padding-left = "10px";

      # -- sys_info --

      ".sysinfo".margin-left = "10px";

      ".sysinfo .item".margin-left = "5px";

      # -- tray --

      ".tray".margin-left = "10px";

      # -- volume --

      ".popup-volume .device-box" = {
        border-right = "1px solid @color_border";
      };

      # -- workspaces --

      ".workspaces .item.focused" = {
        box-shadow = "inset 0 -3px";
        background-color = "@color_bg_dark";
      };

      ".workspaces .item:hover".box-shadow = "inset 0 -3px";
    };
  };
  # programs.ironbar = {
  #   enable = true;
  #   config = {};
  #   style = "";
  #   # package = inputs.ironbar;
  #   # features = ["feature" "another_feature"];
  # };

  fonts.fontconfig.enable = true;
  # home.packages = with pkgs; [
  # ];
}
