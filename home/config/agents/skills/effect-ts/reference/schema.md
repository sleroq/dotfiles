# Schema

Use Schema for validation, normalization, serialization contracts, domain modeling, and typed failures.

## Choosing a constructor

| Need                                     | Constructor               |
| ---------------------------------------- | ------------------------- |
| Serializable record or DTO               | `Schema.Struct`           |
| Runtime object with behavior or identity | `Schema.Class`            |
| Discriminated runtime class              | `Schema.TaggedClass`      |
| Typed expected failure                   | `Schema.TaggedErrorClass` |
| Nominal scalar                           | `Schema.brand`            |

Prefer Structs for portable wire contracts. Use classes only when their runtime behavior or identity provides value.

## Structs and public types

```ts
export const User = Schema.Struct({
  id: UserID,
  name: Schema.String,
  metadata: Schema.optional(Schema.Json),
});
export type User = typeof User.Type;
```

Follow the project's established interface or type-alias convention. Keep wire schemas serializable and free of runtime services, registries, and host-specific behavior.

## Optional fields and defaults

Understand the distinction between an optional key, an `undefined` value, a decoding default, and a constructor default.

- Use optional-key schemas when a property may be absent on the wire.
- Prefer `Schema.withDecodingDefault(...)` for external convenience defaults.
- Use `Schema.withConstructorDefault(...)` only when direct construction should normalize omitted values.
- Verify how encoding handles `undefined`; use a local helper when the project requires undefined properties to be omitted.

## Runtime classes

```ts
export class Point extends Schema.Class<Point>("Point")({
  x: Schema.Number,
  y: Schema.Number,
}) {
  get magnitude() {
    return Math.hypot(this.x, this.y);
  }
}
```

Use getters for derived, side-effect-free values. Add idempotent factories only when callers genuinely accept either constructor data or an existing instance.

## Recursive schemas

Place `Schema.suspend` at the recursive field. It works in Struct and Class definitions:

```ts
export interface Tree extends Schema.Schema.Type<typeof Tree> {}
export const Tree = Schema.Struct({
  value: Schema.String,
  children: Schema.Array(Schema.suspend(() => Tree)),
});
```

Do not cast recursive schemas to `any`. Prefer Effect- or Option-based decoding when synchronous decoder constraints do not fit.

## Branded scalars

```ts
export const UserID = Schema.String.pipe(Schema.brand("UserID"));
export type UserID = typeof UserID.Type;
```

Use stable, unique brand and schema identifiers for exported contracts.

## Errors and defects

```ts
export class StorageError extends Schema.TaggedErrorClass<StorageError>()(
  "StorageError",
  {
    message: Schema.String,
    cause: Schema.optional(Schema.Defect()),
  },
) {}
```

Pass arbitrary causes directly to a `Schema.Defect()` field. Do not instantiate `Schema.Defect` with `new`.

Use tagged errors for expected domain failures. Reserve defects for bugs, violated invariants, and failures that cannot be usefully handled through the typed error channel.

## Decoding and encoding

```ts
Schema.decodeUnknownEffect(Value)(input); // typed failure channel
Schema.decodeUnknownOption(Value)(input); // optional parse
Schema.decodeUnknownSync(Value)(input); // throws
Schema.encodeUnknownSync(Value)(value); // boundary serialization
```

Use synchronous throwing variants only at narrow startup, tooling, or test boundaries where throwing is intentional.

For untrusted JSON strings, use the current Schema JSON-string combinator rather than `JSON.parse` inside `Effect.try`.

## Unknown values

- Use `Schema.Json` when a value must be JSON-serializable.
- Use `Schema.Unknown` when consumers must narrow an opaque value.
- Avoid `Schema.Any` except at an explicitly documented unsafe compatibility boundary.

## Mutability

Keep public contracts readonly by default. Runtime code that needs mutation should opt in at its boundary with a deliberate mutable or draft type rather than changing the public schema for implementation convenience.
