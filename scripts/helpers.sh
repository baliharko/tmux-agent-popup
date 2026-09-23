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
  opencode:label) printf 'OpenCode' ;;
  *:cmd | *:label) printf '%s' "$1" ;;
  esac
}

# agent_option <agent> <field>
# Reads @agent_popup_<agent>_<field>, falling back to agent_default.
agent_option() {
  get_option "@agent_popup_$1_$2" "$(agent_default "$1" "$2")"
}

# configured_agents
# The names in @agent_popup_agents, one per line, skipping any that can't be
# used in option and session names.
configured_agents() {
  local agent
  for agent in $(get_option @agent_popup_agents 'claude codex copilot opencode'); do
    case "$agent" in
    *[!A-Za-z0-9_-]*) continue ;;
    esac
    printf '%s\n' "$agent"
  done
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

# attached_client <name>
# True when a client of that name is attached right now.
attached_client() {
  [ -n "$1" ] && tmux list-clients -F '#{client_name}' | grep -qxF "$1"
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

# agent_sessions
# One line per agent session, fields separated by ":": agent, session, when
# it was last attached (epoch seconds, 0 if never), how many clients are
# attached, the agent's tty, whether it rang the bell since it was last
# looked at (1 or 0), and its directory. The separator has to be printable:
# tmux 3.4 prints control characters in -F output as escapes like \037.
# Agent and session names can't contain ":"; the directory can, so it comes
# last.
agent_sessions() {
  tmux list-sessions -F '#{@agent_popup_agent}:#{session_name}:#{?session_last_attached,#{session_last_attached},0}:#{session_attached}:#{pane_tty}:#{window_bell_flag}:#{@agent_popup_path}' |
    awk -F: '$1 != ""'
}

# dir_agents <dir>
# Agents with a running session for <dir>, most recently attached first.
dir_agents() {
  agent_sessions |
    AGENT_DIR="$1" awk -F: '
      { dir = $0; for (i = 1; i <= 6; i++) sub(/^[^:]*:/, "", dir) }
      dir == ENVIRON["AGENT_DIR"] { print $3 "\t" $1 }' |
    sort -rn | cut -f2
}

# terminal_colours <client>
# The default colours of <client>'s terminal as a tmux style, e.g.
# "fg=#dcd7ba,bg=#1f1f28", or nothing if the terminal doesn't say. Learned,
# with its palette (terminal_palette), by probe-colours (next to this file)
# in a background window of the client's session, and cached in
# @agent_popup_colours and @agent_popup_palette until the plugin is loaded
# again. The window's status-line entry is made blank in the same command
# that creates it, so it never shows.
#
# Only for a terminal that tmux draws RGB colours on: on others tmux would
# round them to the nearest of 256, and the agent's background wouldn't
# match yours.
terminal_colours() {
  local style session features
  style="$(tmux show-option -gqv @agent_popup_colours)"
  if [ -z "$style" ]; then
    read -r session features <<<"$(tmux list-clients -F '#{client_name} #{client_session} #{client_termfeatures}' |
      awk -v c="$1" '$1 == c { print $2, $3; exit }')"
    [ -n "$session" ] || return 0
    case ",$features," in
    *,RGB,*) ;;
    *)
      tmux set-option -g @agent_popup_palette none \; set-option -g @agent_popup_colours none
      return 0
      ;;
    esac
    # shellcheck disable=SC2016 # expanded by the window's shell
    tmux new-window -d -t "=$session:" -n agent-popup-probe \
      -e "AGENT_POPUP_PROBE=$(dirname "${BASH_SOURCE[0]}")/probe-colours" \
      'exec "$AGENT_POPUP_PROBE"' \; \
      set-option -w -t "=${session}:agent-popup-probe" window-status-format '' \; \
      set-option -w -t "=${session}:agent-popup-probe" window-status-current-format ''
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      style="$(tmux show-option -gqv @agent_popup_colours)"
      [ -n "$style" ] && break
      sleep 0.05
    done
  fi
  [ "$style" = none ] || printf '%s' "$style"
}

# terminal_palette
# The terminal's first 16 colours, "#rrggbb" separated by spaces, or nothing
# if it didn't say. Learned by terminal_colours, which has to come first.
terminal_palette() {
  local palette
  palette="$(tmux show-option -gqv @agent_popup_palette)"
  [ "$palette" = none ] || printf '%s' "$palette"
}

# titled <text>
# A popup or menu title: <text> between Powerline thin chevrons (U+E0B3 and
# U+E0B1), as craftzdog's tmux-claude-hatch draws them. Titles are formats,
# so # is doubled.
titled() {
  printf '\356\202\263 %s \356\202\261' "${1//\#/##}"
}

# border_style
# The style of popup and menu frames, titles included. Green by default;
# "default" follows tmux's popup-border-style and menu-border-style.
border_style() {
  get_option @agent_popup_border_style fg=green
}

# show_popup <client> <title> <display-popup args...>
# A popup in the configured size and border. Blocks until it closes.
show_popup() {
  local client="$1" title="$2"
  shift 2
  tmux display-popup -c "$client" \
    -w "$(get_option @agent_popup_width 90%)" \
    -h "$(get_option @agent_popup_height 90%)" \
    -b "$(get_option @agent_popup_border rounded)" \
    -S "$(border_style)" \
    -T "$(titled "$title")" \
    "$@"
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
