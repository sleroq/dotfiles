---
name: attic-cache-integration
description: Integrate a cloned Nix project with the self-hosted Attic cache on cumserver.
disable-model-invocation: true
---

# Attic cache integration

Use this only when given an absolute path to a cloned project. It is stored outside OpenCode's skill directories intentionally; do not register or copy it into `.opencode/skills` or `home/config/agents/skills`.

## Existing infrastructure

- API: `https://cache.cum.army/`
- SSH host: `cumserver`
- NixOS module: `hosts/cumserver/modules/attic.nix`
- Attic uses public per-project caches, local storage, GC every 12 hours, and 30-day retention. It has no byte quota.

## Integrate a project

1. Inspect the supplied repository's default branch, flake outputs, module package option, existing Actions style, and GitHub remote. Use the repository name as the lowercase Attic cache name unless it is unsuitable.
2. Make the project's module consume its exported package, normally:
   ```nix
   default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
   ```
   Building again with the consuming host's `pkgs` creates a different derivation and defeats the cache.
3. In `dotfiles/flake.nix`, remove `<project>.inputs.nixpkgs.follows = "nixpkgs-cumserver";`. Regenerate `flake.lock` with plain `nix flake lock`. After the project PR merges, update that input.
4. Create a public cache using a short-lived setup token. Keep tokens in mode-0600 temporary files and never print them:
   ```sh
   ssh cumserver 'atticd-atticadm make-token --sub setup --validity "10 minutes" --create-cache CACHE --configure-cache CACHE' > "$token_file"
   attic login admin https://cache.cum.army/ "$(cat "$token_file")"
   attic cache create CACHE --public
   attic cache info CACHE
   ```
5. Add the reported endpoint and public key to `nix.settings.extra-substituters` and `nix.settings.extra-trusted-public-keys` in `hosts/cumserver/modules/attic.nix`.
6. Generate a push-only token and save it directly as the project's Actions secret:
   ```sh
   ssh cumserver 'atticd-atticadm make-token --sub github-actions --validity "1 year" --push CACHE' > "$token_file"
   gh secret set ATTIC_TOKEN --repo OWNER/REPO < "$token_file"
   ```
7. Add a workflow following Reactor's canonical example at `/Users/sleroq/develop/reactor/.github/workflows/cache.yml`. Build the exact `packages.x86_64-linux` output first, then install `attic-client`, login with `${{ secrets.ATTIC_TOKEN }}`, and run `attic push CACHE BUILD_PATH`. Trigger pushes to the actual default branch, all tags, and `workflow_dispatch`. Pin actions by full commit SHA.
8. Open a project PR. Do not merge it unless asked.

## Verify

- Format changed Nix files and run `nix flake check --no-build` in the project.
- Evaluate the cumserver configuration, deploy it, and confirm `nix config show substituters` and `trusted-public-keys` contain the new cache.
- Confirm `curl -f https://cache.cum.army/CACHE/nix-cache-info` and `nix store ping --store https://cache.cum.army/CACHE` succeed.
- Compare the project's exported package derivation with the package selected by its cumserver service after the project PR is merged and the dotfiles input is updated.
- Run the repository-root ast-grep scan required by `AGENTS.md`.
