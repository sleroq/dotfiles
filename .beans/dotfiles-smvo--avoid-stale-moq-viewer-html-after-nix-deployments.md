---
# dotfiles-smvo
title: Avoid stale MoQ viewer HTML after Nix deployments
status: completed
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-10-02T22:09:00Z
updated_at: 2026-10-02T22:16:27Z
---

Browser reload retained the original index-Rqb6zYu-.js while production index.html references index-Cq1Ahlj2.js. Nix store files have the fixed Last-Modified value 1970-01-01T00:00:01Z, so HTML conditional revalidation cannot distinguish releases. Serve HTML with Cache-Control: no-store and discard If-Modified-Since for HTML requests; leave hashed assets cacheable. Verify a conditional HTML request returns the current body and browser reload runs the latest bundle.

Production conditional HTML requests now return HTTP 200 with Cache-Control: no-store instead of the previously observed HTTP 304. Latest compiled bundle is served; hashed assets remain cacheable.
