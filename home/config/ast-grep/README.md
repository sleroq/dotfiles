# ast-grep maintenance

Build the Svelte parser with `-fno-strict-aliasing`; otherwise loading the shared config can crash, even with `ast-grep --version`.

ast-grep 0.51 and later ignore native custom languages by default. After reviewing the config and parser libraries, pass `--custom-languages allow` to load them for each invocation. Older versions do not accept this option. Configure editors with `ast-grep --custom-languages allow lsp --config <generated-project-config>`: the language server does not discover configs in parent directories.

From this directory, check rules and fixtures with:

```sh
ast-grep --custom-languages allow scan --config ./sgconfig.yml .
ast-grep --custom-languages allow test --config ./sgconfig.yml --skip-snapshot-tests
```

The checkout config needs untracked links at `parsers/tree-sitter-svelte` and `parsers/tree-sitter-zig` pointing to the Nix parser outputs. Do not use this config at the home level; its relative `rules` path would be wrong.

After adding Zig support, existing generated configs require home activation or a profile reinstall—not just updated rules.
