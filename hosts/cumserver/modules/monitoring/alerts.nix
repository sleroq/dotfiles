{ config, lib, ... }:
let
  cfg = config.cumserver.monitoring;
  hosts = [ cfg.localNodeName ] ++ map (node: node.name) cfg.remoteNodes;
  missingHostQueries = map (
    name: ''absent_over_time(up{job="node",instance=${builtins.toJSON name}}[5m])''
  ) hosts;
  # Only persistent, writable filesystems: ignore virtual/container mounts.
  filesystems = ''job="node",fstype!~"tmpfs|devtmpfs|overlay|squashfs|ramfs|nsfs|tracefs|fuse.*",mountpoint!~"/run(/.*)?|/var/lib/(docker|containers|kubelet)(/.*)?"'';
  diskFree = "100 * node_filesystem_avail_bytes{${filesystems}} / node_filesystem_size_bytes{${filesystems}} and on(instance,device,mountpoint) node_filesystem_readonly{${filesystems}} == 0";
  inodeFree = "100 * node_filesystem_files_free{${filesystems}} / node_filesystem_files{${filesystems}} and on(instance,device,mountpoint) node_filesystem_readonly{${filesystems}} == 0";
  mkRule =
    {
      uid,
      title,
      expr,
      threshold,
      evaluator ? "gt",
      duration ? "10m",
      severity ? "warning",
      summary,
      description,
    }:
    {
      inherit uid title;
      condition = "B";
      for = duration;
      # Host availability rules own missing metrics; other rules should not page
      # again when a host is offline. Query failures still raise DatasourceError.
      noDataState = "OK";
      execErrState = "Error";
      labels = {
        inherit severity;
        scope = "infrastructure";
      };
      annotations = { inherit summary description; };
      data = [
        {
          refId = "A";
          datasourceUid = "Prometheus1";
          relativeTimeRange = {
            from = 600;
            to = 0;
          };
          model = {
            inherit expr;
            datasource = {
              type = "prometheus";
              uid = "Prometheus1";
            };
            refId = "A";
            instant = true;
            range = false;
            intervalMs = 60000;
            maxDataPoints = 43200;
          };
        }
        {
          refId = "B";
          datasourceUid = "__expr__";
          relativeTimeRange = {
            from = 0;
            to = 0;
          };
          model = {
            type = "threshold";
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
            refId = "B";
            expression = "A";
            conditions = [
              {
                type = "query";
                evaluator = {
                  type = evaluator;
                  params = [ threshold ];
                };
                operator.type = "and";
                query.params = [ "B" ];
                reducer = {
                  type = "last";
                  params = [ ];
                };
              }
            ];
          };
        }
      ];
    };
