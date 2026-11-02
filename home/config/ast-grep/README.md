# ast-grep maintenance

Build the Svelte parser with `-fno-strict-aliasing`; otherwise loading the shared config can crash, even with `ast-grep --version`.

Configure editors with `ast-grep lsp --config <generated-project-config>`: the language server does not discover configs in parent directories.

From this directory, check rules and fixtures with:

```sh
ast-grep scan --config ./sgconfig.yml .
ast-grep test --config ./sgconfig.yml --skip-snapshot-tests
```

The checkout config needs untracked links at `parsers/tree-sitter-svelte` and `parsers/tree-sitter-zig` pointing to the Nix parser outputs. Do not use this config at the home level; its relative `rules` path would be wrong.

After adding Zig support, existing generated configs require home activation or a profile reinstall—not just updated rules.
