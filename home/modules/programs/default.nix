{ config, pkgs, ... }:

with config;
{
  imports = [
    ./tmux.nix
    ./lf.nix
    ./zathura.nix
    ./kitty.nix
    ./foot.nix
  ];

  services.flameshot.enable = true;
  services.safeeyes.enable = true;
  services.kdeconnect.enable = true;
  systemd.user.services.ss = {
    Install.WantedBy = [ "multi-user.target" ];
    # Install.After = [ "network.target" ];
    Unit.Description = "Shadowsocks reverse proxy whatever meow meow";
    Service = {
      ExecStart = ''${pkgs.bore-cli}/bin/bore local 8666 --to 5.252.25.99 --port 40004'';         
    };
  };

  home.packages = with pkgs; [
    sonixd
    filezilla
    tor-browser-bundle-bin
    tdesktop
    discord
    schildichat-desktop
    chromium
    exodus
    krita
    libsForQt5.kdenlive
    ngrok
    gimp
    libreoffice-fresh
    mpv
    obs-studio
    networkmanager-openvpn
    qbittorrent
    keepassxc
    logseq

    # CLI
    gdb
    thefuck
    gocryptfs
    stow
    xclip
    onefetch
    btop
    bore-cli
    ngrok
    neofetch
    ffmpeg
    # shadowsocks-libev
    # shadowsocks-v2ray-plugin

    # Work
    skypeforlinux
    remmina
    nomachine-client
    rustdesk

    # Hacking
    pyrit2
    wifite2
    macchanger
    iw
  ];
}
