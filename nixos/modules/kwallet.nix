{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    libsForQt5.kwallet
    libsForQt5.kwalletmanager
  ];

  security.pam.services.login.enableKwallet = true;
}
