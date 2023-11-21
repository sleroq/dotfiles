{ pkgs, ... }:
{
  services.xserver = {
    enable = true;
    windowManager.leftwm.enable = true;
  };

  programs.slock.enable = true;
}
