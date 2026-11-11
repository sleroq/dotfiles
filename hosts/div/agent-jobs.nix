{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  jobs = {
    bump-helium = {
      schedule = "*-*-* 07:00:00 UTC";
      overdueAfterSeconds = 90000;
      allowedPaths = [ "packages/helium.nix" ];
      prompt = ''
        Update only Helium in packages/helium.nix to the latest stable upstream Linux release from imputnet/helium-linux. Update the version and matching x86_64 AppImage hash together. Verify the release asset exists and run a focused package evaluation/build using lock.nodes.nixpkgs-div.locked, matching trusted validation; do not fetch a second nixpkgs revision. Do not change flake inputs, browser settings, or unrelated packages.
      '';
      validation = [
        [
          "nix"
          "build"
          "--no-link"
          "--impure"
          "--expr"
          ''
            let
              lock = builtins.fromJSON (builtins.readFile ./flake.lock);
              source = builtins.fetchTree lock.nodes.nixpkgs-div.locked;
              pkgs = import source { system = "x86_64-linux"; };
            in pkgs.callPackage ./packages/helium.nix { }
          ''
        ]
      ];
      publish = {
        title = "chore: update Helium";
      };
    };
    bump-paseo-stack = {
      schedule = "*-*-1/3 06:00:00 UTC";
      overdueAfterSeconds = 262800;
      allowedPaths = [
        "flake.nix"
        "flake.lock"
        "modules/paseo.nix"
        "modules/paseo/packages.nix"
        "modules/paseo/pi.nix"
        "modules/paseo/opencode.nix"
        "modules/paseo/config.nix"
        "modules/paseo/config.mjs"
        "modules/paseo/pi-profile.mjs"
        "modules/paseo/plugins/pi-cache-miss/package.json"
        "modules/paseo/plugins/pi-cache-miss/package-lock.json"
        "modules/paseo/plugins/pi-fast/package.json"
        "modules/paseo/plugins/pi-fast/package-lock.json"
        "modules/paseo/plugins/worktree-direnv/package.json"
        "modules/paseo/plugins/worktree-direnv/package-lock.json"
        "home/modules/programs/paseo.nix"
        "home/modules/programs/pi.nix"
        "home/modules/programs/opencode.nix"
        "home/config/pi/agent/settings.json"
        "home/config/opencode/opencode.json"
        "home/config/opencode/plugins/direnv/package.json"
        "home/config/opencode/plugins/direnv/bun.lock"
        "home/config/opencode/plugins/paseo-managed-bridge/package.json"
        "hosts/cumserver/modules/fumo-gateway.nix"
        "packages/fumo-pi.nix"
        "packages/fumo-pi-refresh.mjs"
      ];
      prompt = builtins.readFile ./agent-jobs/bump-paseo-stack.txt;
      validation = [
        [
          "jq"
          "--exit-status"
          ".nodes.root.inputs | has(\"pi\") and has(\"llm-agents\") and has(\"fumo-gateway\")"
          "flake.lock"
        ]
      ];
      publish = {
        title = "chore: update Paseo stack";
      };
    };
    bump-dwl = {
      schedule = "*-*-01 09:00:00 UTC";
      overdueAfterSeconds = 2682000;
      allowedPaths = [
        "flake.nix"
        "flake.lock"
        "packages/dwl/default.nix"
        "packages/dwl/README.md"
        "packages/dwl/config.h"
        "packages/dwl/patches/ipc.patch"
        "packages/dwl/patches/desktop.patch"
        "packages/dwl/patches/better-resize.patch"
        "packages/dwl/patches/gpu-reset.patch"
        "packages/dwl/tests/boundaries.c"
        "packages/dwl/tests/run.sh"
        "packages/dwl/tests/noctalia.py"
        "packages/dwl/tests/resize.py"
        "packages/dwl/tests/transitions.py"
        "packages/dwl/tests/transient.c"
        "packages/dwl/tests/drag.c"
        "packages/dwl/tests/ipc-title.c"
        "packages/dwl/tests/dwl-ipc-unstable-v2.xml"
        "packages/dwl/tests/virtual-pointer.xml"
      ];
      prompt = builtins.readFile ./agent-jobs/bump-dwl.txt;
      validation = [
        [
          "nix"
          "build"
          "--no-link"
          "--impure"
          "--expr"
          ''
            let
              lock = builtins.fromJSON (builtins.readFile ./flake.lock);
              pkgs = import (builtins.fetchTree lock.nodes.nixpkgs-interplanetary.locked) { system = "x86_64-linux"; };
              dwl = pkgs.callPackage ./packages/dwl {
                src = builtins.fetchTree lock.nodes.dwl.locked;
              };
            in dwl.overrideAttrs {
              doCheck = true;
              checkPhase = "runHook preCheck\nbash ''${./packages/dwl/tests}/run.sh \"$PWD\"\nrunHook postCheck";
            }
          ''
        ]
      ];
      publish = {
        title = "chore: update DWL";
      };
    };
    bump-maintained-packages = {
      schedule = "Sun *-*-* 08:00:00 UTC";
      overdueAfterSeconds = 608400;
      allowedPaths = [
        "packages/trusttunnel-client.nix"
        "packages/obs-moq.nix"
        "packages/broadcast-box.nix"
        "packages/tree-sitter-htmlx-svelte.nix"
        "home/config/ast-grep/svelte-parser.json"
        "packages/rift.nix"
        "packages/paseo-relay.nix"
        "hosts/cumserver/default.nix"
        "hosts/ru-relay/default.nix"
      ];
      prompt = builtins.readFile ./agent-jobs/bump-maintained-packages.txt;
      validation = [
        [
          "nix"
          "build"
          "--no-link"
          "--impure"
          "--expr"
          ''
            let
              lock = builtins.fromJSON (builtins.readFile ./flake.lock);
              pkgs = import (builtins.fetchTree lock.nodes.nixpkgs-cumserver.locked) { system = "x86_64-linux"; };
            in map (file: pkgs.callPackage file { }) [
              ./packages/trusttunnel-client.nix
              ./packages/obs-moq.nix
              ./packages/broadcast-box.nix
              ./packages/tree-sitter-htmlx-svelte.nix
              ./packages/rift.nix
              ./packages/paseo-relay.nix
            ]
          ''
        ]
      ];
      publish = {
        title = "chore: update maintained packages";
      };
    };
  };
in
{
  imports = [ ../../modules/agent-jobs.nix ];

  age.secrets.agentJobsGithubKey.file = ./secrets/agentJobsGithubKey;
  age.secrets.agentJobsFumoKey.file = ./secrets/agentJobsFumoKey;
  systemd.timers = lib.mapAttrs' (
    name: _: lib.nameValuePair "agent-job-${name}" { enable = false; }
  ) jobs;

  services.agent-jobs = {
    enable = true;
    viewer.port = 8788;
    image = pkgs.callPackage ../../packages/agent-sandbox.nix {
      agent-jobs = config.services.agent-jobs.package;
      pi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default;
      fumo-pi = pkgs.callPackage ../../packages/fumo-pi.nix {
        pi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default;
        source = inputs.fumo-gateway;
      };
    };
    jobs = lib.mapAttrs (
      name: job:
      let
        nixFiles = builtins.filter (lib.hasSuffix ".nix") job.allowedPaths;
      in
      job
      // {
        enable = true;
        repository = "sleroq/dotfiles";
        branch = "automation/${name}";
        environmentFiles.FUMO_PI_KEY = config.age.secrets.agentJobsFumoKey.path;
        piCommand = [ "agent-pi" ];
        model = "fumo/codex/gpt-6.1-terra";
        thinking = "high";
        memoryMB = 8192;
        workspaceMB = 6144;
        prompt = ''
          Maintain the scoped packages in sleroq/dotfiles in this fresh isolated /workspace checkout. Read repository instructions and the actual package consumers before editing. The trusted host checked out the remote default branch; do not access another checkout, SSH host, personal credentials, or the host Nix daemon/store.

          ${job.prompt}

          Edit only these permitted paths:
          ${lib.concatStringsSep "\n" job.allowedPaths}

          Use published upstream releases/revisions and update matching source/dependency hashes together. Preserve existing integrations and local patches. Do not change credentials, provider/model choices, prompts, skills, runtime bookkeeping, or unrelated packages/configuration. Never edit Paseo-managed built-in skills. Any permitted flake update must be targeted, never a blanket update: preserve every root nixpkgs pin, unrelated root and its independent dependency locks, and compare the lock graph against the initial Git HEAD before finishing. If a component needs an out-of-scope change, leave that upgrade out and report the blocker.

          Validation must remain package-scoped. Use Nix to obtain any needed build/test tools inside this private sandbox. Never evaluate/build/test complete NixOS, Darwin or Home Manager configurations; never run nix flake check or an all-host/all-package build, even with --no-build. Do not deploy or activate anything. Run focused affected package tests/builds as required by the scope, format/lint edited Nix files, and run ast-grep scan --config "$HOME/sgconfig.yml" --no-ignore hidden . from the checkout root. Understand findings, fix introduced issues and report unrelated pre-existing blockers without broad cleanup. Never claim an unbuilt platform or unrun test was verified.

          Do not commit, push, force-push, create/modify PRs, or merge. The trusted publisher owns the stable automation/${name} branch and reuses its open PR. Report updated/current/blocked status for every scoped component and any validation limitations. No changes is a valid result when everything is current.
        '';
        validation = [
          (
            [
              "nixfmt"
              "--check"
            ]
            ++ nixFiles
          )
          (
            [
              "deadnix"
              "--fail"
            ]
            ++ nixFiles
          )
        ]
        ++ map (file: [
          "nixf-tidy"
          "--variable-lookup"
          "--file"
          file
        ]) nixFiles
        ++ [
          [
            "ast-grep"
            "scan"
            "--config"
            "/home/agent/sgconfig.yml"
            "--no-ignore"
            "hidden"
            "."
          ]
        ]
        ++ job.validation;
        publish = job.publish // {
          enabled = true;
          appID = "5677761";
          installationID = "180883592";
          privateKeyFile = config.age.secrets.agentJobsGithubKey.path;
          reviewer = "sleroq";
        };
      }
    ) jobs;
  };
}
