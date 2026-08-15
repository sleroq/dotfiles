---
name: effect-ts
description: "Portable Effect v4 guidance for services, layers, schemas, HTTP, runtime boundaries, concurrency, configuration, and testing."
---

# Effect TS

Use this skill for portable Effect v4 TypeScript code.

## Source of truth

1. Follow the nearest project instructions and local conventions.
2. Check the installed Effect version before choosing APIs.
3. Verify unfamiliar APIs in the matching Effect source and official documentation. Do not rely on v2/v3 examples or memory.
4. Prefer the newest established, tested local pattern when project guidance conflicts, and call out material conflicts.

Effect v4 APIs may move while prereleases evolve. Generic HTTP modules live under `effect/unstable/http` and `effect/unstable/httpapi` in current v4 builds. Add a platform package only when its runtime or platform-specific services are required.

## Imports and modules

Prefer named imports from `effect` and its subpaths:

```ts
import { Context, Effect, Layer, Schema } from "effect";
import {
  HttpClient,
  HttpClientRequest,
  HttpClientResponse,
} from "effect/unstable/http";
```

Avoid star imports, import aliases, unnecessary barrels, and namespace-based module organization. Follow the project's existing ESM export convention.

## Services

Prefer a standalone contract, `Context.Service`, and an explicit layer when dependencies should remain visible:

```ts
export interface UserRepository {
  readonly find: (id: UserID) => Effect.Effect<User, UserNotFound>;
}

export class UserRepositoryService extends Context.Service<
  UserRepositoryService,
  UserRepository
>()("app/UserRepository") {}

export const UserRepositoryLayer = Layer.effect(
  UserRepositoryService,
  Effect.gen(function* () {
    const database = yield* Database;

    const find = Effect.fn("UserRepository.find")(function* (id: UserID) {
      return yield* database.findUser(id);
    });

    return UserRepositoryService.of({ find });
  }),
);
```

- Yield dependencies once while constructing a layer and close over them in service methods.
- Bind services to named variables before invoking methods; avoid nested service yields.
- Use `Effect.fn("Domain.method")` for named or traced workflows.
- Use `Effect.fnUntraced` for reusable internal workflows that do not need spans.
- Use the service constructor's `of(...)` helper when available to validate implementations.
- Preserve local service naming and key conventions rather than imposing one universal style.

## Layers

Keep dependencies explicit:

```ts
export const AppLayer = FeatureLayer.pipe(
  Layer.provide(DatabaseLayer),
  Layer.provide(HttpLayer),
);
```

- `Layer.provide` satisfies dependencies and hides the provided outputs.
- `Layer.provideMerge` satisfies dependencies and retains the provided outputs.
- `Layer.mergeAll` combines independent layers.
- `Layer.unwrap` builds a layer from an Effect when selection is dynamic.
- `Layer.fresh` opts out of normal layer memoization when a new resource instance is intentional.
- Use `Effect.provideService` when a sub-effect needs an already-constructed service value; do not build a one-off layer for that case.
- Provide stable layers at application boundaries, not repeatedly inside methods or request handlers.

## Schemas and errors

Choose schemas by behavior and boundary:

- `Schema.Struct` for serializable data records and wire contracts.
- `Schema.Class` when runtime behavior, normalization, or class identity is useful.
- `Schema.TaggedClass` for discriminated runtime classes.
- `Schema.TaggedErrorClass` for typed expected failures.
- `Schema.brand` for nominal scalar types.

```ts
export class ReadError extends Schema.TaggedErrorClass<ReadError>()(
  "ReadError",
  {
    message: Schema.String,
    cause: Schema.optional(Schema.Defect()),
  },
) {}
```

Direct early failures may yield a yieldable error:

```ts
if (!record) return yield * new NotFoundError({ id });
```

Map lower-level failures with Effect error combinators rather than `try`/`catch`. Keep domain services independent of transport-specific errors and translate failures at the transport boundary.

Prefer decode-only defaults for external input. Use constructor defaults only when construction-time normalization is part of the domain value. Use `Schema.Json` for JSON values, `Schema.Unknown` for opaque values, and avoid `Schema.Any` outside documented unsafe boundaries.

