{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.sleroq.kwallet;
in
{
  options.sleroq.kwallet.enable = mkEnableOption "KWallet packages and PAM integration";

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      kdePackages.kwalletmanager
      kdePackages.kwallet
    ];

    security.pam.services.login.enableKwallet = true;
  };
}
