---
name: svelte5-best-practices
description: "Use for non-obvious Svelte 5 reactivity, prop ownership, effect lifecycle, SSR, snippets, keyed lists, attachments, or experimental async-Svelte pitfalls."
license: MIT
metadata:
  author: ejirocodes
  version: '2.0.0'
---

# Svelte 5: non-obvious rules

Consult the linked current Svelte docs when behaviour is version-sensitive. Do not restate basic rune syntax.

## Reactivity and ownership

- `$state` objects and arrays are deeply reactive proxies. Use `$state.raw` for large API-shaped values that are replaced, not mutated; raw state must be reassigned rather than mutated. Use `$state.snapshot(value)` before giving proxy state to an API that expects a plain value.
- `$derived` tracks only values synchronously read by its expression. Keep it side-effect free. It is lazy (push-pull), and only propagates when its result changes by identity. Use `$derived.by` for multi-statement derivations, not `$derived(() => ...)`.
- Derived values may be temporarily reassigned for optimistic UI (Svelte 5.25+); the next source change replaces the override. Do not create a second state variable just to mirror a derivation.
- Treat props as changing and derive values from them. Never mutate a prop. A child mutating a parent-owned state proxy produces an ownership warning; use a callback prop, or deliberately expose the prop with `$bindable` when shared mutation is the component contract.
- `$bindable` is opt-in and should be rare. A bound prop with a `$bindable(fallback)` fallback must receive a non-`undefined` value from its parent.

## Effects are DOM/external-system boundaries

- Prefer `$derived` for state calculations, event handlers for user actions, `{@attach ...}` for element integration, `$inspect` for debugging, and `createSubscriber` for external subscriptions. `$effect` is the remaining escape hatch.
- Effects run after DOM updates, never during SSR, and clean up before re-running and on unmount. Do not add `if (browser)` inside one.
- Dependencies are values read synchronously in the effect, including through synchronous function calls. Reads after `await`, timers, or other async callbacks are **not** tracked. Use `untrack` only to intentionally exclude a synchronous read.
- Avoid reading and writing the same state in an effect: it commonly creates loops. If unavoidable, `untrack` the read that must not subscribe. Use `$effect.pre` only when code must run before the DOM update; use `tick()` from there to observe the updated DOM.
- Effects cannot be created after an `await` or in an event handler. `$effect.root` is a manual-lifecycle escape hatch, not a routine solution.

## Component and template traps

- Prefer keyed `{#each}` for changing lists. Keys must be stable, unique identities — never indexes — or DOM/component state will be associated with the wrong item.
- Snippets declared at component top level may be passed as props; snippets that do not capture component state can be exported from a module script. A snippet is lexical: do not expect it to see the receiving component's scope.
- `bind:this` is `undefined` until mount. Read it only in an event handler or effect, never during component initialisation.
- In runes mode, use callback props for component events. If forwarding a DOM handler, preserve the caller's handler rather than overwriting it.

## SSR and async Svelte

- Do not put request/user-specific mutable state in module scope. On the server it is shared across requests; create it per component/request or pass it through context.
- `$effect` does not run on the server. Server-required computations belong in render/load/server code or a side-effect-free `$derived`, not an effect.
- Direct `await` in components and `$derived` requires Svelte 5.36+ with `compilerOptions.experimental.async: true`; it remains experimental. Do not introduce it without confirming the project has enabled it. Tracking after an `await` applies only to the derived expression itself, not async functions it calls.

## Primary sources

- [Best practices](https://svelte.dev/docs/svelte/best-practices)
- [$state](https://svelte.dev/docs/svelte/$state), [$derived](https://svelte.dev/docs/svelte/$derived), [$effect](https://svelte.dev/docs/svelte/$effect), [$props](https://svelte.dev/docs/svelte/$props), and [$bindable](https://svelte.dev/docs/svelte/$bindable)
- [Svelte 5 migration guide](https://svelte.dev/docs/svelte/v5-migration-guide)
