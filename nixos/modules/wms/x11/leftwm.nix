{ pkgs, ... }:
{
  services.xserver = {
    windowManager.leftwm.enable = true;
  };

  programs.slock.enable = true;
}
