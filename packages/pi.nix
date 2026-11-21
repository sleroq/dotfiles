{ applyPatches, upstream }:

upstream.override (previous: {
  source = applyPatches {
    name = "pi-source";
    src = previous.source;
    patches = [ ./patches/pi-no-cwd-context.patch ];
  };
})
