---
name: attic-cache-integration
description: Integrate a cloned Nix project with the self-hosted Attic cache on cumserver.
disable-model-invocation: true
---

# Attic cache integration

Only for a supplied absolute project path; do not register/copy this skill.
Infrastructure: `https://cache.cum.army/`, `cumserver`,
`hosts/cumserver/modules/attic.nix`.

1. Inspect the project's flake outputs, default branch and Actions conventions.
   Use its lowercase repository name as cache name unless unsuitable.
2. Consume the exported package (`self.packages.${pkgs.stdenv.hostPlatform.system}.default`),
   not a rebuild with host `pkgs`. Remove the project's `nixpkgs.follows` in dotfiles;
   regenerate `flake.lock`. The service must select the same derivation as CI.
3. Use `atticd-atticadm` on cumserver for a short-lived create/configure token.
   Create a public cache; add its reported endpoint/key to the module's
   `extra-substituters`/`extra-trusted-public-keys`. Keep tokens private and temporary.
4. Issue a push-only Actions token, save it as `ATTIC_TOKEN` via `gh secret set`,
   then remove plaintext. CI builds the exact Linux output before installing the
   client/pushing. Trigger default-branch pushes, tags and manual runs; pin actions by SHA.
5. Prepare project changes for review; no PR/publishing without approval. After merge,
   update the dotfiles input. Format/check Nix and deploy the cache configuration using
   root deployment rules. Verify effective substituters/keys, `CACHE/nix-cache-info`,
   `nix store ping`, and equality of CI/service derivations.
