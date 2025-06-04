{ config, lib, inputs, pkgs, secrets, ... }:

let
  cfg = config.cumserver.mailserver;
  fqdn = "mail.cum.army";

  primaryDomain = lib.elemAt config.mailserver.domains 0;

  generateLoginAccountEntry = userConf:
    let
      emailAddress = "${userConf.name}@${primaryDomain}";

      accountBaseConfig = {
        hashedPasswordFile = config.age.secrets."${userConf.passwordSecretName}".path;
      };

      catchAllConfig = lib.optionalAttrs (userConf.isCatchAll or false) {
        catchAll = [ primaryDomain ];
      };

      userProvidedAliases = userConf.additionalDeliveryAliases or [];

      aliasesConfig = lib.optionalAttrs (userProvidedAliases != []) {
        aliases = map (aliasLocalPart: "${aliasLocalPart}@${primaryDomain}") userProvidedAliases;
      };
    in
    {
      name = emailAddress;
      value = accountBaseConfig // catchAllConfig // aliasesConfig;
    };

  generatedLoginAccounts = lib.listToAttrs (map generateLoginAccountEntry secrets.mailUsers);
in {
  options.cumserver.mailserver.enable = lib.mkEnableOption "mailserver";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for mailserver to work";
      }
    ];

    age.secrets = lib.listToAttrs (lib.map (userConf: {
      name = userConf.passwordSecretName;
      value = {
        owner = "virtualMail";
        group = "virtualMail";
        file = ../secrets/mail/${userConf.passwordSecretName};
      };
    }) secrets.mailUsers);

    mailserver = {
      inherit fqdn;
      enable = true;
      stateVersion = 1;
      domains = [ "cum.army" ];

      # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
      loginAccounts = generatedLoginAccounts;

      certificateFile = "/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${fqdn}/${fqdn}.crt";
      keyFile = "/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${fqdn}/${fqdn}.key";
      certificateScheme = "manual";
    };

    services.caddy.virtualHosts."mail.cum.army" = {
      extraConfig = ''
        root * ${inputs.sleroq-link.packages."${pkgs.system}".default}
        file_server
        encode zstd gzip
      '';
    };
  };
}
