{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.services.agent-jobs;
  json = pkgs.formats.json { };
  jobType = types.submodule {
    options = {
      enable = mkEnableOption "this agent job schedule";
      schedule = mkOption { type = types.str; };
      repository = mkOption { type = types.str; };
      cloneURL = mkOption {
        type = types.str;
        default = "";
      };
      branch = mkOption { type = types.str; };
      allowedPaths = mkOption { type = types.listOf types.str; };
      prompt = mkOption { type = types.lines; };
      piCommand = mkOption {
        type = types.listOf types.str;
        default = [ "pi" ];
      };
      validation = mkOption {
        type = types.listOf (types.listOf types.str);
        default = [ ];
      };
      model = mkOption {
        type = types.str;
        default = "";
      };
      thinking = mkOption {
        type = types.str;
        default = "high";
      };
      timeoutSeconds = mkOption {
        type = types.ints.positive;
        default = 3600;
      };
      overdueAfterSeconds = mkOption {
        type = types.ints.positive;
        default = 90000;
        description = "Maximum interval between completed runs before monitoring reports this enabled job overdue.";
      };
      memoryMB = mkOption {
        type = types.ints.positive;
        default = 4096;
      };
      cpus = mkOption {
        type = types.ints.positive;
        default = 2;
      };
      pids = mkOption {
        type = types.ints.positive;
        default = 512;
      };
      workspaceMB = mkOption {
        type = types.ints.positive;
        default = 2048;
      };
      outputMB = mkOption {
        type = types.ints.positive;
        default = 512;
      };
      environmentFiles = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      files = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      readTokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      publish = {
        enabled = mkEnableOption "publication";
        appID = mkOption {
          type = types.str;
          default = "";
        };
        installationID = mkOption {
          type = types.str;
          default = "";
        };
        privateKeyFile = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        title = mkOption {
          type = types.str;
          default = "";
        };
        reviewer = mkOption {
          type = types.str;
          default = "";
        };
      };
    };
  };
  enabled = lib.filterAttrs (_: job: job.enable) cfg.jobs;
  nixStore = name: "/var/lib/agent-jobs-work/${name}/nix";
  nixStoreUnit = name: "${utils.escapeSystemdPath (nixStore name)}.mount";
  credentials =
    job:
    (lib.mapAttrs' (name: value: lib.nameValuePair "env-${name}" value) job.environmentFiles)
    // (lib.mapAttrs' (name: value: lib.nameValuePair "file-${name}" value) job.files)
    // lib.optionalAttrs (job.readTokenFile != null) { read-token = job.readTokenFile; }
    // lib.optionalAttrs (job.publish.privateKeyFile != null) {
      private-key = job.publish.privateKeyFile;
    };
  jobConfig =
    name: job:
    let
      cred = key: "/run/credentials/agent-job-${name}.service/${key}";
    in
    json.generate "agent-job-${name}.json" {
      inherit name;
      inherit (job)
        repository
        branch
        prompt
        validation
        model
        thinking
        cpus
        pids
        ;
      clone_url = job.cloneURL;
      allowed_paths = job.allowedPaths;
      image = cfg.imageName;
      network = "agentjobs";
      pi_command = job.piCommand;
      timeout_seconds = job.timeoutSeconds;
      memory_mb = job.memoryMB;
      workspace_mb = job.workspaceMB;
      output_mb = job.outputMB;
      environment_files = lib.mapAttrs (key: _: cred "env-${key}") job.environmentFiles;
      files = lib.mapAttrs (key: _: cred "file-${key}") job.files;
      read_token_file = if job.readTokenFile == null then "" else cred "read-token";
      publish = {
        inherit (job.publish)
          enabled
          title
          reviewer
          ;
        app_id = job.publish.appID;
        installation_id = job.publish.installationID;
        private_key_file = if job.publish.privateKeyFile == null then "" else cred "private-key";
      };
    };
  metrics = "/var/lib/prometheus-node-exporter-text-files/agent-jobs.prom";
  blocked = [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.0.0.0/24"
    "192.168.0.0/16"
    "198.18.0.0/15"
    "224.0.0.0/4"
    "240.0.0.0/4"
  ];
in
{
  options.services.agent-jobs = {
    enable = mkEnableOption "isolated scheduled agent jobs";
    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../packages/agent-jobs { };
    };
    gvisorPackage = mkOption {
      type = types.package;
      default = pkgs.callPackage ../packages/gvisor-pty-fix.nix { };
      description = "gVisor runtime used by the agent sandboxes.";
    };
    image = mkOption {
      type = types.package;
      description = "Pinned sandbox image containing Pi and the agent-jobs executable.";
    };
    imageName = mkOption {
      type = types.str;
      default = "agent-sandbox:mvp";
    };
    stateDirectory = mkOption {
      type = types.str;
      default = "/var/lib/agent-jobs";
    };
    jobs = mkOption {
      type = types.attrsOf jobType;
      default = { };
    };
    retentionDays = mkOption {
      type = types.ints.positive;
      default = 30;
    };
    viewer = {
      port = mkOption {
        type = types.port;
        default = 8787;
      };
      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      bindAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
      };
      passwordHashFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Runtime Caddy import file containing the operator username and password hash.";
      };
    };
  };
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.viewer.hostname == null || cfg.viewer.passwordHashFile != null;
        message = "The agent run viewer requires an operator password hash before enabling HTTPS ingress.";
      }
      {
        assertion =
          !lib.elem cfg.viewer.bindAddress [
            "0.0.0.0"
            "::"
          ];
        message = "Bind the agent viewer HTTPS ingress to a private interface address, not all interfaces.";
      }
    ];
    services.caddy = lib.optionalAttrs (cfg.viewer.hostname != null) {
      enable = true;
      virtualHosts.${cfg.viewer.hostname}.extraConfig = ''
        bind ${cfg.viewer.bindAddress}
        tls internal
        basic_auth {
          import ${toString cfg.viewer.passwordHashFile}
        }
        handle /metrics {
          reverse_proxy 127.0.0.1:9100
        }
        handle {
          reverse_proxy 127.0.0.1:${toString cfg.viewer.port}
        }
      '';
    };
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = lib.mkDefault "127.0.0.1";
      openFirewall = false;
      extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files" ];
    };
    users.groups.job-viewer = { };
    users.users.agent-job-viewer = {
      isSystemUser = true;
      group = "job-viewer";
    };
    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        runtimes.runsc = {
          path = "${cfg.gvisorPackage}/bin/runsc";
          runtimeArgs = [ "--platform=systrap" ];
        };
      };
    };
    environment.etc."agent-jobs-schedules.prom".text = lib.concatStrings (
      lib.mapAttrsToList (name: job: ''
        agent_job_max_interval_seconds{agent_job="${name}"} ${toString job.overdueAfterSeconds}
        agent_job_schedule_enabled{agent_job="${name}"} ${
          if config.systemd.timers."agent-job-${name}".enable then "1" else "0"
        }
      '') enabled
    );
    systemd.tmpfiles.rules = [
      "L+ /var/lib/prometheus-node-exporter-text-files/agent-jobs-schedules.prom - - - - /etc/agent-jobs-schedules.prom"
      "d ${cfg.stateDirectory} 0750 root job-viewer -"
      "d /var/lib/agent-jobs-work 0700 root root -"
      "d /var/lib/prometheus-node-exporter-text-files 0755 root root -"
    ];
    systemd.mounts = lib.mapAttrsToList (name: job: {
      what = "tmpfs";
      where = nixStore name;
      type = "tmpfs";
      options = "size=${toString job.workspaceMB}M,mode=0750,uid=1000,gid=1000,nosuid,nodev";
      unitConfig.StopWhenUnneeded = true;
    }) enabled;
    systemd.services =
      lib.mapAttrs' (
        name: job:
        lib.nameValuePair "agent-job-${name}" {
          description = "Agent job ${name}";
          requires = [
            "agent-jobs-network.service"
            (nixStoreUnit name)
          ];
          after = [
            "agent-jobs-network.service"
            (nixStoreUnit name)
          ];
          path = [
            pkgs.docker
            pkgs.git
            pkgs.coreutils
            pkgs.util-linux
          ];
          serviceConfig = {
            Type = "oneshot";
            Group = "job-viewer";
            UMask = "0027";
            LoadCredential = lib.mapAttrsToList (key: value: "${key}:${value}") (credentials job);
            ExecStart = "${cfg.package}/bin/agent-jobs run -config ${jobConfig name job} -state ${cfg.stateDirectory} -metrics ${metrics}";
            TimeoutStartSec = job.timeoutSeconds + 300;
            KillMode = "control-group";
          };
        }
      ) enabled
      // {
        agent-jobs-network = {
          description = "Agent sandbox bridge and egress policy";
          requires = [ "docker.service" ];
          after = [
            "docker.service"
            "network-pre.target"
          ];
          before = [ "agent-job-viewer.service" ];
          path = [
            pkgs.docker
            pkgs.iptables
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            docker network inspect agentjobs >/dev/null 2>&1 || docker network create --driver bridge --subnet 172.30.0.0/24 --opt com.docker.network.bridge.name=agentjobs0 --opt com.docker.network.bridge.enable_icc=false agentjobs
            iptables -N AGENT-JOBS 2>/dev/null || iptables -F AGENT-JOBS
            iptables -C DOCKER-USER -i agentjobs0 -j AGENT-JOBS 2>/dev/null || iptables -I DOCKER-USER 1 -i agentjobs0 -j AGENT-JOBS
            iptables -C INPUT -i agentjobs0 -j DROP 2>/dev/null || iptables -I INPUT 1 -i agentjobs0 -j DROP
            ip6tables -C INPUT -i agentjobs0 -j DROP 2>/dev/null || ip6tables -I INPUT 1 -i agentjobs0 -j DROP
            ip6tables -C FORWARD -i agentjobs0 -j DROP 2>/dev/null || ip6tables -I FORWARD 1 -i agentjobs0 -j DROP
            iptables -A AGENT-JOBS -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
            ${lib.concatMapStringsSep "\n" (range: "iptables -A AGENT-JOBS -d ${range} -j DROP") blocked}
            iptables -A AGENT-JOBS -j RETURN
            docker load -i ${cfg.image}
          '';
        };
        agent-job-viewer = {
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-tmpfiles-setup.service" ];
          serviceConfig = {
            User = "agent-job-viewer";
            Group = "job-viewer";
            ExecStart = "${cfg.package}/bin/agent-jobs serve -state ${cfg.stateDirectory} -listen 127.0.0.1:${toString cfg.viewer.port}";
            ProtectSystem = "strict";
            ProtectHome = true;
            NoNewPrivileges = true;
            PrivateTmp = true;
            InaccessiblePaths = [ "/var/lib/agent-jobs-work" ];
            ReadOnlyPaths = [ cfg.stateDirectory ];
          };
        };
        agent-jobs-prune = {
          serviceConfig = {
            Type = "oneshot";
            Group = "job-viewer";
            UMask = "0027";
            ExecStart = "${cfg.package}/bin/agent-jobs prune -state ${cfg.stateDirectory} -days ${toString cfg.retentionDays}";
          };
        };
      };
    systemd.timers =
      lib.mapAttrs' (
        name: job:
        lib.nameValuePair "agent-job-${name}" {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = job.schedule;
            Persistent = true;
          };
        }
      ) enabled
      // {
        agent-jobs-prune = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
          };
        };
      };
  };
}
