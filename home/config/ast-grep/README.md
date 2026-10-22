# ast-grep maintenance

Build the custom Svelte parser with `-fno-strict-aliasing` to avoid crashes in tree-sitter's `Array` macros. Without it, even `ast-grep --version` can crash when loading the shared config. Install checks test both script injection patterns.

Set the editor to run `ast-grep lsp --config <generated-project-config>`. Keep `lsp`: the language server does not find configs in parent directories.

When editing rules here, run `ast-grep scan --config ./sgconfig.yml .` from this directory. Do not use this config at the home level; its relative `rules` path would be wrong.
