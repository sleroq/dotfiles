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
      prompt = ''
        Update Helium in packages/helium.nix to the latest stable upstream Linux release from imputnet/helium-linux, including any necessary supporting repository changes. Update the version and matching x86_64 AppImage hash together. Verify the release asset exists and run a focused package evaluation/build using lock.nodes.nixpkgs-div.locked; do not fetch a second nixpkgs revision. Do not change flake inputs, browser settings, or unrelated packages.
      '';
      publish = {
        title = "chore: update Helium";
      };
    };
    bump-paseo-stack = {
      schedule = "*-*-1/3 06:00:00 UTC";
      overdueAfterSeconds = 262800;
      prompt = builtins.readFile ./agent-jobs/bump-paseo-stack.txt;
      publish = {
        title = "chore: update Paseo stack";
      };
    };
    bump-dwl = {
      schedule = "*-*-01 09:00:00 UTC";
      overdueAfterSeconds = 2682000;
      prompt = builtins.readFile ./agent-jobs/bump-dwl.txt;
      publish = {
        title = "chore: update DWL";
      };
    };
    bump-maintained-packages = {
      schedule = "Sun *-*-* 08:00:00 UTC";
      overdueAfterSeconds = 608400;
      prompt = builtins.readFile ./agent-jobs/bump-maintained-packages.txt;
      publish = {
        title = "chore: update maintained packages";
      };
    };
    bump-container-images = {
      schedule = "Sun *-*-* 10:00:00 UTC";
      overdueAfterSeconds = 608400;
      prompt = builtins.readFile ./agent-jobs/bump-container-images.txt;
      publish = {
        title = "chore: update container images";
      };
    };
  };
in
{
  imports = [ ../../modules/agent-jobs.nix ];

  age.secrets.agentJobsGithubKey.file = ./secrets/agentJobsGithubKey;
  age.secrets.agentJobsFumoKey.file = ./secrets/agentJobsFumoKey;
  services.agent-jobs = {
    enable = true;
    viewer.port = 8788;
    proxy.keyFile = config.age.secrets.agentJobsFumoKey.path;
    image = pkgs.callPackage ../../packages/agent-sandbox.nix {
      agent-jobs = config.services.agent-jobs.package;
      fumoProxy = true;
      substituters = config.nix.settings.substituters ++ (config.nix.settings.extra-substituters or [ ]);
      trustedPublicKeys =
        config.nix.settings.trusted-public-keys ++ (config.nix.settings.extra-trusted-public-keys or [ ]);
      pi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default;
      fumo-pi = pkgs.callPackage ../../packages/fumo-pi.nix {
        pi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default;
        source = inputs.fumo-gateway;
      };
    };
    jobs = lib.mapAttrs (
      name: job:
      job
      // {
        enable = true;
        repository = "sleroq/dotfiles";
        branch = "automation/${name}";
        reuseOpenPR = true;
        piCommand = [ "agent-pi" ];
        model = "fumo/codex/gpt-6.1-terra";
        thinking = "high";
        timeoutSeconds = 1800;
        memoryMB = 8192;
        workspaceMB = 6144;
        prompt = ''
          Maintain the scoped packages in sleroq/dotfiles in this fresh isolated /workspace checkout. Read repository instructions and the actual package consumers before editing. Do not access another checkout, SSH host, personal credentials, or the host Nix daemon/store.

          ${job.prompt}

          Use published upstream releases/revisions and update matching source/dependency hashes together. Preserve existing integrations and local patches. Do not change credentials, provider/model choices, prompts, skills, runtime bookkeeping, or unrelated packages/configuration. Never edit Paseo-managed built-in skills. Any permitted flake update must be targeted, never a blanket update: preserve every root nixpkgs pin, unrelated root and its independent dependency locks, and compare the lock graph against the supplied default-branch base before finishing. Make supporting repository changes needed for the scoped upgrades, but leave unrelated upgrades out.

          Validation must remain package-scoped. Use Nix to obtain any needed build/test tools inside this private sandbox. Never evaluate/build/test complete NixOS, Darwin or Home Manager configurations; never run nix flake check or an all-host/all-package build, even with --no-build. Do not deploy or activate anything. Run focused affected package tests/builds as required by the scope, format/lint edited Nix files, and run ast-grep scan --config "$HOME/sgconfig.yml" --no-ignore hidden . from the checkout root. Understand findings, fix introduced issues and report unrelated pre-existing blockers without broad cleanup. Never claim an unbuilt platform or unrun test was verified.

          Do not create commits except as needed for a local rebase; do not push, force-push, create/modify PRs, or merge. The trusted publisher owns the stable automation/${name} branch and reuses its open PR. Report updated/current/blocked status for every scoped component and any validation limitations. No changes is a valid result when everything is current.
        '';
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
