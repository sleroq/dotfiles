# Configuration

Use Effect `Config` as the source of truth for environment names, parsing, defaults, and validation.

```ts
const AppConfig = Config.all({
  port: Config.integer("PORT").pipe(Config.withDefault(3000)),
  enabled: Config.boolean("FEATURE_ENABLED").pipe(Config.withDefault(false)),
  token: Config.string("TOKEN").pipe(Config.option),
});
```

Read configuration while constructing a layer so service methods receive parsed values rather than repeatedly consulting process state.

## Config-backed service

Wrap configuration in a service when many consumers need the parsed values or tests benefit from direct substitution:

```ts
export interface AppConfigShape {
  readonly port: number;
  readonly token: Option.Option<string>;
}

export class AppConfigService extends Context.Service<
  AppConfigService,
  AppConfigShape
>()("app/AppConfig") {}

export const AppConfigLayer = Layer.effect(
  AppConfigService,
  Config.all({
    port: Config.integer("PORT").pipe(Config.withDefault(3000)),
    token: Config.string("TOKEN").pipe(Config.option),
  }).pipe(Effect.map(AppConfigService.of)),
);
```

For a small service with one configuration value, yielding the Config directly during layer construction may be simpler.

## Tests

Use `ConfigProvider` when testing parsing behavior:

```ts
const providerLayer = ConfigProvider.layer(
  ConfigProvider.fromUnknown({ PORT: 8080 }),
);

const testLayer = AppConfigLayer.pipe(Layer.provide(providerLayer));
```

When parsing is not under test, provide the already-parsed config service directly:

```ts
const testConfig = Layer.succeed(
  AppConfigService,
  AppConfigService.of({ port: 8080, token: Option.none() }),
);
```

Do not mutate `process.env`, feature flags, or module globals after dependent layers are built. Configuration is normally captured during layer construction.
