# Aliases for sudo
alias sudo='sudo '

# local path
path+=("$HOME/.local/bin")

# Scripts
path+=("$HOME/develop/other/dotfiles/scripts")

# XBPS package manager
alias update='xbps-install -Su'
alias xi=xbps-install
alias xq='xbps-query -Rs'
alias xr=xbps-remove

# Nix package manager
nix-sync() {
  nix-env -iA nixpkgs.$1
}

if [ -d $HOME/.nix-profile/etc/profile.d ]; then
  for i in $HOME/.nix-profile/etc/profile.d/*.zsh; do
    if [ -r $i ]; then
      . $i
    fi
  done
fi

# Doom Emacs
path+=("$HOME/.emacs.d/bin")
alias e='emacsclient -c --tty --alternate-editor="nvim" %F'

# NeoVim
alias vim=nvim
alias mvin=nvim
alias nivm=nvim

# zoxide
alias cd=z

# Tmux
alias tmux='tmux -f ~/.config/tmux/tmux.conf'

# Node.js
path+=("$HOME/develop/node.js/bin")
export N_PREFIX=~/develop/node.js

# Golang
export GOPATH=$HOME/develop/go
path+=("$(go env GOPATH)/bin")

# Wayland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland-egl
export ELM_DISPLAY=wl
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=sway

# Services
export SVDIR=~/.config/service

# Safe place
export SAFE_PLACE=/tmp/vault

# Timezone
export TZ=Europe/Moscow
