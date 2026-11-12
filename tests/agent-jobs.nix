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
    fumoProxy = true;
  };
  makeJob = mode: {
    enable = true;
    schedule = "yearly";
    repository = "fixture/repo";
    cloneURL = "file:///var/lib/fixture-repo";
    branch = "automation/fixture";
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
  inspectScratch = pkgs.writeShellScript "inspect-agent-job-scratch" ''
    set -eu
    export PATH=${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.git
        pkgs.util-linux
        pkgs.gnugrep
      ]
    }
    scratch=/var/lib/agent-jobs-work/success/scratch
    tmp=$(mktemp -d)
    cleanup() {
      rm -rf "$scratch/repo" "$tmp"
      mount -o remount,size=2048M "$scratch"
    }
    trap cleanup EXIT

    options=$(findmnt -n -T "$scratch" -o OPTIONS)
    echo "$options" | grep -F size=2097152k
    echo "$options" | grep -F nosuid
    echo "$options" | grep -F nodev
    test "$(stat -c '%a:%u:%g' "$scratch")" = 700:0:0

    mount -o remount,size=16M "$scratch"
    git init -q "$tmp/source"
    git -C "$tmp/source" config user.name Fixture
    git -C "$tmp/source" config user.email fixture@example.invalid
    dd if=/dev/zero of="$tmp/source/large.bin" bs=1M count=32 status=none
    git -C "$tmp/source" add large.bin
    git -C "$tmp/source" diff --cached --binary > "$tmp/candidate.patch"
    git init -q "$scratch/repo"
    if git -C "$scratch/repo" apply --index "$tmp/candidate.patch" 2> "$tmp/error"; then
      echo 'oversized binary patch unexpectedly succeeded' >&2
      exit 1
    fi
    grep -F 'No space left on device' "$tmp/error"
  '';
