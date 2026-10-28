let
  scheduleDefaults = {
    timezone = "UTC";
    provider = "pi";
    model = "cumserver/gpt-6.1-sol";
    thinkingOptionId = "low";
    cwd = "/home/paseo/projects/dotfiles";
    archiveOnFinish = true;
    isolation = "local";
  };

  packageUpdate =
    {
      name,
      cron,
      branch,
      title,
      scope,
    }:
    scheduleDefaults
    // {
      inherit name cron;
      prompt = ''
        Maintain the scoped packages in sleroq/dotfiles. This recurring task is authorized to commit, push, force-push its own automation branch, and create/update a pull request. Do not merge or deploy.

        Repository: /home/paseo/projects/dotfiles on div, running as paseo. Fetch origin and discover the remote default branch before doing any work; the shared checkout can be stale. Read the current repository instructions and package configuration from the fetched base. Work in a dedicated clean git worktree, never modifying the shared checkout, unrelated work, or someone else's branch. Use the stable branch ${branch} and reconstruct the proposed update on the latest remote default branch each run.

        Scope:
        ${scope}

        Use published upstream releases and compatible pins, not invented versions. Read the actual package consumers and overrides before changing pins; paths may evolve. Update matching source and dependency hashes together. Do not change unrelated packages, model choices, prompts, skills, service settings, or runtime bookkeeping. Do not update any flake input or flake.lock unless explicitly permitted in the scope above. Any permitted flake update MUST be targeted, never a blanket nix flake update; compare the lock graph against the base and undo incidental churn. Leave every root nixpkgs input and unrelated flake root and its independent dependency locks exactly unchanged. If an upgrade requires unrelated changes, leave that upgrade out and report the blocker.

        Validation must stay small: format/lint changed files, run focused affected tests and narrow package evaluation or package-only builds. NEVER build/rebuild/test entire NixOS, Darwin, or Home Manager host configurations; NEVER run nix flake check or any all-host/all-package build, even with --no-build. Do not deploy or activate anything. Honor repository build-host rules: never build Linux packages on Darwin or build anything on ru-relay/warsaw. After edits, run the required shared ast-grep scan from the worktree root: ast-grep scan --config "$HOME/sgconfig.yml" --no-ignore hidden .; understand findings, fix newly introduced issues, and report unrelated pre-existing blockers without broad cleanup. Follow the Nix skill checks for edited Nix files. These restrictions apply to every delegated agent too; explicitly pass them on.

        Publication: query GitHub for an OPEN PR from ${branch} before creating anything. If one exists, keep its number/URL and update its branch with git push --force-with-lease (not an unconditional force push); never create a duplicate. Reconstruct the complete candidate update against the latest base, preserving outstanding upgrades within this job's scope rather than accidentally discarding them. Compare with the existing remote branch so an identical result does not produce another commit/push. If no open PR exists (the last was merged or closed), create a new PR only when the candidate has an actual scoped diff versus the current default branch. If there is no actual update, do not commit/push or create a PR; leave any existing PR alone and report no change. Never create empty commits or force-push any other branch. Use title "${title}" and a SUPER SHORT PR body: one sentence, at most two short lines, summarizing the package updates. Keep check details in the agent's final report, not the PR body. Update the existing PR's title/body to this format when publishing new changes. Report the PR URL, concise changed versions, and any validation limitations. If blocked, report honestly rather than claiming success or expanding scope.
      '';
    };
