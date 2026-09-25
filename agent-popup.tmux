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

# Forget the terminal's colours (scripts/probe-colours), so that reloading
# the config picks up a new terminal theme.
tmux set-option -gu @agent_popup_colours \; set-option -gu @agent_popup_palette

# bind_script <table> <key> <script>
bind_script() {
  tmux bind-key -T "$1" "$2" \
    run-shell -b "#{q:@agent_popup_dir}/scripts/$3 #{q:client_name} #{q:pane_id}"
}

bind_script prefix "$(get_option @agent_popup_key a)" toggle
bind_script prefix "$(get_option @agent_popup_menu_key A)" choose-agent
bind_script prefix "$(get_option @agent_popup_picker_key u)" choose-session

# Optional toggle without the prefix, e.g. M-a. Off by default because a
# root key is taken from every program running in tmux.
root_key="$(get_option @agent_popup_root_key '')"
if [ -n "$root_key" ]; then
  bind_script root "$root_key" toggle
fi

# Navigation keys, and c for a new window, pressed inside an agent popup act
# on the window under it: the popup closes and the key does what it normally
# does there. Each key's own binding is copied as-is into the
# agent-popup-keys table (list-keys prints re-sourceable lines, so quoting
# and multi-command bindings survive), and the prefix binding is replaced by
# one that replays the key through that table: straight away in a normal
# pane, via scripts/passthrough in an agent session. Unbound keys are left
# alone. A key wrapped by an earlier load is only wrapped again, so its
# wrapper is this version's.
bindings="$(tmux list-keys -T prefix)"
copied="$(mktemp)"
for key in $(get_option @agent_popup_passthrough_keys '0 1 2 3 4 5 6 7 8 9 c n p l w s ( ) h j k'); do
  line="$(printf '%s\n' "$bindings" |
    awk -v k="$key" '{ i = 2; if ($i == "-r") i++ } $i == "-T" && $(i + 2) == k')"
  case "$line" in
  '') continue ;; # unbound
  *scripts/passthrough*) ;; # wrapped by an earlier load, its own binding copied
  *)
    printf '%s\n' "$line" | sed -E 's/^(bind-key +(-r +)?)-T prefix /\1-T agent-popup-keys /' >"$copied"
    tmux source-file "$copied"
    ;;
  esac
  repeat=()
  case "$line" in 'bind-key -r '*) repeat=(-r) ;; esac
  tmux bind-key ${repeat[@]+"${repeat[@]}"} -T prefix "$key" if-shell -F '#{@agent_popup_agent}' \
    "run-shell -b \"#{q:@agent_popup_dir}/scripts/passthrough #{q:client_name} '$key' #{q:pane_id}\"" \
    "switch-client -T agent-popup-keys ; send-keys -K '$key'"
done
rm -f "$copied"
