{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cumserver.dev-env;
in
{
  options.cumserver.dev-env = {
    enable = lib.mkEnableOption "remote development user environment";

    user = lib.mkOption {
      type = lib.types.str;
      default = "dev";
      description = "User that owns the remote development workspace.";
    };

    workspaceDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}/projects";
      description = "Directory for remote development checkouts.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isNormalUser = true;
      description = "Remote development user";
      home = "/home/${cfg.user}";
      createHome = true;
      shell = pkgs.bashInteractive;
      linger = true;

      # FIXME: do not default to all authorizedKeys of the root
      openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys ++ [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdlcjFtISF+IZ8I6+G48VcpsaCbTNpdzX7TfX+MIrPe"
      ];

      subUidRanges = [
        {
          startUid = 100000;
          count = 65536;
        }
      ];
      subGidRanges = [
        {
          startGid = 100000;
          count = 65536;
        }
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.workspaceDirectory} 0750 ${cfg.user} users - -"
    ];
  };
}
