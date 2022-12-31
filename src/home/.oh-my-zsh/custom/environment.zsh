# local path
path+=("$HOME/.local/bin")

# Scripts
path+=("$HOME/develop/other/dotfiles/scripts")

# Doom Emacs
path+=("$HOME/.emacs.d/bin")

# Node.js
path+=("$HOME/develop/node.js/bin")
export N_PREFIX=~/develop/node.js

# Golang
export GOPATH=$HOME/develop/go
path+=("$(go env GOPATH)/bin")

# Wayland
if [[ -z $DESKTOP_SESSION || $XDG_SESSION_TYPE != 'x11' ]]
then
  export MOZ_ENABLE_WAYLAND=1
  export QT_QPA_PLATFORM=wayland-egl
  export ELM_DISPLAY=wl
  export SDL_VIDEODRIVER=wayland
  export _JAVA_AWT_WM_NONREPARENTING=1
  export XDG_CURRENT_DESKTOP=sway
  export XDG_SESSION_DESKTOP=sway
fi

# Services
export SVDIR=~/.config/service

# Safe place
export SAFE_PLACE=/tmp/vault

# Timezone
export TZ=Europe/Moscow

# Qt
export QT_QPA_PLATFORMTHEME=qt5ct

# LeftWM
path+=("$HOME/.config/leftwm/bin")
