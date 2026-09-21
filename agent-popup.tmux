#!/usr/bin/env bash
# tmux-agent-popup: open coding agents in a popup, each in its own persistent
# tmux session per project directory.
#
# TPM runs this file on startup. It only installs key bindings; the behaviour
# lives in scripts/open-agent.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$DIR/scripts/helpers.sh"

# prefix + a enters the agent table; the next key picks the agent. A table
# keeps the per-agent letters off tmux's own bindings (c is new-window, C is
# customize-mode).
table=agent-popup
tmux unbind-key -a -T "$table" 2>/dev/null
tmux bind-key "$(get_option @agent_popup_key a)" switch-client -T "$table"

for agent in $(get_option @agent_popup_agents 'claude codex copilot'); do
  case "$agent" in
  *[!A-Za-z0-9_-]*) continue ;; # the name goes into option and session names
  esac
  key="$(agent_option "$agent" key)"
  [ -n "$key" ] || continue
  tmux bind-key -T "$table" "$key" \
    run-shell -b "'$DIR/scripts/open-agent' $agent #{q:client_name} #{q:pane_id}"
done