See [reference/schema.md](reference/schema.md).

## HTTP client

Build requests explicitly, execute through an injected client, and decode with Schema:

```ts
const client = yield * HttpClient.HttpClient;
const response =
  yield *
  HttpClient.filterStatusOk(client).execute(
    HttpClientRequest.post(url).pipe(
      HttpClientRequest.acceptJson,
      HttpClientRequest.bodyJson(body),
    ),
  );
const result = yield * HttpClientResponse.schemaBodyJson(Response)(response);
```

Provide the platform client at the application boundary. Apply retries, redirects, authentication, and observability as client transformations rather than hand-written request loops.

## HttpApi

- Define endpoint payload, parameter, success, and error schemas explicitly.
- Use `HttpApiBuilder.group` for typed handlers.
- Yield stable services while constructing the handler layer and close over them.
- Use raw handlers only when an endpoint genuinely requires raw request or response access.
- Keep domain failures transport-independent and map them to endpoint-declared errors.
- Provide middleware implementations and stable dependencies at the server assembly boundary.

See [reference/httpapi.md](reference/httpapi.md).

## Runtime boundaries

Prefer one deliberately assembled `ManagedRuntime` at an actual non-Effect application boundary. Do not create a runtime merely to call one service from another Effect workflow.

For callbacks, use `Effect.callback` when completion is callback-driven. When callbacks must later re-enter a prepared runtime, capture the required runtime, services, and application context explicitly in a small boundary adapter.

See [reference/runtime.md](reference/runtime.md).

## Concurrency and caching

- Use `Effect.forkIn(scope)` and `Effect.forkScoped` for scoped background work.
- Use detached forks only when process- or runtime-owned lifetime is deliberate.
- Use `Effect.all` or `Effect.forEach` with explicit concurrency for fan-out.
- Use `FiberSet` and `FiberMap` for managed dynamic fibers; execute the Effect returned by their operations.
- Use `Deferred.make` in Effect code and unsafe constructors only at justified synchronous boundaries.
- Prefer semaphore permit combinators over manual acquisition and release.
- Distinguish permanent caching, TTL caching, and explicitly invalidatable caching.
- Use `Effect.callback` for callback completion and cancellation cleanup.

See [reference/concurrency.md](reference/concurrency.md).

## Configuration

Use `Config` combinators for typed environment configuration and read configuration while constructing layers:

```ts
const AppConfig = Config.all({
  port: Config.integer("PORT").pipe(Config.withDefault(3000)),
  token: Config.string("TOKEN").pipe(Config.option),
});
```

Use `ConfigProvider` to supply test configuration. Do not mutate environment variables or global flags after dependent layers are built.

See [reference/config.md](reference/config.md).

## Testing

- Use the project's Effect-aware test runner and fixtures when available.
- Choose a test clock for deterministic time and live services for real filesystem, process, socket, or wall-clock behavior.
- Prefer explicit layers and focused service substitutions.
- Scope temporary resources and register finalizers.
- Synchronize concurrent tests through observable state, events, Deferred values, or fibers rather than timing guesses.
- Fixed sleeps are valid only when elapsed time is itself the behavior under test.

See [reference/testing.md](reference/testing.md).

## General conventions

- Use `Effect.void` instead of `Effect.succeed(undefined)`.
- Prefer `DateTime.nowAsDate` when an Effect workflow needs the current `Date`.
- Prefer Schema JSON-string combinators over `JSON.parse` wrapped in `Effect.try`.
- Avoid `any`, non-null assertions, unchecked casts, and broad hidden provisioning.
- Do not swallow failures into `null`; reserve optional values for valid absence.
- Use Effect-aware filesystem, process, HTTP, path, clock, and configuration services when already inside Effect code.

## References

- [Schema](reference/schema.md)
- [HttpApi](reference/httpapi.md)
- [Runtime boundaries](reference/runtime.md)
- [Concurrency and caching](reference/concurrency.md)
- [Configuration](reference/config.md)
- [Testing](reference/testing.md)
