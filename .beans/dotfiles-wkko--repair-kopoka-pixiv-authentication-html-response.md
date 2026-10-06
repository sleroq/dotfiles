---
# dotfiles-wkko
title: Repair Kopoka Pixiv authentication HTML response
status: scrapped
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-09-30T00:25:08Z
updated_at: 2026-09-30T11:24:44Z
---

cumserver Kopoka authenticates Telegram successfully but Pixiv refresh-token authentication returns non-JSON (invalid character <), panicking at src/main.go:210. Reproduced before and after nixpkgs deployment. Investigate HTTP status/content type, everpcpc/pixiv endpoint and challenge/network behavior without exposing tokens. No evidenced Nix-only fix. Service remains in auto-restart after successful activation of other services.
