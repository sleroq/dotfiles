{
  config,
  lib,
  pkgs,
  inputs',
  ...
}:
let
  cfg = config.services.paseo;
  home = "/home/${cfg.user}";
  inherit (import ./packages.nix { inherit pkgs inputs'; }) tools;
  environment = {
    HOME = home;
    PI_FFF_MODE = "override";
    DIRENV_CONFIG = "/etc/direnv";
    PASEO_HOME = "${home}/.paseo";
    GOPATH = "${home}/develop/go";
    GOBIN = "${home}/develop/go/bin";
    PNPM_HOME = "${home}/.local/share/pnpm";
    BUN_INSTALL = "${home}/.bun";
    AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
  };
  path =
    lib.makeBinPath (config.users.users.${cfg.user}.packages ++ [ pkgs.coreutils ])
    + ":${home}/.nix-profile/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${cfg.user}/bin:${home}/.local/bin:${home}/.deno/bin:${home}/.bun/bin:${home}/.npm/bin:${environment.GOBIN}:${environment.PNPM_HOME}";
  gitConfig = pkgs.writeText "paseo-gitconfig" ''
    [user]
      name = Sleroq
      email = hireme@sleroq.link
    [init]
      defaultBranch = master
    [pull]
      rebase = true
  '';
  sgConfig = (pkgs.formats.yaml { }).generate "paseo-sgconfig.yml" {
    ruleDirs = [ "${home}/.config/ast-grep/rules" ];
  };
in
{
  config = lib.mkIf cfg.enable {
    age.secrets.paseo-git-crypt-key = {
      file = ../../shared/secrets/dotfiles-git-crypt-key;
      path = "${home}/.config/git/dotfiles.key";
      owner = cfg.user;
      group = "users";
      mode = "0600";
    };
    age.secrets.paseo-exa-env = {
      file = ../../shared/secrets/exa-env;
      path = "${home}/.config/pi/exa.env";
      owner = cfg.user;
      group = "users";
      mode = "0600";
    };
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    users.users.${cfg.user} = {
      packages = tools;
      sleroq.neovim.enable = lib.mkDefault true;
    }
    // lib.optionalAttrs cfg.manageUser {
      isNormalUser = true;
      inherit home;
      homeMode = "0700";
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };
    programs.bash.interactiveShellInit = ''
      if [ "$USER" = ${lib.escapeShellArg cfg.user} ]; then
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") environment
        )}
        if [ -r ${lib.escapeShellArg config.age.secrets.paseo-exa-env.path} ]; then
          . ${lib.escapeShellArg config.age.secrets.paseo-exa-env.path}
          export EXA_API_KEY
        fi
        export PATH=${lib.escapeShellArg path}
      fi
    '';
    systemd.services.paseo.serviceConfig.EnvironmentFile = config.age.secrets.paseo-exa-env.path;
    systemd.services.paseo.environment = environment // {
      PATH = lib.mkForce path;
    };
    environment.etc."paseo/sgconfig.yml".source = sgConfig;
    environment.etc."paseo/ssh-config".text = ''
      Host cumserver
        HostName 64.188.69.19
        User root
        IdentityFile ~/.ssh/cumserver-deploy
        IdentitiesOnly yes
    '';
    systemd.tmpfiles.rules = [
      "d ${home}/.config 0700 ${cfg.user} users -"
      "d ${home}/.config/pi 0700 ${cfg.user} users -"
      "d ${home}/.config/git 0700 ${cfg.user} users -"
    ]
    ++ lib.optionals cfg.manageUser [
      "d ${home}/projects 0700 ${cfg.user} users -"
      "d ${home}/.ssh 0700 ${cfg.user} users -"
      "L+ ${home}/.ssh/config - - - - /etc/paseo/ssh-config"
      "L+ ${home}/.gitconfig - - - - ${gitConfig}"
    ];
  };
}
