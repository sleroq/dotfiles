# Shared ast-grep configuration

This directory contains the shared ast-grep rules used by CLI scans and editor
language servers.

## Installed layout

Home Manager installs the rule directory and links two entry-point configurations
in `home/modules/ast-grep.nix`:

```text
~/sgconfig.yml
  -> ~/develop/dotfiles/home/config/sgconfig.yml

~/.config/ast-grep
  -> ~/develop/dotfiles/home/config/ast-grep

~/develop/frg/sgconfig.yml
  -> ~/develop/dotfiles/home/config/ast-grep/sgconfig-frg.yml
```

The home-level configuration is the common-rules entry point:

```yaml
ruleDirs:
  - .config/ast-grep/rules
```

ast-grep resolves `ruleDirs` relative to the directory containing the discovered
configuration. Since it discovers the configuration as `~/sgconfig.yml`, the
rule directory resolves as follows:

```text
~/sgconfig.yml
  -> ~/.config/ast-grep/rules/common
  -> ~/develop/dotfiles/home/config/ast-grep/rules/common
```

The FRG configuration is an aggregate entry point containing both common and
FRG-specific rules:

```yaml
ruleDirs:
  - rules/common
  - rules/frg
```

Those paths are relative to its real installed location,
`~/.config/ast-grep/sgconfig-frg.yml`. CLI scans can select it explicitly with
`--config ~/.config/ast-grep/sgconfig-frg.yml`.

ast-grep LSP does not walk ancestor directories to find `sgconfig.yml`. Zed (or
another project's LSP configuration) must explicitly start it with the aggregate
configuration, retaining the `lsp` subcommand when replacing the default
arguments:

```json
{
  "lsp": {
    "ast-grep": {
      "binary": {
        "arguments": ["lsp", "--config", "/Users/sleroq/.config/ast-grep/sgconfig-frg.yml"]
      }
    }
  }
}
```

## Directory-local configuration

This directory also has its own `sgconfig.yml`:

```yaml
ruleDirs:
  - rules
```

Use that file when running directly against this configuration directory, for
example while maintaining its rules and tests:

```bash
ast-grep scan --config ~/.config/ast-grep/sgconfig.yml .
```

Do not link this directory-local file to `~/sgconfig.yml`. At that visible path,
its relative `rules` entry would resolve to `~/rules`, which does not exist.
