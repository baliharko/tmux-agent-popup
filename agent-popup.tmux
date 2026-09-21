#!/usr/bin/env bash
# tmux-agent-popup: open coding agents in a popup, each in its own persistent
# tmux session per project directory.
#
# TPM runs this file on startup. It only installs key bindings; the behaviour
# lives in scripts/.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$DIR/scripts/helpers.sh"

# The agent menu's border and styles need tmux 3.4. #{version} is the
# server's, e.g. "3.3a" or "next-3.6".
version="$(tmux display-message -p '#{version}' | sed 's/[^0-9.]//g')"
case "$version" in
[0-9]*.[0-9]*)
  major="${version%%.*}" minor="${version#*.}"
  if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "${minor%%.*}" -lt 4 ]; }; then
    tmux display-message "tmux-agent-popup needs tmux 3.4 or newer"
    exit 0
  fi
  ;;
esac

# Bindings and menu items find the scripts through this option and quote it
# with #{q:}, so the install path can contain spaces, quotes or #.
tmux set-option -g @agent_popup_dir "$DIR"

# bind_script <table> <key> <script>
bind_script() {
  tmux bind-key -T "$1" "$2" \
    run-shell -b "#{q:@agent_popup_dir}/scripts/$3 #{q:client_name} #{q:pane_id}"
}

bind_script prefix "$(get_option @agent_popup_key a)" toggle
bind_script prefix "$(get_option @agent_popup_menu_key A)" choose-agent

# Optional toggle without the prefix, e.g. M-a. Off by default because a
# root key is taken from every program running in tmux.
root_key="$(get_option @agent_popup_root_key '')"
if [ -n "$root_key" ]; then
  bind_script root "$root_key" toggle
fi
