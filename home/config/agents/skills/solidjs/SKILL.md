---
name: solidjs
description: "Non-obvious SolidJS patterns and reactivity gotchas. Use when authoring or refactoring .tsx/.jsx in a SolidJS app, designing stores/contexts, syncing server state, or debugging reactivity issues (stale reads, missing updates, extra re-runs)."
compatibility: opencode
---

# SolidJS Skill

Covers the patterns and pitfalls that aren't obvious from the official docs. Assume the agent knows core primitives (`createSignal`, `createEffect`, `createMemo`, `batch`, `mapArray`, `onMount`/`onCleanup`, `lazy`, JSX control-flow components).

## Signal vs Store

- Use `createSignal` only for primitives or values replaced wholesale.
- Use `createStore` the moment state is an object or array you mutate in place. Mixing setters that replace an object with code that expects fine-grained updates is the #1 source of "why didn't it re-render".

## Server sync: `reconcile` with a key

Replacing an array via `setStore("items", newItems)` invalidates every row. Use `reconcile` so unchanged rows keep their identity (and downstream memos/components don't re-run).

```tsx
import { reconcile } from "solid-js/store"

setStore("sessions", reconcile(serverData, { key: "id" }))
```

Omit `{ key }` only when the array is already authoritative-by-position (already sorted/aligned). Otherwise always pass it.

## `produce` for nested mutations

```tsx
import { produce } from "solid-js/store"

setStore(produce((draft) => {
  draft.sessions.splice(i, 1)
  draft.activeId = nextId
}))
```

Prefer `produce` over chained `setStore("a", "b", "c", v)` calls when touching multiple paths in one update.

## Effects: `on()` for explicit deps

`createEffect` auto-tracks every signal read. When you want to react to *one* signal and read others passively, use `on()` — it also gives you the previous value.

```tsx
import { createEffect, on } from "solid-js"

createEffect(on(
  () => store.status,
  (status, prevStatus) => {
    if (status === "complete" && prevStatus !== "complete") finalize()
  },
))
```

## `untrack()` to read without subscribing

Inside an effect/memo, wrap reads you don't want to depend on:

```tsx
createEffect(() => {
  const tab = activeTab() // tracked
  untrack(() => {
    if (state.scrollPos[tab.id]) restore(tab) // not tracked
  })
})
```

## Isolated reactive trees: `createRoot` + `runWithOwner`

Use when a sub-tree's lifetime is shorter than its parent (per-document stores, transient dialogs, plugin sandboxes). Without this, computations leak until the parent disposes.

```tsx
import { createRoot, runWithOwner, getOwner, onCleanup } from "solid-js"

const parent = getOwner()
let dispose: (() => void) | undefined

const start = () => {
  dispose?.()
  dispose = createRoot((d) => {
    // create signals/effects scoped here
    return d
  })
  runWithOwner(parent, () => onCleanup(() => dispose?.()))
}
```

## Persistence hydration race

`makePersisted` from `@solid-primitives/storage` hydrates async. If a route reads the signal during initial render it can see the initial value and overwrite storage on first commit. Gate rendering on a `ready` flag (e.g. a resolved `createResource`) before the first write path runs.

## Props: never destructure

Destructuring breaks reactivity — the value is read once.

```tsx
// ✗ stale
function Row({ label }: Props) { return <span>{label}</span> }

// ✓ reactive
function Row(props: Props) { return <span>{props.label}</span> }
```

Use `splitProps` / `mergeProps` when you need to forward or default values.

## Anti-patterns

- **Storing `Accessor`/`Setter` on a class instance.** Reactivity and class fields don't compose; use a closure or a context.
- **`createSignal` for collections you mutate** — switch to `createStore`.
- **`for`/`while` over signals in JSX.** Use `<For>` (keyed) or `<Index>` (positional).
- **Conditional `if` in JSX over signals.** Use `<Show>` so the branch tracks the signal.
- **Per-row event handlers created in render bodies.** Hoist or memoize when lists are large.
- **Missing `<ErrorBoundary>` at route boundaries.** A single throw in a child unmounts the whole app otherwise.
- **`any` types** — rely on inference; SolidJS types are precise.

## Performance checklist (the non-obvious bits)

- [ ] Array updates go through `reconcile({ key })`
- [ ] Multi-property updates wrapped in `batch()` or a single `produce()`
- [ ] Large list mutations wrapped in `startTransition()`
- [ ] Lists rendered with `<For>` (keyed) unless positional is intended
- [ ] Effects with one true dep use `on()` instead of implicit tracking
- [ ] Sub-trees with shorter lifetime than parent use `createRoot`
