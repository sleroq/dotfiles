---
# dotfiles-x4uf
title: Do not count MoQ audio warmup as packet loss
status: completed
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-10-02T21:54:22Z
updated_at: 2026-10-02T22:14:48Z
---

Live playback verification exposed Auto raising its target from 500 to 750 ms immediately after unmuting an already-playing video. The new audio ring is warming up, not proving transport loss. Reset adaptation health (without lowering the configured delay) when the upstream emitter becomes enabled, then verify startup grace and real audio/video playback.

Verified the latest production bundle in a fresh browser: Auto remained at 500 ms while unmuting, the audio ring filled, and shared-buffer audio ran. Typecheck, production build, and all six tests passed.
