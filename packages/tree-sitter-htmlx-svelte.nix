{
  stdenv,
  fetchFromGitHub,
  ast-grep,
}:

let
  pin = builtins.fromJSON (builtins.readFile ../home/config/ast-grep/svelte-parser.json);
in
stdenv.mkDerivation {
  pname = "tree-sitter-htmlx-svelte";
  inherit (pin) version;

  src = fetchFromGitHub {
    inherit (pin)
      owner
      repo
      rev
      hash
      ;
  };

  sourceRoot = "source/crates/tree-sitter-svelte";

  buildPhase = ''
    runHook preBuild
    # Tree-sitter's Array macros type-pun through Array(void); strict aliasing
    # miscompiles scanner tag-stack growth and crashes ast-grep during setup.
    $CC -shared -fPIC -fno-strict-aliasing -Isrc src/parser.c src/scanner.c -o tree-sitter-svelte
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 tree-sitter-svelte $out/lib/tree-sitter-svelte
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ ast-grep ];
  installCheckPhase = ''
    runHook preInstallCheck
    cat > sgconfig.yml <<EOF
    ruleDirs: []
    customLanguages:
      svelte:
        libraryPath: $out/lib/tree-sitter-svelte
        extensions: [svelte]
        languageSymbol: tree_sitter_svelte
    EOF

    # Compile the shared injection patterns and exercise scanner tag-stack growth.
    echo '<script>const value = 1;</script>' | \
      ast-grep run --lang svelte --pattern '<script>$CONTENT</script>' --stdin
    echo '<script lang="ts">const value: number = 1;</script>' | \
      ast-grep run --lang svelte --pattern '<script lang="ts">$CONTENT</script>' --stdin
    runHook postInstallCheck
  '';
}
