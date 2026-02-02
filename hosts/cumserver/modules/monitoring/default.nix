{ config, lib, ... }:
let
  cfg = config.cumserver.monitoring;
in
{
  options.cumserver.monitoring = {
    enable = lib.mkEnableOption "Monitoring";
    grafanaPasswordPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to the Grafana password file";
    };
    localNodeName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Display name for the local monitoring node";
    };
    remoteNodes = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name of the remote node";
          };
          address = lib.mkOption {
            type = lib.types.str;
            description = "Address of the remote node (IP:PORT)";
          };
          username = lib.mkOption {
            type = lib.types.str;
            default = "prometheus";
            description = "Username for basic auth";
          };
          passwordPath = lib.mkOption {
            type = lib.types.path;
            description = "Path to the password file for basic auth";
          };
          enableTLS = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable TLS encryption";
          };
          tlsInsecure = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Skip TLS certificate verification";
          };
        };
      });
      default = [];
      description = "List of remote nodes to monitor";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for Grafana to work";
      }
    ];

    services = {
      alloy = {
        enable = true;
        extraFlags = [
          "--server.http.listen-addr=127.0.0.1:12345"
          "--disable-reporting"
        ];
      };
      grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = "127.0.0.1";
            http_port = 3200;
            root_url = "https://cum.army/grafana/";
          };
          security = {
            admin_user = "sleroq";
            admin_password = "$__file{${cfg.grafanaPasswordPath}}";
          };
        };
        provision = {
          enable = true;
          datasources.settings = {
            apiVersion = 1;
            datasources = [
              {
                name = "Loki";
                type = "loki";
                uid = "Loki1";
                url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}";
              }
              {
                name = "Prometheus";
                type = "prometheus";
                uid = "Prometheus1";
                url = "http://localhost:${toString config.services.prometheus.port}";
                jsonData = {
                  timeInterval = "1m";
                };
              }
            ];
          };
          dashboards.settings = {
            apiVersion = 1;
            providers = [
              {
                name = "dashboards";
                options.path = ./dashboards;
                options.foldersFromFilesStructure = true;
              }
            ];
          };
        };
      };
      prometheus = {
        enable = true;
        # keep data for 90 days
        extraFlags = [ 
          "--storage.tsdb.retention.time=90d"
          "--web.enable-remote-write-receiver"
        ];
        scrapeConfigs = [
            {
                job_name = "prometheus";
                static_configs = [{ targets = [ "127.0.0.1:9090" ]; }];
            }
            {
                job_name = "node-local";
                static_configs = [{ targets = [ "127.0.0.1:9100" ]; }];
                relabel_configs = [
                    {
                        target_label = "job";
                        replacement = "node";
                    }
                    {
                        target_label = "instance";
                        replacement = cfg.localNodeName;
                    }
                    {
                        target_label = "node_name";
                        replacement = cfg.localNodeName;
                    }
                    {
                        target_label = "node_type";
                        replacement = "local";
                    }
                ];
            }
        ] ++ lib.optionals (config.cumserver.frp.enable or false) [
          {
            job_name = "frps";
            static_configs = [{ targets = [ "127.0.0.1:${toString config.services.frp.instances.frps.settings.webServer.port}" ]; }];
          }
        ] ++ lib.optionals (config.cumserver.restic.enable or false) [
          {
            job_name = "restic";
            static_configs = [{ targets = [ "127.0.0.1:${toString config.cumserver.restic.port}" ]; }];
          }
        ] ++ (map (node: {
            job_name = "node-${lib.strings.toLower node.name}";
            static_configs = [{
                targets = [ node.address ];
                labels = {
                    node_name = node.name;
                    node_type = "remote";
                };
            }];
            basic_auth = {
                inherit (node) username;
                password_file = toString node.passwordPath;
            };
            scheme = if node.enableTLS then "https" else "http";
            tls_config = lib.mkIf node.enableTLS {
                insecure_skip_verify = node.tlsInsecure;
            };
            relabel_configs = [
                {
                    target_label = "job";
                    replacement = "node";
                }
                {
                    source_labels = [ "node_name" ];
                    target_label = "instance";
                    replacement = "\${1}";
                }
            ];
        }) cfg.remoteNodes);
        exporters = {
            node = {
                enable = true;
                enabledCollectors = [ "systemd" "processes" ];
            };
        };
      };
      loki = {
        enable = true;
        configuration = {
          server = {
            http_listen_port = 3100;
          };
          auth_enabled = false;

          analytics = {
            reporting_enabled = false;
          };

          ingester = {
            lifecycler = {
              address = "127.0.0.1";
              ring = {
                kvstore = {
                  store = "inmemory";
                };
                replication_factor = 1;
              };
            };
          };

          pattern_ingester = {
            enabled = true;
            lifecycler = {
              ring = {
                kvstore = {
                  store = "inmemory";
                };
                replication_factor = 1;
              };
              num_tokens = 128;
              heartbeat_period = "5s";
              heartbeat_timeout = "1m";
              address = "127.0.0.1";
              unregister_on_shutdown = true;
            };
            client_config = {
              pool_config = {
                client_cleanup_period = "15s";
                health_check_ingesters = true;
                remote_timeout = "1s";
              };
              remote_timeout = "5s";
            };
            concurrent_flushes = 32;
            flush_check_period = "1m";
            max_clusters = 300;
            max_eviction_ratio = 0.25;
            connection_timeout = "2s";
            max_allowed_line_length = 3000;
          };

          schema_config = {
            configs = [
              {
                from = "2024-01-01";
                store = "boltdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "168h"; # seven days
                };
              }
            ];
          };

          storage_config = {
            boltdb = {
              directory = "/var/lib/loki/index";
            };
            filesystem = {
              directory = "/var/lib/loki/chunks";
            };
          };

          limits_config = {
            allow_structured_metadata = false;
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
          };

          table_manager = {
            chunk_tables_provisioning = {
              inactive_read_throughput = 0;
              inactive_write_throughput = 0;
              provisioned_read_throughput = 0;
              provisioned_write_throughput = 0;
            };
            index_tables_provisioning = {
              inactive_read_throughput = 0;
              inactive_write_throughput = 0;
              provisioned_read_throughput = 0;
              provisioned_write_throughput = 0;
            };
            retention_deletes_enabled = true;
            retention_period = "720h"; # 30 days
          };
        };
      };
      caddy = {
        virtualHosts = {
          "cum.army" = {
            extraConfig = ''
              handle_path /grafana/* {
                  reverse_proxy 127.0.0.1:3200
              }
            '';
          };
        };
      };
    };

    environment.etc."alloy/config.alloy".text = ''
      logging {
        level = "info"
        format = "logfmt"
      }

      livedebugging {
        enabled = true
      }

      // Get hostname for labeling
      local.file "hostname" {
        filename = "/proc/sys/kernel/hostname"
      }

      // Discover local node_exporter target
      discovery.relabel "integrations_node_exporter" {
        targets = [{
          __address__ = "localhost:9100",
        }]

        rule {
          source_labels = ["__address__"]
          target_label = "instance"
          replacement = "${cfg.localNodeName}"
        }

        rule {
          target_label = "job"
          replacement = "node"
        }
      }

      // Scrape local node_exporter metrics
      prometheus.scrape "integrations_node_exporter" {
        targets = discovery.relabel.integrations_node_exporter.output
        forward_to = [prometheus.remote_write.prometheus.receiver]
        scrape_interval = "15s"
      }

      ${lib.concatMapStringsSep "\n" (node: ''
      // Discover remote node_exporter target: ${node.name}
      discovery.relabel "integrations_node_exporter_${node.name}" {
        targets = [{
          __address__ = "${node.address}",
        }]

        rule {
          source_labels = ["__address__"]
          target_label = "instance"
          replacement = "${node.name}"
        }

        rule {
          target_label = "job"
          replacement = "node"
        }
      }

      // Scrape remote node_exporter metrics: ${node.name}
      prometheus.scrape "integrations_node_exporter_${node.name}" {
        targets = discovery.relabel.integrations_node_exporter_${node.name}.output
        forward_to = [prometheus.remote_write.prometheus.receiver]
        scrape_interval = "30s"
        basic_auth {
          username = "${node.username}"
          password_file = "${node.passwordPath}"
        }
        ${lib.optionalString node.enableTLS ''
        tls_config {
          insecure_skip_verify = ${if node.tlsInsecure then "true" else "false"}
        }
        ''}
      }
      '') cfg.remoteNodes}

      // Send metrics to Prometheus
      prometheus.remote_write "prometheus" {
        endpoint {
          url = "http://localhost:${toString config.services.prometheus.port}/api/v1/write"
        }
      }

      // Relabeling rules for systemd journal logs
      discovery.relabel "logs_integrations_node_exporter_journal_scrape" {
        targets = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }

        rule {
          source_labels = ["__journal__boot_id"]
          target_label  = "boot_id"
        }

        rule {
          source_labels = ["__journal__transport"]
          target_label  = "transport"
        }

        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }
      }

      // Collect systemd journal logs
      loki.source.journal "logs_integrations_node_exporter_journal_scrape" {
        max_age = "24h"
        relabel_rules = discovery.relabel.logs_integrations_node_exporter_journal_scrape.rules
        forward_to = [loki.write.loki.receiver]
      }

      // Discover log files
      local.file_match "logs_integrations_node_exporter_direct_scrape" {
        path_targets = [{
          __address__ = "localhost",
          __path__    = "/var/log/{syslog,messages,*.log}",
          instance    = local.file.hostname.content,
          job         = "integrations/node_exporter",
        }]
      }

      // Collect log files
      loki.source.file "logs_integrations_node_exporter_direct_scrape" {
        targets = local.file_match.logs_integrations_node_exporter_direct_scrape.targets
        forward_to = [loki.write.loki.receiver]
      }

      // Send logs to Loki
      loki.write "loki" {
        endpoint {
          url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push"
        }
      }
    '';
  };
}
