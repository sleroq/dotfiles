---
name: designing-typescript-domains
description: "Designs readable TypeScript domain APIs using modules, branded values, object factories, and classes only when instance semantics are useful. Use when creating or refactoring helpers, utility classes, domain objects, service objects, shared contexts, or code with excessive standalone-function styling."
---

# Designing TypeScript Domains

Shape TypeScript APIs around domain concepts without hiding pure behavior in classes or shared context.

## Start With Local Conventions

Read the nearest project guidance and representative neighboring modules before choosing a shape. Preserve an established local convention unless it creates a concrete correctness or maintenance problem.

Do not refactor only to replace `functionName()` with `Object.functionName()`. The new shape must improve domain vocabulary, ownership, discoverability, or lifecycle management.

## Choose the Smallest Honest Shape

Use this order of preference:

1. **Module-level function** for one pure, stateless operation.
2. **Domain module or same-name object** for several operations belonging to one domain concept.
3. **Branded value plus constructors** for scalar identities that must not mix with ordinary primitives.
4. **Factory returning a narrow object** for behavior that closes over dependencies or private per-instance state.
5. **Class** only when runtime instance semantics are useful.
6. **Injected service or shared context** only for runtime capabilities or scoped data, never merely to hold pure helpers.

## Pure Domain Behavior

Keep deterministic transformations directly importable. If several operations form a clear vocabulary, group them around a domain noun.

### Portable object API

```ts
export type MessageKey = string & {
  readonly MessageKey: unique symbol
}

export const MessageKey = {
  make(input: {
    scopeID: string
    channelID: string
    sequence: bigint
  }) {
    const sequence = input.sequence.toString().padStart(20, "0")
    return `${input.scopeID}:${input.channelID}:${sequence}` as MessageKey
  },
}
```

Callers get domain-oriented code:

```ts
const key = MessageKey.make(input)
```

### ESM module projection

When the codebase already uses namespace-style ESM projections, keep flat exports and project the module:

```ts
export type ID = string & {
  readonly MessageKey: unique symbol
}

export function make(input: Input) {
  // ...
  return value as ID
}

export function parse(value: string) {
  // ...
}

export * as MessageKey from "./message-key"
```

This provides `MessageKey.make(...)` without a static class. Use this pattern only when supported by the project's module/runtime conventions.

Keep non-exported helpers at module scope. Avoid private static methods used only to simulate module privacy.

## Branded Scalar Values

Brand IDs, keys, addresses, and other scalar domain values when accidentally mixing them with arbitrary strings or numbers would be a real bug.

Expose a small vocabulary:

- `make` for trusted construction or normalization
- `parse` for validation that can fail
- `fromX` when the source representation matters
- `format` or `toX` for meaningful projections

Do not brand ordinary values without a domain-safety benefit. Do not add both a top-level constructor and an object method that perform the same operation; keep one canonical construction path.

## Factories for Private State and Captured Dependencies

Use a factory when each consumer needs an independent object and class identity is irrelevant:

```ts
export function makeMessageCache(options: { readonly limit: number }) {
  const messages = new Map<string, string>()

  return {
    get(id: string) {
      return messages.get(id)
    },
    set(id: string, value: string) {
      messages.set(id, value)
      if (messages.size <= options.limit) return
      const oldest = messages.keys().next()
      if (!oldest.done) messages.delete(oldest.value)
    },
  }
}
```

Return only the capabilities callers need. Keep the closed-over state private. Prefer closure capture over storing dependencies in a broad global object.

## When a Class Is Justified

Use a class when one or more of these are required:

- mutable state tied to a distinct instance
- runtime identity or `instanceof`
- a framework-required base class or decorator target
- protocol behavior such as an iterator
- inheritance required by an external API
- explicit lifecycle methods such as `start`, `close`, or `dispose`
- prototype methods are materially useful across many instances

Do not create a class solely to group static functions:

```ts
// Avoid
export class MessageKeyUtils {
  static make(input: Input) {
    // ...
  }
}
```

Prefer a module function, domain object, or ESM module projection. Avoid inheritance when composition or a narrow interface expresses the relationship.

## Dependency and Context Boundaries

Separate three kinds of code:

### Pure domain operation

Directly import it. It does not need mocking, middleware, or dependency injection.

```ts
MessageKey.make(input)
```

### Runtime capability

Inject behavior that performs IO, owns resources, depends on configuration, or needs swappable implementations.

```ts
export interface MessageClient {
  readonly send: (channelID: string, text: string) => Promise<void>
}
```

### Scoped runtime data

Use middleware or request context for values derived from the current request, session, tenant, or authenticated user.

Do not add pure constructors or formatters to that context. Pass scoped values from the context into the domain operation explicitly.

```ts
const scope = requestContext.messageScope
const key = MessageKey.make({
  scopeID: scope.id,
  channelID: scope.channelID,
  sequence,
})
```

Avoid mega-contexts that combine unrelated domain helpers, IO services, configuration, and request data. Split capabilities by ownership and lifetime.

## Avoid Ambient Context by Default

Do not introduce global mutable state or async-local context merely to avoid passing a value. Ambient context hides requirements and makes behavior depend on the call chain.

Use ambient context only at a framework boundary where explicit propagation is impractical and the project already has an established mechanism. Keep the boundary narrow and restore explicit values immediately.

## Refactoring Workflow

1. List the current operations and the data or dependencies each one uses.
2. Separate pure transformations from IO, mutable state, and scoped runtime data.
3. Name the domain concept callers should see.
4. Select the smallest shape from the decision order above.
5. Keep one canonical construction path.
6. Move only behavior owned by that concept; do not create a generic `Utils`, `Manager`, or `Context` bucket.
7. Update call sites so they read as domain vocabulary.
8. Verify that dependencies remain explicit and test the public behavior.

## Review Checklist

- Does the API name a domain concept rather than an implementation category?
- Is pure behavior still callable without constructing or injecting anything?
- Does every class need instance semantics?
- Does every factory own private state or captured dependencies?
- Does shared context contain only truly scoped data or runtime capabilities?
- Is there exactly one obvious way to construct each domain value?
- Are private details unexported?
- Did the change reduce coupling as well as visual function noise?
- Does the result follow the nearest repository convention?

## References

- [TypeScript Handbook: Classes and why there are no static classes](https://www.typescriptlang.org/docs/handbook/2/classes.html#why-no-static-classes)
- [TypeScript Handbook: Modules](https://www.typescriptlang.org/docs/handbook/2/modules.html)
- [Google TypeScript Style Guide: exports and container classes](https://google.github.io/styleguide/tsguide.html#exports)
- [typescript-eslint: no-extraneous-class](https://typescript-eslint.io/rules/no-extraneous-class/)
- [MDN: JavaScript classes](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes)
- [MDN: Closures](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Closures)

Imported from [divaltor/.dotfiles](https://github.com/divaltor/.dotfiles/blob/ee95046d60707a8a4e1ec72412b2aaa4e4e61ebc/.config/opencode/skills/designing-typescript-domains/SKILL.md).