in
pkgs.testers.runNixOSTest {
  name = "agent-jobs";
  nodes = {
    machine = { ... }: {
      imports = [ ../modules/agent-jobs.nix ];
      services.agent-jobs = {
        enable = true;
        package = agent-jobs;
        pi = pkgs.writeShellScriptBin "pi" ''
          exec ${fixture}/bin/agent-jobs-fixture "$@"
        '';
        inherit image;
        gvisorPackage = gvisor;
        viewer.port = 8788;
        proxy = {
          keyFile = toString (pkgs.writeText "fixture-fumo-key" "fixture-real-key");
          upstream = "http://127.0.0.1:18080";
        };
        jobs =
          pkgs.lib.genAttrs [ "success" "failure" "timeout" "security" "arbitrary-path" "symlink" ] makeJob
          // {
            nix-build = makeJob "nix-build" // {
              piCommand = [
                "/bin/agent-jobs-fixture"
                "nix-build"
                "${pkgs.bashInteractive}/bin/bash"
              ];
            };
            direnv = makeJob "direnv";
            retry = makeJob "success" // {
              publish = {
                enabled = true;
                appID = "1";
                installationID = "2";
                privateKeyFile = toString (pkgs.writeText "fixture-invalid-private-key" "invalid fixture key");
              };
            };
          };
      };
      systemd.services.fixture-listener = listener;
      networking.firewall.trustedInterfaces = [ "eth1" ];
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
    machine.start(allow_reboot=True)
    private.start()
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
    machine.succeed("systemctl --version | head -1")
    machine.succeed("su -s /bin/sh agent-job-viewer -c 'LC_ALL=C TZ=UTC systemctl --system --no-pager --all --timestamp=unix --property=Id,LoadState,ActiveState,UnitFileState,NextElapseUSecRealtime show agent-job-success.timer' | grep -E '^NextElapseUSecRealtime=@[0-9]+$'")
    machine.succeed("curl -fsS 'http://127.0.0.1:8788/?job=success' | grep -F 'Scheduled'")
    machine.succeed("curl -fsS 'http://127.0.0.1:8788/?job=security' | grep -F 'Not scheduled or unavailable'")
    machine.fail("systemctl is-enabled agent-job-security.timer")
    machine.wait_for_unit("fixture-listener.service")
    machine.wait_for_unit("agent-jobs-proxy.service")
    private.wait_for_unit("fixture-listener.service")
    private.succeed("ip address add 1.1.1.1/32 dev lo")
    private.succeed("systemctl start dnsmasq.service")
    private.wait_for_unit("dnsmasq.service")
    private.fail("curl --connect-timeout 2 http://192.168.1.1:8788/api/runs")
    private.succeed("ip route add 172.30.0.0/24 via 192.168.1.1")
    private.fail("curl --connect-timeout 2 http://172.30.0.1:8789/v1/check")
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
    def check_session_export(name, run_id):
        base = "http://127.0.0.1:8788"
        machine.succeed(f"test -s /var/lib/agent-jobs/{name}/{run_id}/session-html/fixture.jsonl.html")
        machine.succeed(f"curl -fsS {base}/jobs/{name}/runs/{run_id}/sessions/fixture.jsonl | grep -F 'fixture exported session'")
        machine.succeed(f"curl -fsSI {base}/jobs/{name}/runs/{run_id}/sessions/fixture.jsonl | tr -d '\\r' | grep -Fx \"Content-Security-Policy: sandbox allow-scripts; default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; connect-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'\"")
        machine.succeed(f"curl -fsS {base}/api/jobs/{name}/runs/{run_id}/sessions/fixture.jsonl | grep -F 'fixture complete'")
    scratch_unit = "var-lib-agent\\x2djobs\\x2dwork-success-scratch.mount"
    for service in ["agent-job-success.service", "agent-job-publish-success@fixture.service"]:
        for dependency in ["Requires", "After"]:
            machine.succeed(f"systemctl show {service} -p {dependency} --value | grep -F '{scratch_unit}'")
        machine.succeed(f"test $(systemctl show {service} -p MemoryMax --value) = 2147483648")
        machine.succeed(f"test $(systemctl show {service} -p MemorySwapMax --value) = 0")
    machine.succeed("test $(systemctl show agent-jobs-proxy.service -p MemoryMax --value) = 268435456")
    machine.succeed("test $(systemctl show agent-jobs-proxy.service -p MemorySwapMax --value) = 0")
    machine.succeed(f"systemd-run --wait --pipe --property='Requires={scratch_unit}' --property='After={scratch_unit}' ${inspectScratch}")
    machine.wait_until_succeeds("! mountpoint -q /var/lib/agent-jobs-work/success/scratch")
    start_job("success")
    machine.wait_until_succeeds("! mountpoint -q /var/lib/agent-jobs-work/success/scratch")
    start_job("direnv")
    machine.succeed("curl -fsS http://127.0.0.1:8788/api/runs | jq -e '.[] | select(.job == \"success\" and .status == \"success\")'")
    run_id = machine.succeed("curl -fsS http://127.0.0.1:8788/api/runs?job=success | jq -r '.[0].id'").strip()
    machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/jobs/success/runs/{run_id}/sessions | jq -e 'length == 1'")
    machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/jobs/success/runs/{run_id}/artifacts/output/pr-body.md | grep -Fx 'Update the fixture file.'")
    machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/jobs/success/runs/{run_id}/artifacts/output/result.json | jq -e '.agent == \"success\" and (has(\"validation\") | not)'")
    machine.succeed(f"test ! -e /var/lib/agent-jobs/success/{run_id}/output/validation.log")
    machine.succeed(f"mkdir -p /var/lib/agent-jobs/retry && cp -a /var/lib/agent-jobs/success/{run_id} /var/lib/agent-jobs/retry/")
    machine.succeed(f"jq '.job = \"retry\" | .status = \"failed\" | .phase = \"publish\" | .base_commit = \"fixture\" | .expected_branch = \"\"' /var/lib/agent-jobs/retry/{run_id}/result.json > /tmp/retry.json && mv /tmp/retry.json /var/lib/agent-jobs/retry/{run_id}/result.json")
    machine.fail(f"systemctl start agent-job-publish-retry@{run_id}.service")
    machine.succeed(f"jq -e '.status == \"failed\" and .error == \"invalid GitHub app private key\"' /var/lib/agent-jobs/retry/{run_id}/result.json")
    machine.succeed(f"journalctl -u agent-job-publish-retry@{run_id}.service | grep -F 'invalid GitHub app private key'")
    check_session_export("success", run_id)
    machine.succeed("test -s /var/lib/prometheus-node-exporter-text-files/agent-jobs.prom")
    machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/jobs/success/runs/{run_id} | jq -e '.nix_store_seed_bytes > 0 and .nix_store_seed_bytes <= 2147483648 and .nix_store_setup_duration_seconds > 0'")
    machine.succeed(r"""curl -fsS http://127.0.0.1:9100/metrics | grep -E '^agent_job_last_nix_store_seed_bytes\{agent_job="success"\} [1-9][0-9]*$'""")
    machine.succeed("""curl -fsS http://127.0.0.1:9100/metrics | grep -Fx 'agent_job_nix_store_limit_bytes{agent_job="success"} 2147483648'""")
    machine.succeed("""curl -fsS http://127.0.0.1:9100/metrics | grep -Fx 'agent_job_sandbox_memory_limit_bytes{agent_job="success"} 2147483648'""")
    machine.succeed("curl -fsS http://127.0.0.1:9100/metrics | grep agent_job_last_duration_seconds")
    machine.succeed("""curl -fsS http://127.0.0.1:9100/metrics | grep -Fx 'agent_job_schedule_enabled{agent_job="success"} 1'""")
    machine.succeed("""curl -fsS http://127.0.0.1:9100/metrics | grep -Fx 'agent_job_schedule_enabled{agent_job="security"} 0'""")
    start_job("security")
    start_job("arbitrary-path")
    for name in ["failure", "timeout", "symlink"]:
        machine.fail(f"systemctl start agent-job-{name}.service")
        machine.succeed(f"find /var/lib/agent-jobs/{name} -name result.json | grep .")
    for name, status in [("failure", "failed"), ("timeout", "timed_out")]:
        run_id = machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/runs?job={name} | jq -er '.[0] | select(.status == \"{status}\") | .id'").strip()
        machine.succeed(f"curl -fsS http://127.0.0.1:8788/api/jobs/{name}/runs/{run_id}/sessions | jq -e 'length == 1'")
        check_session_export(name, run_id)
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
