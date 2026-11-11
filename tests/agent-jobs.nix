{
  pkgs,
  agent-jobs,
  gvisor ? pkgs.callPackage ../packages/gvisor-pty-fix.nix { },
}:
let
  fixture = pkgs.buildGoModule {
    pname = "agent-jobs-fixture";
    version = "1";
    src = ./agent-jobs-fixture;
    vendorHash = null;
    env.CGO_ENABLED = 0;
  };
  image = pkgs.callPackage ../packages/agent-sandbox.nix {
    inherit agent-jobs;
    pi = fixture;
  };
  makeJob = mode: {
    enable = true;
    schedule = "yearly";
    repository = "fixture/repo";
    cloneURL = "file:///var/lib/fixture-repo";
    branch = "automation/fixture";
    allowedPaths = [ "allowed.txt" ];
    prompt = "Fixture only; do not contact any model.";
    piCommand = [
      "/bin/agent-jobs-fixture"
      mode
    ];
    model = "fixture";
    timeoutSeconds = if mode == "timeout" then 30 else 180;
    memoryMB = 2048;
    workspaceMB = 2048;
    outputMB = 32;
    files = pkgs.lib.optionalAttrs (mode == "security") {
      allowed = "${pkgs.writeText "allowed-fixture-credential" "allowed fixture credential"}";
    };
  };
  listener = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = "${fixture}/bin/agent-jobs-fixture serve";
  };
