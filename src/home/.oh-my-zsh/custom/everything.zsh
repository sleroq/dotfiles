# Aliases for sudo
alias sudo='sudo '

# XBPS package manager
alias update='xbps-install -Su'
# alias xi=xbps-install
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
alias e='emacsclient -c --tty --alternate-editor="nvim" %F'

# NeoVim
alias vim=nvim
alias mvin=nvim
alias nivm=nvim

# zoxide
alias cd=z

# Tmux
alias tmux='tmux -f ~/.config/tmux/tmux.conf'
