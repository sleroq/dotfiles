{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    kdePackages.kwalletmanager
    kdePackages.kwallet
  ];

  security.pam.services.login.enableKwallet = true;
}
