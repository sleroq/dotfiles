{ config, lib, inputs', secrets, ... }:

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

      catchAllForPrimaryDomainConfig = lib.optionalAttrs (userConf.isCatchAll or false) {
        catchAll = [ primaryDomain ];
      };

      # Handles:
      # - "localpart" -> "localpart@primaryDomain"
      # - "user@other.com" -> "user@other.com"
      # - "@domain.com" -> "@domain.com" (for domain catch-alls)
      userDefinedAliasesList = userConf.aliases or [];
      processedAliasesConfig = lib.optionalAttrs (userDefinedAliasesList != []) {
        aliases = map (aliasEntry:
          if lib.strings.hasInfix "@" aliasEntry then aliasEntry
          else "${aliasEntry}@${primaryDomain}"
        ) userDefinedAliasesList;
      };

      userDefinedAliasesRegexp = userConf.aliasesRegexp or [];
      aliasesRegexpConfig = lib.optionalAttrs (userDefinedAliasesRegexp != []) {
        aliasesRegexp = userDefinedAliasesRegexp;
      };

      userQuota = userConf.quota or "5G";
      quotaConfig = lib.optionalAttrs (userQuota != null) {
        quota = userQuota;
      };

      userSendOnly = userConf.sendOnly or null;
      sendOnlyConfig = lib.optionalAttrs (userSendOnly != null) {
        sendOnly = userSendOnly;
      };

      userSendOnlyRejectMessage = userConf.sendOnlyRejectMessage or null;
      sendOnlyRejectMessageConfig = lib.optionalAttrs (userSendOnlyRejectMessage != null) {
        sendOnlyRejectMessage = userSendOnlyRejectMessage;
      };

      userSieveScript = userConf.sieveScript or null;
      sieveScriptConfig = lib.optionalAttrs (userSieveScript != null) {
        sieveScript = userSieveScript;
      };
    in
    {
      name = emailAddress;
      value = accountBaseConfig
        // catchAllForPrimaryDomainConfig
        // processedAliasesConfig
        // aliasesRegexpConfig
        // quotaConfig
        // sendOnlyConfig
        // sendOnlyRejectMessageConfig
        // sieveScriptConfig;
    };

  generatedLoginAccounts = lib.listToAttrs (map generateLoginAccountEntry secrets.mailUsers);
in {
  options.cumserver.mailserver = {
    enable = lib.mkEnableOption "Mail server";
    backup.enable = lib.mkEnableOption "backups" // { default = true; };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.caddy.enable;
          message = "Caddy has to be enabled for mailserver to work";
        }
        {
          assertion = lib.isList secrets.mailUsers && lib.all (user: lib.isAttrs user && user ? "name" && user ? "passwordSecretName") secrets.mailUsers;
          message = "secrets.mailUsers must be a list of users, each with at least 'name' and 'passwordSecretName'.";
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
        stateVersion = 3;
        domains = [ "cum.army" ];
        messageSizeLimit = 52428800; # 50MB
        enableManageSieve = true;

        # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
        loginAccounts = generatedLoginAccounts;

        x509.certificateFile = "/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${fqdn}/${fqdn}.crt";
        x509.privateKeyFile = "/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${fqdn}/${fqdn}.key";
      };

      # Wait for caddy, so certs are ready on first ever boot
      systemd.services.dovecot.after = [ "caddy.service" ];

      services.caddy.virtualHosts."mail.cum.army" = {
        extraConfig = ''
          root * ${inputs'.sleroq-link.packages.default}
          file_server
          encode zstd gzip
        '';
      };
    })

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      users.groups.restic-mail-backups.members = [ "virtualMail" ];
      users.groups.restic-s3-backups.members = [ "virtualMail" ];

      services.restic.backups.mailserver = {
        user = "virtualMail";
        repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/backups";
        passwordFile = config.age.secrets.resticMailPassword.path;
        environmentFile = config.age.secrets.resticS3Keys.path;
        initialize = true;
        paths = [ "/var/vmail" "/var/sieve" ];
        exclude = [
          "**/tmp/*"
          "**/cache/*"
          "**/log/*"
        ];
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
        ];
        timerConfig = {
          OnCalendar = "02:30";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })
  ];
}
