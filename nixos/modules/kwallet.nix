{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    libsForQt5.kwallet
    libsForQt5.kwalletmanager
  ];

  security.pam.services.kwallet = {
    name = "kwallet";
    enableKwallet = true;
  };
}
