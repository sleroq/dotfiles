---
name: solidjs
description: "Solid 2 patterns and reactivity gotchas. Use when authoring or refactoring .tsx/.jsx in a Solid app, designing stores/contexts, syncing server state, or debugging stale reads, async reactivity, and unnecessary work."
compatibility: opencode
---

# SolidJS Skill (2.x)

This skill targets the latest Solid 2 release. Do not apply Solid 1 patterns: `createResource`, `batch`, `startTransition`, `useTransition`, `on`, `createComputed`, `produce`, `createMutable`, `onMount`, `Suspense`, `ErrorBoundary`, and `Index` have been removed or replaced.

Use coordinated Solid 2 package versions. For an RC, verify the compiler, SSR/hydration, and framework integration at runtime—not just with TypeScript.

## Packages and JSX

Import reactive primitives and stores from `solid-js`; import DOM rendering from `@solidjs/web`. `solid-js/store` and `solid-js/web` are no longer valid exports.

```tsx
import { createMemo, createStore, reconcile } from "solid-js"
import { render } from "@solidjs/web"
```

For web JSX, use the web JSX runtime:

```json
{
  "compilerOptions": {
    "jsx": "preserve",
    "jsxImportSource": "@solidjs/web"
  }
}
```

## Signals and stores

- Use `createSignal` for primitives or values replaced wholesale.
- Use `createStore` for object or array state that needs fine-grained updates.
- Update stores through a draft setter. Do not use the removed `produce` helper or Solid 1 path setters for nested changes.

```tsx
const [state, setState] = createStore({
  sessions: [],
  activeId: undefined as string | undefined,
})

setState((draft) => {
  draft.sessions.splice(i, 1)
  draft.activeId = nextId
})
```

## Server sync: reconcile the selected draft

When server data replaces a collection, reconcile it so unchanged entries retain their identity. Apply `reconcile` to the selected draft and provide the stable ID key unless order is authoritative.

```tsx
import { reconcile } from "solid-js"

setState((draft) => {
  reconcile(serverData, "id")(draft.sessions)
})
```

## Effects: separate tracking from side effects

`createEffect` has a compute phase and an untracked apply phase. Put reactive reads in the first callback; put DOM, network, logging, and other imperative work in the second. Its returned cleanup runs before the next application and when disposed.

```tsx
createEffect(
  () => state.status,
  (status, previous) => {
    if (status === "complete" && previous !== "complete") finalize()
    document.title = status
  },
)
```

Use `onSettled` for work that must run after the initial reactive graph settles; `onMount` no longer exists. Use `untrack` only to deliberately read a reactive value without adding a dependency during computation.

## Automatic batching

Solid batches updates automatically within a microtask. Do not add the removed `batch()` or `startTransition()` APIs. At an imperative or test boundary that must observe updates synchronously, use `flush()`.

## Async reactivity

An async computation is native reactive state; prefer an async `createMemo` over `createResource`.

```tsx
const user = createMemo(async () => {
  const id = userId() // Read reactive inputs before the first await.
  const response = await fetch(`/api/users/${id}`)
  return response.json()
})

return (
  <Loading fallback={<UserSkeleton />}>
    <UserView user={user()} />
  </Loading>
)
```

Reactive reads after the first `await` do **not** establish dependency edges. Capture every signal/store value that determines the request before awaiting. Use `Loading` and `Errored` for pending and failure UI; use `isPending`, `latest`, `refresh`, and `action` when their lifecycle or mutation semantics are needed.

## Props and JSX

Never destructure reactive props: it reads them once and disconnects later reads from top-level tracking. Keep `props` intact; use `omit` to forward props and `merge` to apply defaults.

```tsx
// stale
function Row({ label }: Props) {
  return <span>{label}</span>
}

// reactive
function Row(props: Props) {
  return <span>{props.label}</span>
}
```

- Use `<For>` for lists. Use `<For keyed={false}>` for positional list semantics; `Index` was removed.
- Use `<Show>` for conditional JSX, rather than an imperative conditional over a signal.
- Use `Loading`, `Errored`, and `Reveal`, not `Suspense`, `ErrorBoundary`, or `SuspenseList`.
- Pass classes with `class` object/array syntax, not `classList`.
- Use camel-case event props. Replace `on:`/`oncapture:` syntax with native event listeners or those props.
- Use ref callbacks or directive factories, not `use:` directives.
- Render a context directly (`<ThemeContext value={theme()}>`), not `Context.Provider`.

## Performance checklist

- [ ] Mutable object/array state uses `createStore` and draft setters
- [ ] Server collection replacement uses `reconcile(data, "id")` on the selected draft
- [ ] Effects separate reactive computation from imperative application
- [ ] Async computations capture their reactive inputs before their first `await`
- [ ] Lists use `<For>` with keyed or positional semantics chosen deliberately
- [ ] Pending and failure UI uses `Loading` and `Errored`
- [ ] No removed Solid 1 APIs or import paths remain
