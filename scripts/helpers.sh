#!/usr/bin/env bash
# Shared helpers for tmux-agent-popup. Sourced, not executed.

# get_option <name> <default>
# Prints the global tmux option, or <default> when it is unset or empty.
get_option() {
  local value
  value="$(tmux show-option -gqv "$1")"
  printf '%s' "${value:-$2}"
}

# agent_default <agent> <field>
# Built-in defaults. Any agent runs a command of the same name unless
# configured otherwise, and is labelled with its name.
agent_default() {
  case "$1:$2" in
  claude:label) printf 'Claude Code' ;;
  codex:label) printf 'Codex' ;;
  copilot:label) printf 'Copilot' ;;
  *:cmd | *:label) printf '%s' "$1" ;;
  esac
}

# agent_option <agent> <field>
# Reads @agent_popup_<agent>_<field>, falling back to agent_default.
agent_option() {
  get_option "@agent_popup_$1_$2" "$(agent_default "$1" "$2")"
}

# is_popup_client <client>
# True when <client> is the nested client inside one of our popups. tmux
# starts a popup's command itself, and open-agent execs the client there, so
# its parent process is the tmux server.
is_popup_client() {
  local pids
  pids="$(tmux list-clients -F '#{client_name} #{client_pid} #{pid}' |
    awk -v c="$1" '$1 == c { print $2, $3 }')"
  [ -n "$pids" ] && [ "$(ps -o ppid= -p "${pids% *}" | tr -d ' ')" = "${pids#* }" ]
}

# leave_agent_session <client> <pane>
# Returns false unless the key was pressed in an agent session. Inside the
# popup it detaches the popup's client, which closes the popup; the agent keeps
# running. A normal client that switched to the session (e.g. with prefix s)
# only gets a message, since detaching it would drop the terminal out of tmux.
leave_agent_session() {
  [ -n "$(tmux display-message -p -t "$2" '#{@agent_popup_agent}')" ] || return 1
  if is_popup_client "$1"; then
    tmux detach-client -t "$1"
  else
    tmux display-message -c "$1" 'agent-popup: already in an agent session'
  fi
}

# dir_agents <dir>
# Agents with a running session for <dir>, most recently attached first.
dir_agents() {
  tmux list-sessions -F $'#{session_last_attached}\t#{@agent_popup_agent}\t#{@agent_popup_path}' |
    AGENT_DIR="$1" awk -F'\t' '$2 != "" && $3 == ENVIRON["AGENT_DIR"] { print $1 "\t" $2 }' |
    sort -rn | cut -f2
}

# session_name <agent> <dir>
# One session per agent + directory: agent-<agent>-<basename>-<crc of path>.
# The basename is only there for humans. tmux reads . and : in a target as
# window/pane separators, so anything outside [A-Za-z0-9_-] becomes _.
session_name() {
  local base crc
  base="$(printf '%s' "${2##*/}" | LC_ALL=C tr -c 'A-Za-z0-9_-' '_' | cut -c1-24)"
  crc="$(printf '%s' "$2" | cksum)"
  printf 'agent-%s-%s-%08x' "$1" "$base" "${crc%% *}"
}
