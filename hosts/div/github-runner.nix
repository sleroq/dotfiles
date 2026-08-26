{ config, pkgs, ... }:

{
  age.secrets.githubRunnerCumbanToken.file = ./secrets/githubRunnerCumbanToken;

  services.github-runners.cumban = {
    enable = true;
    url = "https://github.com/sleroq/cumban";
    name = "div-cumban";
    tokenFile = config.age.secrets.githubRunnerCumbanToken.path;
    tokenType = "registration";
    replace = true;
    ephemeral = false;
    extraLabels = [
      "div"
      "cumban-profile"
    ];
    extraPackages = with pkgs; [
      bun
      nodejs
    ];
  };

  # Playwright downloads the Chromium revision pinned by bun.lock. nix-ld
  # supplies the dynamic loader and libraries expected by that binary.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      glib
      gtk3
      libdrm
      libgbm
      libxkbcommon
      mesa
      nspr
      nss
      pango
      systemd
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
    ];
  };
}
