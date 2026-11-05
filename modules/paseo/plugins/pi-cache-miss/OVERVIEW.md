# Pi cache misses

Adds a warning to the agent timeline when a Pi request reads substantially fewer cached prompt tokens than the preceding request had cached. Each warning shows the cached-token drop, current cache-hit percentage, and model. Requests are checked individually, so later hits do not hide an earlier miss in the same turn.

Requires Paseo 0.15.1 or later on the daemon and app, and Pi session format v3. The shared Paseo Nix configuration registers this local plugin, just like `worktree-direnv`.

## Detection

After each observed turn finishes, including failure or cancellation, the plugin reads the exact Pi session file reported by Paseo. It follows the active branch and compares requests using the same API, provider, and model. A warning requires both a drop of at least 1,024 cached tokens and retention below 80% of the preceding request's cached tokens (`cacheRead + cacheWrite`). Large new uncached prompts alone do not trigger warnings. First requests, models without reported caching, unsuccessful requests, and the first request after a model change, compaction, branch summary, or context edit do not trigger warnings.

This is a heuristic, not a provider-reported cache-miss event. Expiry, eviction, prompt changes, and provider routing can all produce the same warning. Losses smaller than the thresholds are intentionally ignored. Detection requires a preceding request with reported cached tokens; cold sessions with no caching reported cannot be classified.

## Data and lifetime

The plugin reads the session transcript locally but only adds token counts and model names to Paseo. It does not modify Pi sessions, send prompts to the agent, or make external network requests. As with every Paseo plugin, it is trusted, unsandboxed code.

Warnings appear after the turn, not while requests stream. Turns already running when the plugin starts are not inspected. There is no history backfill. Stable session-entry IDs prevent duplicate warnings when the same request is inspected again. Paseo's plugin timeline rows are in memory and disappear on daemon restart.

