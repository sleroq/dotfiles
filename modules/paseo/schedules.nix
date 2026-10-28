{
  config,
  lib,
  pkgs,
  inputs',
  ...
}:
let
  cfg = config.services.paseo;
  inherit (import ./packages.nix { inherit pkgs inputs'; }) paseo;
  optionalString =
    description:
    lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      inherit description;
    };
  definitions = (pkgs.formats.json { }).generate "paseo-schedules.json" cfg.schedules;
in
{
  options.services.paseo.schedules = lib.mkOption {
    default = { };
    description = ''
      Declarative new-agent schedules. Attribute names are stable ownership keys.
      Definitions are reconciled on deployment and daemon startup; app-created
      schedules are left alone. App pause/resume state is preserved, but edits to
      managed definitions are overwritten on reconciliation. Removing an entry
      deletes its managed schedule. Prompts are public Nix store content.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }: {
          options = {
            adoptId = optionalString "Existing schedule ID to adopt on first reconciliation, preserving its history.";
            name = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "Schedule display name in Paseo.";
            };
            cron = lib.mkOption {
              type = lib.types.str;
              description = "Five-field cron expression.";
            };
            timezone = lib.mkOption {
              type = lib.types.str;
              default = "UTC";
              description = "IANA timezone for the cron expression.";
            };
            prompt = lib.mkOption {
              type = lib.types.str;
              description = "Prompt sent to each new agent; use builtins.readFile for long prompts.";
            };
            provider = lib.mkOption {
              type = lib.types.str;
              description = "Agent provider ID, with the model declared separately.";
            };
            model = optionalString "Model ID, or null to use the provider default.";
            modeId = optionalString "Provider mode, or null to use the default.";
            thinkingOptionId = optionalString "Thinking option ID, or null to use the default.";
            cwd = lib.mkOption {
              type = lib.types.str;
              description = "Absolute working directory on the daemon host.";
            };
            maxRuns = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = "Maximum run count, or null for no limit.";
            };
            expiresAt = optionalString "Absolute ISO-8601 expiry timestamp, or null for no expiration.";
            archiveOnFinish = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Archive each scheduled agent after it finishes.";
            };
            isolation = lib.mkOption {
              type = lib.types.enum [
                "local"
                "worktree"
              ];
              default = "local";
              description = "Workspace isolation for scheduled agents.";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf cfg.enable {
    # Keep this unit even with no definitions so the last removal is reconciled.
    systemd.services.paseo-schedules = {
      description = "Reconcile Nix-managed Paseo schedules";
      wantedBy = [ "paseo.service" ];
      requires = [ "paseo.service" ];
      after = [ "paseo.service" ];
      partOf = [ "paseo.service" ];
      restartTriggers = [ definitions ];
      environment.HOME = "/home/${cfg.user}";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
        StateDirectory = "paseo-schedules";
        StateDirectoryMode = "0700";
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${pkgs.nodejs_24}/bin/node ${./schedules.mjs} ${definitions} /var/lib/paseo-schedules/managed.json ${paseo}/libexec/paseo/packages/cli/dist/utils/client.js /home/${cfg.user}/.paseo";
      };
    };
  };
}
