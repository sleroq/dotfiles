{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cumserver.mailserver;
  domain = builtins.head config.mailserver.domains;
  submissionAddress = "key-submission@${domain}";
  stateDir = "/var/lib/wks";
  directory = "${stateDir}/domains";
  domainDir = "${directory}/${domain}";
  environment = {
    HOME = stateDir;
    GNUPGHOME = "${stateDir}/gnupg";
  };

  # GnuPG fixes this path at build time; adding sendmail to PATH is insufficient.
  gnupg = pkgs.gnupg.overrideAttrs (old: {
    configureFlags = (old.configureFlags or [ ]) ++ [
      "--with-mailprog=/run/wrappers/bin/sendmail"
    ];
  });
  wksServer = "${gnupg}/bin/gpg-wks-server --directory ${directory}";

  receiveConfig = pkgs.writeText "wks.procmailrc" ''
    SHELL=${pkgs.bash}/bin/bash
    PATH=${
      lib.makeBinPath [
        gnupg
        pkgs.coreutils
      ]
    }
    HOME=${environment.HOME}
    GNUPGHOME=${environment.GNUPGHOME}
    DEFAULT=/dev/null

    :0
    * ^FROM_DAEMON
    /dev/null

    :0
    * ^X-WKS-Loop:
    /dev/null

    :0 w
    |${wksServer} --from ${submissionAddress} --header X-WKS-Loop=wks.${domain} --receive --send

    # Defer failed processing instead of losing requests during an outage.
    :0 e
    {
      EXITCODE=75
      HOST
    }
  '';
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "wks-admin" ''
        export GNUPGHOME=${environment.GNUPGHOME}
        exec ${wksServer} "$@"
      '')
    ];

    users.groups.wks = { };
    users.users.wks = {
      isSystemUser = true;
      group = "wks";
      home = stateDir;
    };

    systemd.services.wks-init = {
      description = "Initialize the OpenPGP Web Key Service";
      wantedBy = [ "multi-user.target" ];
      before = [ "postfix.service" ];
      inherit environment;
      path = [
        gnupg
        pkgs.gawk
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "wks";
        Group = "wks";
        StateDirectory = "wks";
        StateDirectoryMode = "0711";
        UMask = "0077";
      };
      script = ''
        install -d -m 0700 "$GNUPGHOME"
        install -d -m 0711 ${directory}
        install -d -m 0755 ${domainDir}
        printf '%s\n' '${submissionAddress}' > ${domainDir}/submission-address
        # Keep the normal mailbox/private-key confirmation flow; no auth-submit.
        printf '%s\n' '# Confirmation-based publication' > ${domainDir}/policy
        chmod 0644 ${domainDir}/{submission-address,policy}
        ${wksServer} --list-domains
        # GnuPG's mkdir is affected by the private service umask.
        chmod 0755 ${domainDir}/hu

        if ! gpg --batch --list-secret-keys '=${submissionAddress}' >/dev/null 2>&1; then
          gpg --batch --pinentry-mode loopback --passphrase "" \
            --quick-generate-key '${submissionAddress}' future-default default 0
        fi
        fingerprint=$(gpg --batch --with-colons --list-secret-keys '=${submissionAddress}' \
          | awk -F: '$1 == "fpr" { print $10; exit }')
        ${wksServer} --install-key "$fingerprint" '${submissionAddress}'
      '';
    };

    systemd.services.postfix = {
      requires = [ "wks-init.service" ];
      after = [ "wks-init.service" ];
    };
    systemd.services.caddy = {
      wants = [ "wks-init.service" ];
      after = [ "wks-init.service" ];
    };

    services.postfix = {
      # Stop this reserved address from being rewritten to a catch-all mailbox.
      mapFiles.wks = pkgs.writeText "wks-recipient" ''
        ${submissionAddress} ${submissionAddress}
      '';
      transport = ''
        ${submissionAddress} wks:
      '';
      settings.main = {
        virtual_alias_maps = lib.mkBefore [ "hash:/var/lib/postfix/conf/wks" ];
        virtual_mailbox_maps = lib.mkBefore [ "hash:/var/lib/postfix/conf/wks" ];
        wks_destination_recipient_limit = 1;
      };
      settings.master.wks = {
        command = "pipe";
        privileged = true;
        chroot = false;
        maxproc = 1;
        args = [
          "flags=Rq"
          "user=wks"
          "argv=${pkgs.procmail}/bin/procmail"
          "-m"
          "${receiveConfig}"
        ];
      };
    };

    services.caddy.virtualHosts."openpgpkey.${domain}".extraConfig = ''
      @public path /.well-known/openpgpkey/${domain}/hu/* /.well-known/openpgpkey/${domain}/policy /.well-known/openpgpkey/${domain}/submission-address
      handle @public {
        uri strip_prefix /.well-known/openpgpkey/${domain}
        root * ${domainDir}
        header Access-Control-Allow-Origin "*"
        header /.well-known/openpgpkey/${domain}/hu/* Content-Type application/octet-stream
        file_server
      }
      handle {
        respond 404
      }
    '';

    systemd.services.wks-cleanup = {
      description = "Expire unconfirmed OpenPGP key submissions";
      requires = [ "wks-init.service" ];
      after = [ "wks-init.service" ];
      inherit environment;
      serviceConfig = {
        Type = "oneshot";
        User = "wks";
        Group = "wks";
      };
      script = "${wksServer} --cron";
    };
    systemd.timers.wks-cleanup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # The mail backup runs as virtualMail and cannot read the service private key.
    services.restic.backups.wks = lib.mkIf cfg.backup.enable {
      user = "root";
      inherit (config.services.restic.backups.mailserver)
        repository
        passwordFile
        environmentFile
        initialize
        pruneOpts
        ;
      paths = [ stateDir ];
      exclude = [ "${environment.GNUPGHOME}/S.*" ];
      timerConfig = {
        OnCalendar = "04:30";
        Persistent = true;
      };
    };
  };
}
