# Runtime boundaries

## ManagedRuntime

Create a `ManagedRuntime` at a genuine boundary where Promise-, callback-, or framework-driven code must run an assembled Effect application:

```ts
const runtime = ManagedRuntime.make(AppLayer);

await runtime.runPromise(program);
const fiber = runtime.runFork(backgroundProgram);
```

Keep the runtime's lifetime explicit and dispose it during application shutdown. Avoid constructing runtimes inside service methods, request handlers, or tests merely to satisfy dependencies.

## Layer memoization

Layers are memoized within a runtime. Shared memo maps can intentionally share layer resources across related runtimes, but they also widen resource lifetime and identity. Use them only when that sharing is part of the architecture.

Do not use shared memoization for state that should be isolated by tenant, request, project, workspace, or another domain key. Model that lifetime explicitly with scoped caches or keyed resource services.

## Promise boundaries

Stay inside Effect whenever possible:

```ts
const value = yield * Effect.promise(() => externalPromise());
```

Use `Effect.tryPromise` when Promise rejection should become a typed error:

```ts
const value =
  yield *
  Effect.tryPromise({
    try: () => externalPromise(),
    catch: (cause) => new ExternalError({ cause }),
  });
```

Avoid calling global `Effect.runPromise` from inside application modules when an assembled runtime already exists.

## Callback boundaries

Use `Effect.callback` when an external API completes through callbacks:

```ts
const value =
  yield *
  Effect.callback<Value, CallbackError>((resume) => {
    const cancel = external.start((result) => resume(decode(result)));
    return Effect.sync(cancel);
  });
```

Return a cleanup Effect when cancellation should unregister listeners or stop native work.

When a callback registered now will re-enter the application later, create a small adapter that explicitly captures:

- the intended runtime
- required services or context values
- cancellation ownership
- any framework-local context that must be restored

Do not depend on accidental ambient state.

## Scoped resources

Use `Effect.acquireRelease`, `Effect.addFinalizer`, and scoped layers for resources:

```ts
const connection =
  yield * Effect.acquireRelease(openConnection, closeConnection);
```

Place background fibers associated with the resource in the same scope with `Effect.forkScoped` or `Effect.forkIn(scope)`. The scope should own both the resource and its background work.

## Entry points

At a CLI, worker, or server entry point:

1. Build the complete application layer once.
2. Run one scoped main Effect with the platform runtime.
3. Convert failures to process exit behavior only at the outermost boundary.
4. Dispose managed runtimes and scoped resources during shutdown.
