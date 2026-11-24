{ config, lib, ... }:
let
  alloyOtlpEndpoint = "127.0.0.1:4318";
  tempoHttpPort = 3201;
  tempoOtlpEndpoint = "127.0.0.1:14318";
in
{
  config = lib.mkIf config.cumserver.monitoring.enable {
    services = {
      # Only Alloy forwards metrics to the loopback Prometheus receiver.
      prometheus.extraFlags = [ "--web.enable-otlp-receiver" ];
      tempo = {
        enable = true;
        settings = {
          server = {
            http_listen_address = "127.0.0.1";
            http_listen_port = tempoHttpPort;
            grpc_listen_address = "127.0.0.1";
            grpc_listen_port = 9096;
          };
          distributor.receivers.otlp.protocols.http.endpoint = tempoOtlpEndpoint;
          storage.trace = {
            backend = "local";
            local.path = "/var/lib/tempo/blocks";
            wal.path = "/var/lib/tempo/wal";
          };
          backend_worker.compaction.block_retention = "168h";
          backend_scheduler.local_work_path = "/var/lib/tempo";
          live_store = {
            wal.path = "/var/lib/tempo/live-store/traces";
            shutdown_marker_dir = "/var/lib/tempo/live-store/shutdown-marker";
          };
          memberlist.bind_addr = [ "127.0.0.1" ];
          usage_report.reporting_enabled = false;
        };
      };
      caddy.virtualHosts."cum.army".extraConfig = ''
        @kopokaOtlp path /otlp/kopoka/v1/metrics /otlp/kopoka/v1/traces
        handle @kopokaOtlp {
          route {
            @unsupportedMethod not method POST
            header @unsupportedMethod Allow POST
            respond @unsupportedMethod 405
            basic_auth {
              import {$KOPOKA_OTLP_AUTH_FILE}
            }
            uri strip_prefix /otlp/kopoka
            reverse_proxy ${alloyOtlpEndpoint} {
              header_up -Authorization
            }
          }
        }
      '';
      grafana.provision.datasources.settings.datasources = [
        {
          name = "Tempo";
          type = "tempo";
          uid = "Tempo1";
          access = "proxy";
          url = "http://127.0.0.1:${toString tempoHttpPort}";
        }
      ];
    };

    age.secrets.kopokaOtlpCaddyAuth.file = ../../../../shared/secrets/kopokaOtlpCaddyAuth;
    systemd.services.caddy = {
      environment.KOPOKA_OTLP_AUTH_FILE = "%d/kopoka-otlp-auth";
      serviceConfig.LoadCredential = [
        "kopoka-otlp-auth:${config.age.secrets.kopokaOtlpCaddyAuth.path}"
      ];
    };

    environment.etc."alloy/kopoka.alloy".text = ''
      otelcol.receiver.otlp "kopoka" {
        http {
          endpoint = "${alloyOtlpEndpoint}"
        }

        output {
          metrics = [otelcol.exporter.otlphttp.kopoka_metrics.input]
          traces  = [otelcol.processor.tail_sampling.kopoka.input]
        }
      }

      otelcol.processor.tail_sampling "kopoka" {
        decision_wait = "3m"
        num_traces    = 50000
        decision_cache = {
          sampled_cache_size     = 50000,
          non_sampled_cache_size = 50000,
        }

        policy {
          name = "errors"
          type = "status_code"
          status_code {
            status_codes = ["ERROR"]
          }
        }
        policy {
          name = "slow"
          type = "latency"
          latency {
            threshold_ms = 750
          }
        }
        policy {
          name = "baseline"
          type = "probabilistic"
          probabilistic {
            sampling_percentage = 2
          }
        }

        output {
          traces = [otelcol.exporter.otlphttp.kopoka_traces.input]
        }
      }

      otelcol.exporter.otlphttp "kopoka_metrics" {
        client {
          endpoint = "http://127.0.0.1:${toString config.services.prometheus.port}/api/v1/otlp"
        }
      }

      otelcol.exporter.otlphttp "kopoka_traces" {
        client {
          endpoint = "http://${tempoOtlpEndpoint}"
        }
      }
    '';
  };
}
