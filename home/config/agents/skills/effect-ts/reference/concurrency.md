# Concurrency and caching

## Fiber ownership

Use ownership and lifetime to choose the fork operator:

```ts
yield * work.pipe(Effect.forkIn(scope));
yield * subscription.pipe(Stream.runForEach(handle), Effect.forkScoped);
```

- `forkIn(scope)` attaches work to an explicit scope.
- `forkScoped` attaches work to the current scope.
- `forkDetach` is for deliberate runtime/process-owned work that must outlive the caller.
- `forkChild` is valid for ordinary child-fiber concurrency where structured child lifetime is intended.
- `Effect.fork` and `Effect.forkDaemon` do not exist in the pinned Effect version.

Do not mechanically replace detached or child work with scoped work; first identify who owns cancellation.

## Explicit fan-out

```ts
const [left, right] =
  yield *
  Effect.all([loadLeft, loadRight], {
    concurrency: "unbounded",
  });

const results =
  yield *
  Effect.forEach(items, processItem, {
    concurrency: 4,
  });
```

Do not assume collection combinators run concurrently by default.

## Deferred

Use the effectful constructor in Effect workflows:

```ts
const ready = yield * Deferred.make<void>();
yield * Deferred.succeed(ready, undefined);
yield * Deferred.await(ready);
```

Use `Deferred.makeUnsafe` only when a synchronous constructor is required by synchronous state setup. “Unsafe” means construction is outside the normal Effect operation, not that the value has different scope semantics.

## FiberSet and FiberMap

`FiberSet.run` and `FiberMap.run` return Effects; execute them:

```ts
const fibers = yield * FiberSet.make<void, StoreError>();

yield *
  Effect.forEach(outputs, (output) => FiberSet.run(fibers, store(output)), {
    discard: true,
  });

yield * FiberSet.join(fibers);
```

Do not call `FiberSet.run(...)` inside a plain JavaScript `forEach` and discard the returned Effect.

Use `FiberMap` when one running fiber is allowed per key.

## Semaphores and keyed locking

Prefer permit combinators that guarantee release:

```ts
const semaphore = yield * Semaphore.make(1);
const result = yield * semaphore.withPermit(criticalSection);
```

Use an established keyed mutex or lock service when serialization is keyed by an ID or path instead of constructing ad hoc semaphore maps.

## Caching semantics

Choose the cache operator based on invalidation requirements:

```ts
const cached = yield * Effect.cached(load);

const cachedForMinute = yield * Effect.cachedWithTTL(load, "1 minute");

const [get, invalidate] =
  yield * Effect.cachedInvalidateWithTTL(load, Duration.infinity);
```

- `Effect.cached` retains the computed result; it is more than in-flight deduplication.
- `cachedWithTTL` refreshes after expiry.
- `cachedInvalidateWithTTL` is appropriate for refreshable state with explicit invalidation.

Do not replace refreshable state with permanent caching merely to deduplicate concurrent callers.

## Callback interop

Use `Effect.callback` when an API completes through a callback and may require cancellation cleanup:

```ts
const value =
  yield *
  Effect.callback<Value, CallbackError>((resume) => {
    const cancel = external.start((result) => resume(decodeResult(result)));
    return Effect.sync(cancel);
  });
```

When an external callback later needs to run arbitrary application Effects, use a small runtime adapter that explicitly captures the required runtime and application context.

## Timeouts and test synchronization

Use timeout operators around published signals such as Deferred values, observable service state, events, or polling predicates. Do not use a fixed sleep to guess when another fiber is ready. Sleeps remain valid when passage of time is the behavior being tested.