in
{
  config = lib.mkIf cfg.enable {
    age.secrets.grafanaTelegramBotToken = {
      file = ../../secrets/grafanaTelegramBotToken;
      owner = "grafana";
      group = "grafana";
    };

    services.grafana = {
      settings.smtp = {
        enabled = true;
        host = "127.0.0.1:25";
        from_address = "grafana@cum.army";
        from_name = "Infrastructure alerts";
        startTLS_policy = "NoStartTLS";
      };
      provision.alerting = {
        contactPoints.settings = {
          apiVersion = 1;
          contactPoints = [
            {
              orgId = 1;
              name = "infrastructure-email";
              receivers = [
                {
                  uid = "infrastructure-email";
                  type = "email";
                  disableResolveMessage = false;
                  settings = {
                    addresses = "admin@cum.army";
                    singleEmail = true;
                  };
                }
                {
                  uid = "infrastructure-telegram";
                  type = "telegram";
                  disableResolveMessage = false;
                  settings = {
                    bottoken = "$__file{${config.age.secrets.grafanaTelegramBotToken.path}}";
                    chatid = "-1004350530001";
                    parse_mode = "HTML";
                    disable_web_page_preview = true;
                    message = ''
                      {{ range .Alerts -}}
                      {{ if eq .Status "firing" }}🔴 <b>FIRING</b>{{ else }}🟢 <b>RESOLVED</b>{{ end }}{{ with .Labels.severity }} · {{ . | html }}{{ end }}
                      <b>{{ or .Annotations.summary .Labels.alertname | html }}</b>
                      {{ with .GeneratorURL }}<a href="{{ . | html }}">View alert</a>{{ end }}{{ if eq .Status "firing" }}{{ with .SilenceURL }} · <a href="{{ . | html }}">Silence</a>{{ end }}{{ end }}

                      {{ end -}}
                    '';
                  };
                }
              ];
            }
          ];
        };
        policies.settings = {
          apiVersion = 1;
          policies = [
            {
              orgId = 1;
              receiver = "infrastructure-email";
              group_by = [
                "grafana_folder"
                "instance"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
            }
          ];
        };
        rules.settings = {
          apiVersion = 1;
          groups = [
            {
              orgId = 1;
              name = "host-health";
              folder = "Infrastructure";
              interval = "1m";
              rules = map mkRule [
                {
                  uid = "host-unreachable";
                  title = "Host unreachable";
                  expr = ''max by(instance) ((1 - up{job="node",instance!="Interplanetary"}) or ${lib.concatStringsSep " or " missingHostQueries})'';
                  threshold = 0.5;
                  duration = "5m";
                  severity = "critical";
                  summary = "{{ $labels.instance }}: exporter unreachable";
                  description = "Node metrics have failed to scrape for 5 minutes, or disappeared for at least 10 minutes. Check the host, network, and node exporter.";
                }
                {
                  uid = "desktop-metrics-missing";
                  title = "Desktop metrics missing";
                  expr = ''max by(instance) (absent_over_time(up{job="node",instance="Interplanetary"}[15m]) or (1 - max_over_time(up{job="node",instance="Interplanetary"}[15m])))'';
                  threshold = 0.5;
                  duration = "15m";
                  summary = "{{ $labels.instance }}: desktop metrics missing";
                  description = "No successful desktop scrape has arrived for about 30 minutes. The desktop may be sleeping; otherwise check Alloy and HTTPS remote write.";
                }
                {
                  uid = "host-disk-space-low";
                  title = "Disk space low";
                  expr = diskFree;
                  threshold = 15;
                  evaluator = "lt";
                  summary = "{{ $labels.instance }}: {{ $labels.mountpoint }} disk space low";
                  description = "Less than 15% filesystem space available for 10 minutes. Check disk usage and retention before deleting data.";
                }
                {
                  uid = "host-disk-space-critical";
                  title = "Disk space critical";
                  expr = diskFree;
                  threshold = 5;
                  evaluator = "lt";
                  duration = "5m";
                  severity = "critical";
                  summary = "{{ $labels.instance }}: {{ $labels.mountpoint }} disk nearly full";
                  description = "Less than 5% filesystem space available for 5 minutes. Writes and services may fail.";
                }
                {
                  uid = "host-inodes-low";
                  title = "Filesystem inodes low";
                  expr = inodeFree;
                  threshold = 10;
                  evaluator = "lt";
                  summary = "{{ $labels.instance }}: {{ $labels.mountpoint }} inodes low";
                  description = "Less than 10% filesystem inodes free for 10 minutes. Look for directories with excessive small files.";
                }
                {
                  uid = "host-disk-filling";
                  title = "Disk filling within 24 hours";
                  expr = "predict_linear(node_filesystem_avail_bytes{${filesystems}}[6h], 24 * 3600) and on(instance,device,mountpoint) (${diskFree}) < 20";
                  threshold = 0;
                  evaluator = "lt";
                  duration = "30m";
                  summary = "{{ $labels.instance }}: {{ $labels.mountpoint }} predicted to fill";
                  description = "Filesystem is below 20% free and its last 6 hours of growth predict exhaustion within 24 hours, sustained for 30 minutes.";
                }
                {
                  uid = "host-memory-low";
                  title = "Memory available low";
                  expr = ''100 * node_memory_MemAvailable_bytes{job="node"} / node_memory_MemTotal_bytes{job="node"}'';
                  threshold = 10;
                  evaluator = "lt";
                  summary = "{{ $labels.instance }}: available memory below 10%";
                  description = "Available memory, including reclaimable cache, has remained below 10% for 10 minutes. Check process memory and swap activity.";
                }
                {
                  uid = "host-cpu-high";
                  title = "CPU usage high";
                  expr = ''100 * (1 - avg by(instance) (rate(node_cpu_seconds_total{job="node",mode="idle"}[5m])))'';
                  threshold = 90;
                  duration = "15m";
                  summary = "{{ $labels.instance }}: sustained CPU usage above 90%";
                  description = "Average CPU usage has exceeded 90% for 15 minutes. Check running processes, load, and I/O wait.";
                }
                {
                  uid = "host-systemd-failed";
                  title = "Systemd service failed";
                  expr = ''node_systemd_unit_state{job="node",state="failed",name=~".+\\.service"}'';
                  threshold = 0.5;
                  duration = "5m";
                  severity = "critical";
                  summary = "{{ $labels.instance }}: {{ $labels.name }} failed";
                  description = "Systemd reports this service failed for 5 minutes. Inspect its status and journal. Includes failed backup units where the systemd collector is enabled.";
                }
                {
                  uid = "paseo-schedule-failed";
                  title = "Paseo schedule failed or blocked";
                  expr = ''paseo_schedule_run_outcome{instance="Div",outcome=~"failed|blocked|missing"}'';
                  threshold = 0.5;
                  duration = "0s";
                  severity = "critical";
                  summary = "{{ $labels.name }}: schedule result {{ $labels.outcome }}";
                  description = "Run {{ $labels.run }} failed, was blocked, or did not report a valid result. Inspect the schedule run in Paseo for details.";
                }
                {
                  uid = "paseo-checker-failed";
                  title = "Paseo schedule checker failed";
                  expr = ''1 - paseo_schedule_checker_success{instance="Div"}'';
                  threshold = 0.5;
                  duration = "5m";
                  severity = "critical";
                  summary = "Div: Paseo schedule checker failed";
                  description = "The checker could not inspect Paseo. Check the paseo-schedule-checker service journal and the Paseo daemon.";
                }
                {
                  uid = "paseo-checker-stale";
                  title = "Paseo schedule checker metrics stale";
                  expr = ''(time() - paseo_schedule_checker_timestamp_seconds{instance="Div"} > bool 900) or (absent(paseo_schedule_checker_timestamp_seconds{instance="Div"}) and on(instance) (up{job="node",instance="Div"} == 1))'';
                  threshold = 0.5;
                  duration = "5m";
                  severity = "critical";
                  summary = "Div: Paseo schedule checker metrics missing or stale";
                  description = "The checker has not produced fresh metrics for 15 minutes, or its metrics are missing while the node exporter is reachable.";
                }
                {
                  uid = "paseo-schedule-stuck";
                  title = "Paseo schedule run stuck";
                  expr = ''time() - paseo_schedule_run_started_timestamp_seconds{instance="Div"}'';
                  threshold = 86400;
                  duration = "5m";
                  severity = "critical";
                  summary = "{{ $labels.name }}: schedule run has not finished";
                  description = "Run {{ $labels.run }} has been running for more than 24 hours. Inspect it in Paseo.";
                }
                {
                  uid = "paseo-schedule-overdue";
                  title = "Paseo schedule overdue";
                  # Compare with the previous cursor: Paseo advances missed schedules on daemon startup.
                  expr = ''(time() - paseo_schedule_next_run_timestamp_seconds{instance="Div"} offset 1h > 3600) and on(instance,schedule,name) (paseo_schedule_last_run_timestamp_seconds{instance="Div"} < on(instance,schedule,name) paseo_schedule_next_run_timestamp_seconds{instance="Div"} offset 1h) and on(instance,schedule,name) (paseo_schedule_active{instance="Div"} == 1) and on(instance,schedule,name) (paseo_schedule_active{instance="Div"} offset 1h == 1) unless on(instance,schedule,name) paseo_schedule_run_started_timestamp_seconds{instance="Div"}'';
                  threshold = 0;
                  duration = "0s";
                  severity = "critical";
                  summary = "{{ $labels.name }}: scheduled run did not start";
                  description = "The schedule was due over an hour ago but no run was recorded. Check Paseo's schedule history and daemon journal.";
                }
                {
                  uid = "host-oom-kills";
                  title = "OOM kill detected";
                  expr = ''increase(node_vmstat_oom_kill{job="node"}[10m])'';
                  threshold = 0;
                  duration = "0s";
                  severity = "critical";
                  summary = "{{ $labels.instance }}: kernel OOM kill detected";
                  description = "The kernel OOM kill counter increased within the last 10 minutes. Inspect the kernel journal and memory-heavy processes.";
                }
              ];
            }
          ];
        };
      };
    };
    systemd.services.grafana = {
      wants = [ "postfix.service" ];
      after = [ "postfix.service" ];
    };
  };
}
