{
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "tree-sitter-htmlx-svelte";
  version = "0.1.16";

  src = fetchFromGitHub {
    owner = "themixednuts";
    repo = "tree-sitter-htmlx";
    rev = "c9b9cc35709fff494a3a9e41cd9471b633649e45";
    hash = "sha256-qEzK2sPmSFYBNMeLR7KNwReOkx3LIytUFbuF1BMFZsw=";
  };

  sourceRoot = "source/crates/tree-sitter-svelte";

  buildPhase = ''
    runHook preBuild
    $CC -shared -fPIC -Isrc src/parser.c src/scanner.c -o tree-sitter-svelte
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 tree-sitter-svelte $out/lib/tree-sitter-svelte
    runHook postInstall
  '';
}
