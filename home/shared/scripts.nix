{ pkgs, opts, ... }:

let
  # Disable KDE global shortcuts
  disable-global-kde = pkgs.writeShellScriptBin "disable-global-kde" ''
    hotkeysRC="$XDG_CONFIG_HOME/kglobalshortcutsrc"

    # Remove application launching shortcuts.
    ${pkgs.gnused}/bin/sed -i 's/_launch=[^,]*/_launch=none/g' $hotkeysRC

    # Remove other global shortcuts.
    ${pkgs.gnused}/bin/sed -i 's/^\([^_].*\)=[^,]*/\1=none/g' $hotkeysRC

    # Reload hotkeys.
    ${pkgs.kdePackages.kglobalaccel}/bin/kquitapp5 kglobalaccel && ${pkgs.coreutils}/bin/sleep 2s && ${pkgs.kdePackages.kglobalaccel}/bin/kglobalaccel5 &
  '';

  # Open encrypted vault using gocryptfs
  openvault = pkgs.writeShellScriptBin "openvault" ''
    set -e

    ${pkgs.coreutils}/bin/mkdir -p "$SAFE_PLACE"

    # Mount the encrypted directory
    ${pkgs.gocryptfs}/bin/gocryptfs "$HOME/Sync/Obsidian vault" "$SAFE_PLACE"

    # Start Obsidian/LogSeq and wait for it to close
    # obsidian
    # logseq

    # Unmount
    # fusermount -u "$SAFE_PLACE"
  '';

  # Toggle hyperthreading (requires root access)
  toggleHT = pkgs.writeShellScriptBin "toggleHT" ''
    HYPERTHREADING=1

    function toggleHyperThreading() {
      for CPU in /sys/devices/system/cpu/cpu[0-9]*; do
          CPUID=`${pkgs.coreutils}/bin/basename $CPU | ${pkgs.coreutils}/bin/cut -b4-`
          echo -en "CPU: $CPUID\t"
          [ -e $CPU/online ] && echo "1" > $CPU/online
          THREAD1=`${pkgs.coreutils}/bin/cat $CPU/topology/thread_siblings_list | ${pkgs.coreutils}/bin/cut -f1 -d,`
          if [ $CPUID = $THREAD1 ]; then
              echo "-> enable"
              [ -e $CPU/online ] && echo "1" > $CPU/online
          else
            if [ "$HYPERTHREADING" -eq "0" ]; then echo "-> disabled"; else echo "-> enabled"; fi
              echo "$HYPERTHREADING" > $CPU/online
          fi
      done
    }

    function enabled() {
            echo -en "Enabling HyperThreading\n"
            HYPERTHREADING=1
            toggleHyperThreading
    }

    function disabled() {
            echo -en "Disabling HyperThreading\n"
            HYPERTHREADING=0
            toggleHyperThreading
    }

    #
    ONLINE=$(${pkgs.coreutils}/bin/cat /sys/devices/system/cpu/online)
    OFFLINE=$(${pkgs.coreutils}/bin/cat /sys/devices/system/cpu/offline)
    if [[ $EUID -ne 0 ]]; then
       echo "This script must be run as root"
       exit 1
    fi
    echo "---------------------------------------------------"
    echo -en "CPU's online: $ONLINE\t CPU's offline: $OFFLINE\n"
    echo "---------------------------------------------------"
    while true; do
        read -p "Type in e to enable or d disable hyperThreading or q to quit [e/d/q] ?" ed
        case $ed in
            [Ee]* ) enabled; break;;
            [Dd]* ) disabled;exit;;
            [Qq]* ) exit;;
            * ) echo "Please answer e for enable or d for disable hyperThreading.";;
        esac
    done
  '';

  # Toggle touchpad on/off for X11
  touchpad-toggle = pkgs.writeShellScriptBin "touchpad-toggle" ''
    declare -i ID
    ID=$(${pkgs.xorg.xinput}/bin/xinput list | ${pkgs.gnugrep}/bin/grep -Eio '(touchpad|glidepoint)\s*id=[0-9]{1,2}' | ${pkgs.gnugrep}/bin/grep -Eo '[0-9]{1,2}')
    declare -i STATE
    STATE=$(${pkgs.xorg.xinput}/bin/xinput list-props "$ID" | ${pkgs.gnugrep}/bin/grep 'Device Enabled' | ${pkgs.gawk}/bin/awk '{print $4}')
    if [ "$STATE" -eq 1 ]
    then
        ${pkgs.xorg.xinput}/bin/xinput disable "$ID"
        # echo "Touchpad disabled."
        ${pkgs.libnotify}/bin/notify-send -a 'Touchpad' 'Touchpad Disabled' -i input-touchpad
    else
        ${pkgs.xorg.xinput}/bin/xinput enable "$ID"
        # echo "Touchpad enabled."
        ${pkgs.libnotify}/bin/notify-send -a 'Touchpad' 'Touchpad Enabled' -i input-touchpad
    fi
  '';

in
{
  home.packages = [
    disable-global-kde
    openvault
    toggleHT
    touchpad-toggle
  ];
} 