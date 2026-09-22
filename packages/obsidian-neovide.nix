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

    exec neovide --neovim-bin="$nvim_bin" -- "$@"
  '';
}
