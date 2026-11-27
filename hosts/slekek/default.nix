{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.slekek;
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSh54pu9bAH8DFBKPtswFJzevCft+gHZStJQ0trYGoj sleroq@cum.army"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me"
  ];
  chargeLimit = if cfg.serverMode then "60" else "80";
in
{
  imports = [
    ./disk-config.nix
    ./minecraft-tunnel.nix
  ];

  options.slekek.serverMode = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Run slekek as a headless 24/7 Cumcraft server instead of handheld Steam Deck mode.";
  };

  config = lib.mkMerge [
    {
      jovian.devices.steamdeck = {
        enable = true;
        autoUpdate = false;
        enableFwupdBiosUpdates = true;
      };

      boot = {
        # Mainline 7.3.5 is cached and supports Jupiter Wi-Fi, audio, GPU, and gamepad
        # while Jovian-Experiments/linux archive fetches return GitHub 502s.
        kernelPackages = pkgs.linuxPackages_latest;
        loader.systemd-boot = {
          enable = true;
          configurationLimit = 10;
        };
        loader.efi.canTouchEfiVariables = true;
        tmp.cleanOnBoot = true;
        kernelModules = [ "tcp_bbr" ];
        kernel.sysctl = {
          "net.core.default_qdisc" = "fq";
          "net.ipv4.tcp_congestion_control" = "bbr";
        };
      };

      age.secrets = {
        wifiEnv.file = ./secrets/wifiEnv.age;
        slekekMetricsPassword.file = ../../shared/secrets/slekekMetricsPassword;
      };

      networking = {
        hostName = "slekek";
        networkmanager = {
          enable = true;
          wifi.powersave = false;
          unmanaged = [ "interface-name:tailscale0" ];
          ensureProfiles = {
            environmentFiles = [ config.age.secrets.wifiEnv.path ];
            profiles.home-wifi = {
              connection = {
                id = "teto-factory-69-5G";
                type = "wifi";
                autoconnect = true;
              };
              wifi = {
                mode = "infrastructure";
                ssid = "teto-factory-69-5G";
              };
              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$HOME_WIFI_PSK";
              };
              ipv4.method = "auto";
              ipv6.method = "auto";
            };
          };
        };
        firewall = {
          enable = true;
          trustedInterfaces = [ "tailscale0" ];
          allowedTCPPorts = [
            22
            25565
            8100
          ];
          allowedUDPPorts = [ config.services.tailscale.port ];
        };
      };

      services = {
        openssh = {
          enable = true;
          openFirewall = false;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
          };
        };
        tailscale.enable = true;
        fstrim.enable = true;
        journald.settings.Journal.SystemMaxUse = "200M";
        udev.extraRules = ''
          ACTION=="add|change", SUBSYSTEM=="hwmon", ATTR{name}=="steamdeck_hwmon", ATTR{max_battery_charge_level}="${chargeLimit}"
        '';
        alloy = {
          enable = true;
          extraFlags = [
            "--server.http.listen-addr=127.0.0.1:12345"
            "--disable-reporting"
          ];
        };
      };

      systemd.services.alloy.serviceConfig.LoadCredential = [
        "metrics-password:${config.age.secrets.slekekMetricsPassword.path}"
      ];

      environment.etc."alloy/config.alloy".text = ''
        prometheus.exporter.unix "slekek" {
          enable_collectors = ["systemd", "processes", "drm"]
        }

        discovery.relabel "slekek" {
          targets = prometheus.exporter.unix.slekek.targets

          rule {
            target_label = "job"
            replacement = "node"
          }
          rule {
            target_label = "instance"
            replacement = "Slekek"
          }
          rule {
            target_label = "node_name"
            replacement = "Slekek"
          }
          rule {
            target_label = "node_type"
            replacement = "remote"
          }
        }

        prometheus.scrape "slekek" {
          targets = discovery.relabel.slekek.output
          scrape_interval = "60s"
          forward_to = [prometheus.remote_write.cumserver.receiver]
        }

        ${lib.optionalString cfg.serverMode ''
          prometheus.scrape "fabric" {
            targets = [{
              __address__ = "127.0.0.1:25585",
              job = "fabric",
              instance = "Slekek",
            }]
            scrape_interval = "30s"
            forward_to = [prometheus.remote_write.cumserver.receiver]
          }
        ''}

        prometheus.remote_write "cumserver" {
          endpoint {
            url = "https://cum.army/api/v1/write"
            basic_auth {
              username = "slekek"
              password_file = sys.env("CREDENTIALS_DIRECTORY") + "/metrics-password"
            }
          }
        }
      '';

      time.timeZone = "Europe/Moscow";
      i18n.defaultLocale = "en_US.UTF-8";

      users.users = {
        root.openssh.authorizedKeys.keys = authorizedKeys;
        ${username} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
            "video"
            "input"
            "gamemode"
          ];
          openssh.authorizedKeys.keys = authorizedKeys;
        };
      };
      security.sudo.wheelNeedsPassword = false;

      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = with pkgs; [
        btop
        curl
        dust
        gitMinimal
        htop
        mcrcon
        rsync
        tailscale
        tmux
        zstd
      ];

      zramSwap = {
        enable = true;
        algorithm = "lz4";
      };

      nix = {
        settings = {
          auto-optimise-store = true;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          max-jobs = 2;
        };
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 14d";
        };
      };

      specialisation.handheld.configuration = {
        system.nixos.tags = [ "handheld" ];
        slekek.serverMode = lib.mkForce false;
      };

      system.stateVersion = "26.05";
    }

    (lib.mkIf cfg.serverMode {
      boot.kernelParams = [ "video=eDP-1:d" ];

      services.udev.extraRules = ''
        ACTION=="add|change", SUBSYSTEM=="backlight", ATTR{brightness}="0", ATTR{bl_power}="4"
      '';

      systemd.services = {
        "systemd-backlight@".enable = false;
        slekek-backlight-off = {
          description = "Power off built-in Steam Deck backlight in server mode";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-udev-settle.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "slekek-backlight-off" ''
              for bl in /sys/class/backlight/*; do
                [ -d "$bl" ] || continue
                echo 0 > "$bl/brightness" || true
                echo 4 > "$bl/bl_power" || true
              done
            '';
          };
        };
      };

      systemd.targets = {
        sleep.enable = false;
        suspend.enable = false;
        hibernate.enable = false;
        hybrid-sleep.enable = false;
      };

      age.secrets = {
        cumcraftEasyAuthPassword = {
          file = ../cumserver/secrets/cumcraftEasyAuthPassword;
          owner = "minecraft";
        };
        resticMinecraftPassword = {
          owner = "minecraft";
          group = "minecraft";
          file = ../cumserver/secrets/resticMinecraftPassword;
        };
        resticMinecraftRestEnv.file = ../cumserver/secrets/resticMinecraftRestEnv;
      };

      services.cumcraft = {
        enable = true;
        easyAuth.passwordFile = config.age.secrets.cumcraftEasyAuthPassword.path;
        bluemap = {
          enable = true;
          livePlayers = true;
        };
      };

      services.minecraft-servers.servers.cum = {
        jvmOpts = lib.mkForce (
          lib.concatStringsSep " " [
            "-Xms4G"
            "-Xmx8G"
            "-XX:MaxDirectMemorySize=1G"
            "-XX:MaxMetaspaceSize=512M"
            "-XX:+UseG1GC"
            "-XX:+ParallelRefProcEnabled"
            "-XX:MaxGCPauseMillis=200"
            "-XX:+UnlockExperimentalVMOptions"
            "-XX:+DisableExplicitGC"
            "-XX:G1NewSizePercent=30"
            "-XX:G1MaxNewSizePercent=40"
            "-XX:G1HeapRegionSize=8M"
            "-XX:G1ReservePercent=20"
            "-Dfabric.modsFolder=.cumcraft-mods"
          ]
        );
        serverProperties = {
          enable-rcon = true;
          "rcon.password" = "localbackup";
          "rcon.port" = 25576;
        };
        extraStartPre = lib.mkAfter ''
          install -CDm 0644 ${../cumserver/modules/bluemap-world.conf} config/bluemap/maps/world.conf
        '';
      };

      systemd.services.minecraft-server-cum = {
        restartTriggers = [ config.age.secrets.cumcraftEasyAuthPassword.file ];
        serviceConfig = {
          TimeoutStopSec = lib.mkForce "120s";
          MemoryLow = "8G";
        };
      };

      services.restic.backups.minecraft = {
        user = "minecraft";
        repository = "rest:http://div.capybara-menkent.ts.net:8040/minecraft/";
        passwordFile = config.age.secrets.resticMinecraftPassword.path;
        environmentFile = config.age.secrets.resticMinecraftRestEnv.path;
        initialize = true;
        paths = [ "/srv/minecraft/cum" ];
        exclude = [
          "logs"
          "crash-reports"
          "hs_err_pid*.log"
          "**/DistantHorizons.sqlite"
          "**/vss-lod"
          "/srv/minecraft/cum/bluemap"
        ];
        timerConfig = {
          OnCalendar = "03:30";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        backupPrepareCommand = ''
          set +e
          if systemctl is-active --quiet minecraft-server-cum.service; then
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25576 -p localbackup "save-off" || true
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25576 -p localbackup "save-all flush" || true
          fi
        '';
        backupCleanupCommand = ''
          set +e
          if systemctl is-active --quiet minecraft-server-cum.service; then
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25576 -p localbackup "save-on" || true
          fi
        '';
      };
    })

    (lib.mkIf (!cfg.serverMode) {
      jovian.steam = {
        enable = true;
        autoStart = true;
        user = username;
        desktopSession = "plasma";
      };

      services.desktopManager.plasma6.enable = true;
      environment.systemPackages = [ pkgs.moonlight-qt ];
    })
  ];
}