in
pkgs.testers.runNixOSTest {
  name = "agent-jobs";
  nodes = {
    machine = { ... }: {
      imports = [ ../modules/agent-jobs.nix ];
      services.agent-jobs = {
        enable = true;
        package = agent-jobs;
        inherit image;
        gvisorPackage = gvisor;
        viewer.port = 8788;
        jobs =
          pkgs.lib.genAttrs [ "success" "failure" "timeout" "security" "bad-path" "symlink" ] makeJob
          // {
            nix-build = makeJob "nix-build" // {
              piCommand = [
                "/bin/agent-jobs-fixture"
                "nix-build"
                "${pkgs.bashInteractive}/bin/bash"
              ];
            };
            direnv = makeJob "direnv";
          };
      };
      systemd.services.fixture-listener = listener;
      systemd.timers.agent-job-security.enable = false;
      specialisation.changed-timers.configuration = {
        systemd.timers.agent-job-success.enable = pkgs.lib.mkForce false;
        systemd.timers.agent-job-security.enable = pkgs.lib.mkForce true;
      };
      virtualisation.podman = {
        enable = true;
        dockerCompat = false;
      };
      services.prometheus.exporters.node.listenAddress = "0.0.0.0";
      environment.systemPackages = [
        pkgs.git
        pkgs.curl
        pkgs.jq
        pkgs.iproute2
      ];
      virtualisation.memorySize = 6144;
      virtualisation.diskSize = 8192;
      virtualisation.cores = 2;
    };
    private = { lib, ... }: {
      systemd.services.fixture-listener = listener;
      systemd.services.dnsmasq.wantedBy = lib.mkForce [ ];
      environment.systemPackages = [ pkgs.curl ];
      services.dnsmasq = {
        enable = true;
        settings = {
          listen-address = "1.1.1.1";
          address = "/agent-jobs.fixture/203.0.113.2";
          no-resolv = true;
          no-hosts = true;
          bind-interfaces = true;
        };
      };
      networking.firewall.allowedTCPPorts = [
        53
        18080
      ];
      networking.firewall.allowedUDPPorts = [ 53 ];
    };
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("agent-jobs-enablement.service")
    machine.succeed("test ! -e /var/lib/agent-jobs/enabled-since/security")
    machine.succeed("test -s /var/lib/agent-jobs/enabled-since/success")
    machine.succeed("echo 123 > /var/lib/agent-jobs/enabled-since/success")
    machine.reboot()
    machine.wait_for_unit("agent-jobs-enablement.service")
    machine.succeed("test \"$(cat /var/lib/agent-jobs/enabled-since/success)\" = 123")
    machine.succeed("systemctl restart agent-jobs-enablement.service")
    machine.succeed("test \"$(cat /var/lib/agent-jobs/enabled-since/success)\" = 123")
    system = machine.succeed("readlink -f /run/current-system").strip()
    machine.succeed(f"{system}/specialisation/changed-timers/bin/switch-to-configuration test")
    machine.wait_for_unit("agent-jobs-enablement.service")
    machine.succeed("test ! -e /var/lib/agent-jobs/enabled-since/success && test -s /var/lib/agent-jobs/enabled-since/security")
    machine.succeed(f"{system}/bin/switch-to-configuration test")
    machine.wait_for_unit("agent-jobs-enablement.service")
    machine.succeed("test ! -e /var/lib/agent-jobs/enabled-since/security && test \"$(cat /var/lib/agent-jobs/enabled-since/success)\" -gt 123")
    machine.succeed('grep -F \'agent_job_enabled_since_timestamp_seconds{agent_job="success"}\' /var/lib/prometheus-node-exporter-text-files/agent-jobs-enablement.prom')
    machine.fail('grep -F \'agent_job_enabled_since_timestamp_seconds{agent_job="security"}\' /var/lib/prometheus-node-exporter-text-files/agent-jobs-enablement.prom')
    machine.wait_for_unit("docker.service")
    runtime = machine.succeed("curl -fsS --unix-socket /var/run/docker.sock http://localhost/info | jq -r '.Runtimes.runsc.path'").strip()
    assert runtime == "${gvisor}/bin/runsc", f"Unexpected configured runtime: {runtime}"
    print(machine.succeed(f"{runtime} --version"))
    machine.wait_for_unit("agent-job-viewer.service")
    machine.wait_for_unit("fixture-listener.service")
    private.wait_for_unit("fixture-listener.service")
    private.succeed("ip address add 1.1.1.1/32 dev lo")
    private.succeed("systemctl start dnsmasq.service")
    private.wait_for_unit("dnsmasq.service")
    private.fail("curl --connect-timeout 2 http://192.168.1.1:8788/api/runs")
    private.succeed("ip address add 203.0.113.2/32 dev lo")
    machine.succeed("ip route add 203.0.113.2/32 via 192.168.1.2")
    machine.succeed("ip route add 1.1.1.1/32 via 192.168.1.2")
    machine.succeed("ip address add 169.254.169.254/32 dev lo")
    machine.succeed("curl -fsS http://192.168.1.2:18080 && curl -fsS http://203.0.113.2:18080 && curl -fsS http://169.254.169.254:18080")
    machine.succeed("mkdir -p /var/lib/fixture-repo/nested && cd /var/lib/fixture-repo && git init && git config user.name Fixture && git config user.email fixture@example.invalid && echo original > allowed.txt && printf 'source_up\nexport FIXTURE_ENV=root\n' > .envrc && echo 'export FIXTURE_ENV=nested' > nested/.envrc && git add allowed.txt .envrc nested/.envrc && git commit -m initial")
    machine.succeed("echo forbidden-host-credential > /run/host-canary")
    machine.succeed("podman load -i ${image}")
    machine.succeed("podman run -d --pull=never --name existing-service -p 127.0.0.1:18081:18080 --entrypoint /bin/agent-jobs-fixture agent-sandbox:mvp serve")
    machine.wait_until_succeeds("curl -fsS http://127.0.0.1:18081")
    machine.succeed("podman exec existing-service /bin/curl --connect-timeout 3 -fsS http://203.0.113.2:18080")
    machine.succeed("systemctl restart docker.service")
    machine.succeed("podman exec existing-service /bin/curl --connect-timeout 3 -fsS http://203.0.113.2:18080")
    def start_job(name):
        status, output = machine.execute(f"systemctl start agent-job-{name}.service")
        if status != 0:
            failed_id = machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/runs?job={name} | jq -r '.[0].id'").strip()
            for artifact in ["stderr.log", "stdout.log"]:
                _, content = machine.execute(f"curl -fsS http://127.0.0.1:8788/api/jobs/{name}/runs/{failed_id}/artifacts/{artifact}")
                print(content)
            raise Exception(f"{name}: {output}")
    start_job("success")
    start_job("direnv")
    machine.succeed("curl -fsS http://127.0.0.1:8788/api/runs | jq -e '.[] | select(.job == \"success\" and .status == \"success\")'")
    run_id = machine.succeed("curl -fsS http://127.0.0.1:8788/api/runs?job=success | jq -r '.[0].id'").strip()
    machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/jobs/success/runs/{run_id}/sessions | jq -e 'length == 1'")
    machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/jobs/success/runs/{run_id}/artifacts/output/pr-body.md | grep -Fx 'Update the fixture file.'")
    machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/jobs/success/runs/{run_id}/artifacts/output/result.json | jq -e '.agent == \"success\" and (has(\"validation\") | not)'")
    machine.succeed(f"test ! -e /var/lib/agent-jobs/success/{run_id}/output/validation.log")
    machine.succeed(f"curl -fsS http://127.0.0.1:8788/jobs/success/runs/{run_id}/sessions/fixture.jsonl | grep 'fixture complete'")
    machine.succeed("test -s /var/lib/prometheus-node-exporter-text-files/agent-jobs.prom")
    machine.succeed("curl -fsS http://127.0.0.1:9100/metrics | grep agent_job_last_duration_seconds")
    machine.succeed("""curl -fsS http://127.0.0.1:9100/metrics | grep -Fx 'agent_job_schedule_enabled{agent_job="success"} 1'""")
    machine.succeed("""curl -fsS http://127.0.0.1:9100/metrics | grep -Fx 'agent_job_schedule_enabled{agent_job="security"} 0'""")
    start_job("security")
    for name in ["failure", "timeout", "bad-path", "symlink"]:
        machine.fail(f"systemctl start agent-job-{name}.service")
        machine.succeed(f"find /var/lib/agent-jobs/{name} -name result.json | grep .")
    timeout_id = machine.succeed("curl -fsS http://127.0.0.1:8788/api/runs?job=timeout | jq -r '.[0].id'").strip()
    machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/jobs/timeout/runs/{timeout_id}/sessions | jq -e 'length == 1'")
    machine.succeed("test -z \"$(docker ps -aq --filter name=agent-jobs-)\"")
    machine.succeed("test -z \"$(docker volume ls -q --filter name=agent-jobs-)\"")
    machine.succeed("test \"$(curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:8788/api/runs)\" = 405")
    machine.succeed("test \"$(systemctl show -p User --value agent-job-viewer.service)\" = agent-job-viewer")
    machine.fail("su -s /bin/sh agent-job-viewer -c 'test -r /var/lib/agent-jobs-work'")
    machine.succeed("""curl -fsS http://127.0.0.1:9100/metrics | grep -Fx 'agent_job_last_run_success{agent_job="failure"} 0'""")
    # A Nix/runtime compatibility failure must not hide the preceding isolation checks.
    start_job("nix-build")
    machine.succeed("""curl -fsS 'http://127.0.0.1:8788/api/runs?job=nix-build' | jq -e '.[0].status == "success"'""")
    machine.succeed("test -z \"$(docker ps -aq --filter name=agent-jobs-)\"")
    machine.wait_until_succeeds("! mountpoint -q /var/lib/agent-jobs-work/nix-build/nix")
    machine.succeed("curl -fsS http://127.0.0.1:18081")
    machine.succeed("podman exec existing-service /bin/curl --connect-timeout 3 -fsS http://203.0.113.2:18080")
    machine.succeed("podman rm -f existing-service")
  '';
}
