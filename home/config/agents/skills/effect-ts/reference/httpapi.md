# HttpApi

Use `effect/unstable/httpapi` for typed endpoint contracts, handler construction, middleware, and OpenAPI metadata. Verify exact APIs against the installed Effect version because unstable modules may change between prereleases.

## Contract ownership

Keep public wire schemas in a low-level, runtime-independent module. Build HttpApi endpoint and group definitions from those canonical schemas. Keep server implementations and infrastructure layers above the contract modules in the dependency graph.

Domain services should own business rules and typed domain failures without depending on HTTP status codes, server responses, or route-specific errors.

## Endpoint groups

Declare payload, URL parameter, header, success, and error schemas explicitly. Implement handlers through `HttpApiBuilder.group`:

```ts
export const UserHandlers = HttpApiBuilder.group(Api, "users", (handlers) =>
  Effect.gen(function* () {
    const users = yield* UserService;

    return handlers.handle("list", () => users.list());
  }),
);
```

Yield stable services while constructing the handler layer and close over them. Do not provide or rebuild stable service layers inside each request handler.

## Raw responses and streaming

Stay in the declared API tree for public routes:

- Use the group's raw-handler facility when an endpoint requires raw request or response access.
- For server-sent events, return a scoped streaming response and annotate the success schema with the correct content type.
- Keep stream queues, subscriptions, and cleanup scoped to the request lifetime.
- Use a raw router only for routes intentionally outside the declared API surface.

## Errors

Public JSON errors should be endpoint-declared schemas. Translate domain errors at the handler boundary:

```ts
return (
  yield *
  users
    .get(id)
    .pipe(
      Effect.catchTag(
        "UserNotFound",
        (error) => new ApiNotFoundError({ message: error.message }),
      ),
    )
);
```

Use built-in transport error classes only when their exact status and wire body are intended. Do not expose internal causes or defects through public responses by default.

## Middleware and provisioning

- Declare contract middleware on its owning API group or endpoint.
- Provide middleware implementation layers once during server assembly.
- Use request-local service provisioning only for values derived from that request, such as authenticated identity or route context.
- Do not use request provisioning to smuggle stable application services into handlers.
- Keep global transport policy at the outer server boundary.

## Contract changes

When a project generates clients or OpenAPI artifacts, run its canonical generation command after changing the public API. Never edit generated output directly, and review generated changes as part of the contract change.
