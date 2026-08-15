# Testing Effect code

Use the project's Effect-aware runner and fixtures when available. Keep runtime, clock, console, scope, and dependency provisioning visible in the test setup.

## Basic pattern

```ts
const it = testEffect(MyServiceLayer);

describe("MyService", () => {
  it.effect("loads values", () =>
    Effect.gen(function* () {
      const service = yield* MyService;
      expect(yield* service.load()).toEqual(["value"]);
    }),
  );
});
```

If the project does not provide a custom runner, use its normal test framework and a small shared helper that runs a scoped Effect with an explicit test layer. Avoid recreating a `ManagedRuntime` in every test file.

## Test clock versus live services

- Use a test clock for deterministic timeout, retry, schedule, debounce, and polling behavior.
- Use live services for real filesystem operations, child processes, sockets, locks, watchers, and wall-clock integration.
- Do not mix a test clock with APIs that depend on real time unless the test intentionally bridges both.

## Layers and substitutions

Prefer an open service layer when replacing dependencies and a closed application layer when production wiring is part of the behavior under test.

Use focused partial service substitutions when supported:

```ts
const accountLayer = Layer.mock(AccountService, {
  load: () => Effect.fail(new AccountError({ message: "unavailable" })),
});
```

Unspecified methods should fail visibly if called. A complete `Layer.succeed` implementation is appropriate when the entire fake boundary is small and deliberate.

Extract shared fakes only after the same boundary implementation repeats across tests.

## Scoped fixtures

Use scoped fixtures for temporary directories, databases, servers, fibers, subscriptions, and configuration. Register finalizers for every resource created by a test.

```ts
const directory =
  yield * Effect.acquireRelease(makeTempDirectory, removeTempDirectory);
```

Avoid Promise-style setup and teardown around an Effect test when acquisition and release can live in the Effect scope.

## Concurrent synchronization

Wait for observable readiness:

- `Deferred`
- service status APIs
- stream or event signals
- mock-server call counters
- polling predicates with bounded timeouts
- fibers joined or awaited directly

```ts
const ready = yield * Deferred.make<void>();
const fiber = yield * worker(ready).pipe(Effect.forkChild);
yield * Deferred.await(ready).pipe(Effect.timeout("2 seconds"));
yield * Fiber.join(fiber);
```

Do not use fixed sleeps to guess when concurrent work is ready. Sleeps are acceptable when passage of time is itself the behavior under test, such as debounce behavior or timestamp resolution.

## Failure assertions

Assert through the Effect error channel:

```ts
const error = yield * Effect.flip(service.load());
expect(error).toBeInstanceOf(LoadError);

const exit = yield * service.load().pipe(Effect.exit);
expect(Exit.isFailure(exit)).toBe(true);
```

Use rendered Causes when diagnosing defects or interruption. Avoid Promise `try`/`catch` around Effect failures.

## Checklist

- Dependencies are supplied through explicit test layers.
- Resources are scoped and finalized.
- Expected failures stay typed.
- Promise boundaries are yielded inside Effect when they cannot be effectified.
- Formerly parallel behavior remains explicitly parallel.
- Readiness uses deterministic signals rather than timing guesses.
- Environment and global state are not mutated after dependent layers are built.
