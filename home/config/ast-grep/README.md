# ast-grep maintenance

ast-grep LSP does not discover ancestor configurations. Configure the editor to launch `ast-grep lsp --config <generated-project-config>` rather than replacing the `lsp` subcommand with `--config` alone.

To scan while editing rules in this directory, run `ast-grep scan --config ./sgconfig.yml .` here. The directory-local config is not suitable as the home-level config: its relative `rules` path would resolve against the wrong directory.
