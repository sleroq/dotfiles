---
name: agent-browser
description: Use agent-browser for browser automation, navigating websites, interacting with forms, taking screenshots, extracting data, testing web apps, exploratory QA, or automating Electron apps.
---

# agent-browser

Use the Nix-installed `agent-browser` CLI for browser automation. Before using it, read the workflow and command reference matching the installed version:

```bash
agent-browser skills get core
```

For the complete reference, run `agent-browser skills get core --full`. For specialized workflows (Electron apps, exploratory testing, Slack, or cloud browsers), run `agent-browser skills list` and then `agent-browser skills get <name>`.

The CLI requires a Chrome/Chromium browser. Do not install or upgrade the CLI with npm, npx, or `agent-browser upgrade`; its version is managed by Nix in this repository.
