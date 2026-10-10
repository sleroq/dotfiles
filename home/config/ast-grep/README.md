# ast-grep maintenance

The custom Svelte parser must be built with `-fno-strict-aliasing`: its vendored tree-sitter `Array` macros type-pun through `Array(void)`. With strict aliasing, optimized tag-stack growth can dereference a null pointer while compiling the script injection patterns, crashing even `ast-grep --version` when the shared config is discovered. The parser package's install checks compile and match both script patterns through ast-grep.

ast-grep LSP does not discover ancestor configurations. Configure the editor to launch `ast-grep lsp --config <generated-project-config>` rather than replacing the `lsp` subcommand with `--config` alone.

To scan while editing rules in this directory, run `ast-grep scan --config ./sgconfig.yml .` here. The directory-local config is not suitable as the home-level config: its relative `rules` path would resolve against the wrong directory.
