---
name: nix
description: Use for any Nix implementation, review, refactor, debugging, or configuration work.
---

# Nix Work

After editing `.nix` files, format them with `nixfmt`, run `deadnix --fail` on the affected files or repository, and inspect `nixf-tidy --variable-lookup` diagnostics for each changed file. Use `deadnix --no-lambda-pattern-names` when `callPackage` injection makes lambda arguments appear unused, and never use `deadnix --edit` automatically.
