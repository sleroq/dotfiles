# Shared ast-grep configuration

This directory contains the shared ast-grep rules used by CLI scans and editor
language servers.

## Installed layout

Home Manager creates two links in `home/modules/ast-grep.nix`:

```text
~/sgconfig.yml
  -> ~/develop/dotfiles/home/config/sgconfig.yml

~/.config/ast-grep
  -> ~/develop/dotfiles/home/config/ast-grep
```

The home-level configuration contains:

```yaml
ruleDirs:
  - .config/ast-grep/rules
```

ast-grep resolves `ruleDirs` relative to the directory containing the discovered
configuration. Since it discovers the configuration as `~/sgconfig.yml`, the
rule directory resolves as follows:

```text
~/sgconfig.yml
  -> ~/.config/ast-grep/rules
  -> ~/develop/dotfiles/home/config/ast-grep/rules
```

This lets `ast-grep scan` and `ast-grep lsp` discover the same rules when they
run from projects below the home directory. For example, Zed starts the language
server in a project such as `~/develop/frg/am`; ast-grep walks its ancestor
directories, finds `~/sgconfig.yml`, and evaluates `files` globs relative to the
home directory. A glob such as `develop/**/.gitlab-ci.yml` therefore matches
`~/develop/frg/am/worker/.gitlab-ci.yml`.

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
