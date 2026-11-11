{
  runCommand,
  esbuild,
  source,
  pi,
  nodejs,
  writeShellScriptBin,
  symlinkJoin,
}:
let
  bundle = runCommand "fumo-pi-extension" { nativeBuildInputs = [ esbuild ]; } ''
    mkdir -p "$out"
    esbuild ${source}/clients/pi/index.ts --bundle --platform=node --format=esm --packages=external --outfile="$out/index.js"
    printf '%s\n' '{"type":"module"}' > "$out/package.json"
    ln -s ${pi}/lib/pi/node_modules "$out/node_modules"
    cp ${./fumo-pi-refresh.mjs} "$out/refresh-fumo.mjs"
  '';
  wrapper = writeShellScriptBin "agent-pi" ''
    set -e
    ${nodejs}/bin/node ${bundle}/refresh-fumo.mjs
    exec ${pi}/bin/pi "$@"
  '';
in
symlinkJoin {
  name = "fumo-pi";
  paths = [
    bundle
    wrapper
  ];
}
