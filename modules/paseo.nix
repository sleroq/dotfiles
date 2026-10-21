{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.paseo;
  home = "/home/${cfg.user}";
  inherit (import ./paseo/packages.nix { inherit pkgs inputs; }) paseo;
  userBin = "/etc/profiles/per-user/${cfg.user}/bin";
  seedCommand = "${pkgs.nodejs_24}/bin/node /etc/paseo/seed-profile.mjs /etc/paseo/profile.json ${home}";
  syncCommand = "${pkgs.nodejs_24}/bin/node /etc/paseo/pi-profile.mjs /etc/paseo/pi-settings.json /etc/paseo/pi-mcp.json ${home}/.pi/agent ${../home/config/pi/agent/models.json}";
  profile = (pkgs.formats.json { }).generate "paseo-profile.json" {
    files = {
      ".paseo/config.json" = "/etc/paseo-config.json";
      ".pi/agent/settings.json" = "/etc/paseo/pi-settings.json";
      ".pi/agent/mcp.json" = "/etc/paseo/pi-mcp.json";
      ".pi/agent/models.json" = "${../home/config/pi/agent/models.json}";
      ".config/opencode/opencode.json" = "/etc/paseo/opencode.json";
      "sgconfig.yml" = "/etc/paseo/sgconfig.yml";
    };
    links = {
      ".pi/agent/AGENTS.md" = "${../home/config/agents/AGENTS.md}";
      ".pi/agent/extensions" = "${../home/config/pi/agent/extensions}";
      ".pi/agent/agents" = "${../home/config/pi/agent/agents}";
      ".pi/agent/prompts" = "${../home/config/pi/agent/prompts}";
      ".pi/agent/sounds" = "${../home/config/pi/agent/sounds}";
      ".agents/skills" = "${../home/config/agents/skills}";
      ".config/ast-grep/rules" = "${../home/config/ast-grep/rules}";
      ".config/opencode/plugins/direnv.js" = "${./paseo/opencode-direnv.js}";
      ".config/opencode/AGENTS.md" = "${../home/config/agents/AGENTS.md}";
      ".config/opencode/agents" = "${../home/config/opencode/agents}";
      ".config/opencode/commands" = "${../home/config/opencode/commands}";
      ".config/opencode/tui.json" = "${../home/config/opencode/tui.json}";
    };
  };
  baseline = (pkgs.formats.json { }).generate "paseo-config.json" (
    import ./paseo/config.nix {
      inherit lib;
      listen = "127.0.0.1:6767";
      commands = {
        pi = [ "${userBin}/pi-direnv" ];
        opencode = [ "${userBin}/opencode" ];
        codex = [ "${userBin}/codex" ];
      };
      relay = {
        enabled = cfg.relay.enable;
      }
      // lib.optionalAttrs (cfg.relay.endpoint != null) { endpoint = cfg.relay.endpoint; };
    }
  );
  configSyncCommand = "${pkgs.nodejs_24}/bin/node /etc/paseo/config.mjs /etc/paseo-config.json ${home}/.paseo/config.json";

in
{
  imports = [
    ./paseo/workspace.nix
    ./paseo/pi.nix
    ./paseo/opencode.nix
    ./paseo/schedules.nix
  ];

  options.services.paseo = {
    enable = lib.mkEnableOption "private Paseo coding daemon";
    relay.enable = lib.mkEnableOption "end-to-end encrypted access through the Paseo relay";
    relay.endpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        (builtins.fromJSON (builtins.readFile ../home/config/paseo/config.json)).daemon.relay.endpoint;
      description = "Relay host:port (including an explicit port); null retains the shared endpoint. Custom endpoints use TLS.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "paseo";
      description = "Account running the Paseo daemon.";
    };
    manageUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Provision a dedicated account and its baseline Git/SSH configuration.";
    };
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys allowed to access the Paseo account.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
    environment.etc."paseo-config.json".source = baseline;
    environment.etc."paseo/config.mjs".source = ./paseo/config.mjs;
    environment.etc."paseo/profile.json".source = profile;
    environment.etc."paseo/seed-profile.mjs".source = ../lib/seed-profile.mjs;
    environment.etc."systemd/system.control/paseo-tailnet.service".source = "/dev/null";
    environment.etc."systemd/system.control/paseo.service.d/90-paseo-config.conf".text = ''
      [Service]
      EnvironmentFile=${config.age.secrets.paseo-exa-env.path}
      ExecStartPre=
      ExecStart=
      ExecStartPre=${pkgs.coreutils}/bin/mkdir -p ${home}/.paseo
      ExecStartPre=${pkgs.coreutils}/bin/chmod 0700 ${home}/.paseo
      ExecStartPre=${seedCommand}
      ExecStartPre=${configSyncCommand}
      ExecStartPre=${syncCommand}
      ExecStart=${paseo}/bin/paseo daemon run
    '';
    systemd.services.paseo = {
      description = "Private Paseo coding daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = [
          seedCommand
          configSyncCommand
          syncCommand
        ];
        ExecStart = "${paseo}/bin/paseo daemon run";
        User = cfg.user;
        WorkingDirectory = "${home}/projects";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        NoNewPrivileges = true;
      };
    };
  };
}
