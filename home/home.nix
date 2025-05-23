{ pkgs, ... }:

{
  home.username = "sleroq";
  home.homeDirectory = "/home/sleroq";

  programs.git = {
    enable = true;
    userName = "Sleroq";
    userEmail = "hireme@sleroq.link";
    extraConfig = {
      "push" = {
        "autoSetupRemote" = "true";
      };
    };
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "foot";
  };

  xsession.enable = true;

  services.syncthing.enable = true;

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

  # TODO: Remove after homemanager update
  systemd.user.startServices = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfreePredicate = (_: true);
}
