{
  writeShellApplication,
  neovide,
}:

writeShellApplication {
  name = "obsidian-neovide";
  runtimeInputs = [ neovide ];
  text = ''
    if [[ "''${1-}" == "-e" ]]; then
      shift
    fi

    if (( $# == 0 )); then
      echo "usage: obsidian-neovide [-e] <nvim> [nvim arguments...]" >&2
      exit 2
    fi

    nvim_bin="$1"
    shift

    # Obsidian's Electron wrapper exports its graphics libraries to child
    # processes. Let Neovide's Nix wrapper provide its matching libraries.
    unset LD_LIBRARY_PATH

    exec neovide --neovim-bin="$nvim_bin" -- "$@"
  '';
}
