---
name: Age Secrets
description: Use whenever reading, creating, editing, writing, rekeying, or debugging age/agenix secret files in this repository.
---

# Age Secrets

Use `agenix`; do not hand-edit ciphertext or expose plaintext in chat, logs, shell history, or the repository.

## Workflow

1. Work from the directory containing the applicable `secrets.nix` (for example, `cd hosts/cumserver`). Paths passed to `agenix` must match keys such as `secrets/marzbanMetricsEnv` in that file.
2. Use the explicit local identity when needed: `-i "$HOME/.ssh/id_ed25519"`.
3. Read without displaying values:
   ```sh
   umask 077
   tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
   agenix -d secrets/NAME -i "$HOME/.ssh/id_ed25519" > "$tmp"
   # Inspect $tmp locally; report only redacted names or validation results.
   ```
4. Edit interactively with `EDITOR="$EDITOR" agenix -e secrets/NAME -i "$HOME/.ssh/id_ed25519"`.
5. For an exact/scripted write, prepare a mode-600 plaintext file, check it, then run `agenix -e secrets/NAME -i "$HOME/.ssh/id_ed25519" < "$tmp"`. Never pipe a fallible producer directly into this command; an empty producer can replace the secret.
6. Verify by decrypting again and comparing or validating the plaintext without printing it. Ciphertext changing is expected because age encryption is nondeterministic.

## Add or Change Secrets

- Add `"secrets/NAME".publicKeys = ...;` to the owning `secrets.nix` first, then create it with `agenix -e secrets/NAME ...` (or validated stdin).
- Declare its runtime use separately with `age.secrets.NAME.file = ./secrets/NAME;`; consume `config.age.secrets.NAME.path`, never plaintext in Nix.
- After changing recipients, run `agenix -r -i "$HOME/.ssh/id_ed25519"` from the rules directory and verify a representative decrypt.
- Review `git status`; commit only encrypted files, rules, and runtime declarations. Remove every plaintext temp file.
