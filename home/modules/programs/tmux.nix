{ ... }:

{
  programs.tmux = {
    enable = true;
    customPaneNavigationAndResize = true;
    keyMode = "vi";
    newSession = true;
    prefix = "C-a";
    terminal = "screen-256color";
    # mouse = true;
    extraConfig = ''
      # Easy config reload
      bind-key R source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded."

      # mouse behavior TODO
      set -g mouse on

      bind-key : command-prompt
      bind-key r refresh-client
      bind-key L clear-history

      bind-key space next-window
      bind-key bspace previous-window
      bind-key enter next-layout

      bind-key C-o rotate-window

      bind-key + select-layout main-horizontal
      bind-key = select-layout main-vertical
      set-window-option -g other-pane-height 25
      set-window-option -g other-pane-width 80

      bind-key a last-pane
      bind-key q display-panes
      bind-key c new-window
      bind-key t next-window
      bind-key T previous-window

      bind-key [ copy-mode
      bind-key ] paste-buffer

      run-shell "tmux setenv -g TMUX_VERSION $(tmux -V | cut -c 6-)"

      # Setup \'v\' to begin selection as in Vim
      # Update default binding of `Enter` to also use copy-pipe
      # bind-key -T copy-mode-vi v send-keys -X begin-selection
      # bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "reattach-to-user-namespace pbcopy"
      # unbind   -T copy-mode-vi Enter
      # bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "reattach-to-user-namespace pbcopy"

      set-window-option -g display-panes-time 1500

      # Status Bar
      set-option -g status-interval 1
      set-option -g status-left \'\'
      set-option -g status-right \'%l:%M%p\'
      set-window-option -g window-status-current-style fg=magenta
      set-option -g status-style fg=default

      # Status Bar solarized-dark (default)
      set-option -g status-style bg=black
      set-option -g pane-active-border-style fg=black
      set-option -g pane-border-style fg=black

      # Status Bar solarized-light
      if-shell "[ \"$COLORFGBG\" = \"11;15\" ]" "set-option -g status-style bg=white"
      if-shell "[ \"$COLORFGBG\" = \"11;15\" ]" "set-option -g pane-active-border-style fg=white"
      if-shell "[ \"$COLORFGBG\" = \"11;15\" ]" "set-option -g pane-border-style fg=white"

      # Set window notifications
      setw -g monitor-activity on
      set  -g visual-activity on

      # Allow the arrow key to be used immediately after changing windows
      set-option -g repeat-time 0
    '';
  };
}