in
{
  bump-paseo-stack = scheduleDefaults // {
    adoptId = "1c817bdf";
    name = "Dotfiles: bump Paseo stack";
    cron = "0 6 */3 * *";
    prompt = ''
      Maintain the Paseo stack in sleroq/dotfiles. This recurring task is explicitly authorized by the user to commit, push, force-push its own automation branch, and create/update a pull request. Do not merge or deploy.

      Repository: /home/paseo/projects/dotfiles on div, running as paseo. Fetch origin and discover the remote default branch before doing any work; the shared checkout can be stale. Read the current repository instructions and stack configuration from the fetched base. Work in a dedicated clean git worktree, never modifying the shared checkout, unrelated work, or someone else's branch. Use the stable branch automation/bump-paseo-stack and reconstruct the proposed update on the latest remote default branch each run.

      Scope: update the complete Paseo and agent/LLM-serving stack to current upstream releases/revisions, including supporting packages hosted separately from Paseo. This job owns Paseo daemon and desktop, Pi, Codex/OpenCode and other configured agent runtimes, pi-subagents and all other configured Pi/OpenCode extension and plugin package versions, CLIProxyAPI on cumserver, its opencode-go-cliproxyapi native plugin and any other configured LLM gateway/provider adapters, and dedicated related flake inputs. Rift and Paseo relay belong exclusively to the weekly maintained-packages schedule; do not update their package pins here.

      Inventory the actual configured stack and trace each component to its owning pin on every run; this is not a closed list, and updating the main Paseo package or llm-agents input alone is not sufficient. Inspect modules/paseo*, home/modules/programs/{paseo,pi,opencode}.nix, Pi/OpenCode settings and extension/plugin manifests and lockfiles, hosts/cumserver/modules/cli-proxy-api.nix, hosts/cumserver/modules/CLIProxyAPI.md, packages/opencode-go-cliproxyapi.nix, and relevant overlays; paths may evolve. Use published versions and compatible pins, not invented versions. Update matching versions, source/dependency hashes and package lockfiles together. Check CLIProxyAPI and its native plugins as a compatible set, preserve local patches and integration behavior, and update version-specific documentation when needed. Do not change credentials, OAuth state, API exposure, provider/model choices, prompts, skills, or unrelated development tools. Limit service/configuration changes to those strictly required for upgrade compatibility, preserving existing access boundaries. Do not update runtime bookkeeping such as lastChangelogVersion. If a component is blocked, leave its incompatible upgrade out, report the blocker, and continue with independently compatible updates. Report each scoped component as updated, already current, or blocked so supporting packages cannot be silently skipped.

      Flake updates MUST be targeted, never a blanket nix flake update. Expected allowed root inputs are pi, llm-agents, llm-agents-paseo, and any dedicated Paseo/agent/LLM-gateway input actually present on the latest base, plus their necessary transitive dependencies. Follow the actual package consumers rather than assuming an input supplies Paseo; the current daemon comes from llm-agents-paseo, while desktop, Codex/OpenCode and CLIProxyAPI come from llm-agents, and Pi comes from pi. Leave every root nixpkgs input exactly unchanged, including nixpkgs, nixpkgs-master, nixpkgs-div, nixpkgs-cumserver, nixpkgs-interplanetary, nixpkgs-portable, nixpkgs-roundy and any future host pins. Leave unrelated flake roots and their independent dependency locks unchanged. Compare the lock graph against the base to verify this before publishing; undo incidental churn. If an upgrade requires unrelated host nixpkgs changes, leave that upgrade out and report the blocker.

      Validation must stay small: format/lint changed files, run focused affected tests and narrow package evaluation or a package-only build if necessary. NEVER build/rebuild/test entire NixOS, Darwin, or Home Manager host configurations; NEVER run nix flake check or any all-host/all-package build, even with --no-build. Do not deploy or activate anything. Honor repository build-host rules for any narrow build. After edits, run the required shared ast-grep scan from the worktree root: ast-grep scan --config "$HOME/sgconfig.yml" --no-ignore hidden .; understand findings, fix newly introduced issues, and report unrelated pre-existing blockers without broad cleanup. Follow the Nix skill checks for edited Nix files. These restrictions apply to every delegated agent too; explicitly pass them on.

      Publication: query GitHub for an OPEN PR from automation/bump-paseo-stack before creating anything. If one exists, keep its number/URL and update its branch with git push --force-with-lease (not an unconditional force push); never create a duplicate. Reconstruct the complete candidate update against the latest base, preserving the outstanding upgrade scope rather than accidentally discarding it. Compare with the existing remote branch so an identical result does not produce another commit/push. If no open PR exists (the last was merged or closed), create a new PR only when the candidate has an actual stack diff versus the current default branch. If there is no actual update, do not commit/push or create a PR; leave any existing PR alone and report no change. Never create empty commits or force-push any other branch. Use title "chore: update Paseo stack" and a SUPER SHORT PR body: one sentence, at most two short lines, e.g. "Update Paseo, agents, and related dependencies." Keep check details in the agent's final report, not the PR body. Update the existing PR's title/body to this format when publishing new changes. Report the PR URL, concise changed versions, and any validation limitations. If blocked, report honestly rather than claiming success or expanding scope.
    '';
  };

  bump-helium = packageUpdate {
    name = "Dotfiles: bump Helium";
    cron = "0 7 * * *";
    branch = "automation/bump-helium";
    title = "chore: update Helium";
    scope = ''
      Update only Helium in packages/helium.nix to the latest stable upstream Linux release from imputnet/helium-linux. Update the version and matching x86_64 AppImage hash together. Verify the release asset exists and run a focused package evaluation/build on a capable Linux host. Do not change flake inputs, browser settings, or unrelated packages.
    '';
  };

  bump-dwl = packageUpdate {
    name = "Dotfiles: bump DWL";
    cron = "0 9 1 * *";
    branch = "automation/bump-dwl";
    title = "chore: update DWL";
    scope = ''
      Update the dwl flake input to the latest stable upstream release, with only its necessary lock node changes. Inspect flake.nix, packages/dwl/default.nix, packages/dwl/README.md, local patches/configuration, and compositor consumers. Port the existing patches only as required for compatibility; preserve desktop behavior, keybindings, IPC, and local features. Do not change other flake inputs, the wlroots/nixpkgs pins, or the Noctalia shell.

      Build only the patched DWL package and run the focused boundary/regression tests documented in packages/dwl/README.md on a capable Linux host. Update the documented supported DWL revision when it changes. If the release requires a different wlroots/nixpkgs pin, a feature redesign, or tests cannot validate a patch port, leave the unsupported upgrade out and report the blocker; do not submit an unverified compositor port.
    '';
  };

  bump-maintained-packages = packageUpdate {
    name = "Dotfiles: bump maintained packages";
    cron = "0 8 * * 0";
    branch = "automation/bump-maintained-packages";
    title = "chore: update maintained packages";
    scope = ''
      Update only TrustTunnel client, OBS MoQ, Broadcast Box, the Svelte tree-sitter parser, Rift, and Paseo relay to current upstream releases/revisions. This job exclusively owns Rift and Paseo relay package updates; the Paseo stack job must not update those pins. Helium, DWL, proxy-helper, and all other packages are out of scope.

      - TrustTunnel: packages/trusttunnel-client.nix; update the version and hashes for every supported platform, keeping the macOS universal asset hashes consistent.
      - OBS MoQ: packages/obs-moq.nix; update the matching source tag and libmoq release binary together, including both hashes. Check OBS/plugin compatibility with a focused Linux package build.
      - Broadcast Box: packages/broadcast-box.nix; update the upstream source revision and Go/npm dependency hashes together. Inspect host overrides in hosts/cumserver/default.nix and hosts/ru-relay/default.nix. Preserve intentionally distinct fork/revision pins and their behavior; do not replace them with the default upstream pin. If a default change requires dependency-hash adjustments for an existing override, validate that pinned variant too or leave the Broadcast Box upgrade out. Do not build on ru-relay.
      - Svelte tree-sitter parser: the pin in home/config/ast-grep/svelte-parser.json and its consumer packages/tree-sitter-htmlx-svelte.nix; keep the shared parser metadata consistent, preserve the scanner compiler fix, run its install checks and the shared ast-grep scan with the newly built parser actually loaded.
      - Rift: packages/rift.nix; update the version and release hashes for every supported platform. Preserve Paseo integration.
      - Paseo relay: packages/paseo-relay.nix; update the source revision/version/hash and mixFodDeps hash together. Preserve compatibility with the configured Paseo stack; do not update Paseo or its flake inputs here.

      Use a published stable release where available; for packages intentionally tracking unreleased upstream revisions, retain that policy and use a real upstream commit. Do not update any flake input or lock file. Run focused affected package builds/tests where needed; validate supported-platform source hashes without pretending unbuilt platforms were tested. If one package is blocked, leave it unchanged, report the blocker, and continue with independently validated updates.
    '';
  };
}
