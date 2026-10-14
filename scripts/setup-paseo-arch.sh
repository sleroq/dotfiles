#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ ${1:-} != --skip-packages ]]; then
  paru -S --needed paseo-bin pi-coding-agent-bin openai-codex-bin bun-bin direnv git ripgrep ast-grep age
fi
if [[ ! -x "$HOME/.bun/bin/opencode" ]] && ! command -v opencode >/dev/null; then
  paru -S --needed opencode
fi

install -d -m 0700 "$HOME/.config/pi"
(
  umask 077
  exa_tmp=$(mktemp "$HOME/.config/pi/exa.env.XXXXXX")
  trap 'rm -f "$exa_tmp"' EXIT
  age --decrypt -i "$HOME/.ssh/id_ed25519" "$root/shared/secrets/exa-env" >"$exa_tmp"
  mv "$exa_tmp" "$HOME/.config/pi/exa.env"
)
exa_shell_line='if [ -r "$HOME/.config/pi/exa.env" ]; then . "$HOME/.config/pi/exa.env"; export EXA_API_KEY; fi'
for shell_config in "$HOME/.zshenv" "$HOME/.profile"; do
  if ! grep -Fqx "$exa_shell_line" "$shell_config" 2>/dev/null; then
    printf '\n%s\n' "$exa_shell_line" >>"$shell_config"
  fi
done

install -d -m 0700 "$HOME/.paseo"
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user" "$HOME/develop"
install -m 0755 "$root/modules/paseo/arch/pi-direnv" "$HOME/.local/bin/pi-direnv"
install -m 0755 "$root/modules/paseo/arch/paseo" "$HOME/.local/bin/paseo"
install -m 0644 "$root/modules/paseo/arch/paseo-node.service" "$HOME/.config/systemd/user/paseo-node.service"

bun run - "$root/modules/paseo/arch/config.json" "$root/home/config/paseo/config.json" "$root/modules/paseo/config.mjs" <<'TS'
import { chmodSync, copyFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const home = homedir();
const target = join(home, ".paseo/config.json");
if (existsSync(target)) {
  const backup = join(home, ".paseo/backups", new Date().toISOString());
  mkdirSync(backup, { recursive: true, mode: 0o700 });
  copyFileSync(target, join(backup, "config.json"));
  chmodSync(join(backup, "config.json"), 0o600);
}

const { mergeConfig, writeConfig } = await import(process.argv[4]);
const shared = JSON.parse(readFileSync(process.argv[3], "utf8"));
const config = JSON.parse(readFileSync(process.argv[2], "utf8").replaceAll("@HOME@", home));
if (!existsSync(join(home, ".bun/bin/opencode"))) {
  config.agents.providers.opencode.command = ["/usr/bin/opencode"];
}
await writeConfig(mergeConfig(shared, config), target);
TS

if [[ ! -f "$HOME/.pi/agent/.profile-deployment.json" ]]; then
  printf 'Deploy the shared profile before starting: bun scripts/deploy-pi-profile.ts work\n' >&2
  exit 1
fi

sudo loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable --now paseo-node.service
systemctl --user is-active paseo-node.service
