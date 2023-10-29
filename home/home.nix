{ pkgs, opts, lib, ... }:

let
  safe-place = ''
    # Safe place
    export SAFE_PLACE="/tmp/vault"
  '';
in
{
  home.username = "sleroq";
  home.homeDirectory = "/home/sleroq";

  programs.git = {
    enable = true;
    userName = "Sleroq";
    userEmail = "hireme@sleroq.link";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    BROWSER = "librewolf";
    TERMINAL = "foot";
  };

  xsession = {
    enable = true;
    profileExtra = safe-place;
  };

  programs.zsh = lib.mkIf opts.zsh-integration {
    envExtra = safe-place;
  };

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    libsForQt5.ark
    libsForQt5.filelight

    p7zip
    unzip

    helvetica-neue-lt-std
    arkpandora_ttf
    (nerdfonts.override { fonts = [ "JetBrainsMono" "Ubuntu" "Agave" ]; })
    powerline-fonts
    noto-fonts
    noto-fonts-extra
    noto-fonts-cjk
    noto-fonts-emoji
    source-han-sans
    source-han-sans-japanese
    source-han-serif-japanese
    font-awesome
  ];

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

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfreePredicate = (_: true);
}
