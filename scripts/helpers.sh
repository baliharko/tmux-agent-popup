#!/usr/bin/env bash
# Shared helpers for tmux-agent-popup. Sourced, not executed.

# get_option <name> <default>
# Prints the global tmux option, or <default> when it is unset or empty.
get_option() {
  option_value "$1"
  printf '%s' "${VALUE:-$2}"
}

# option_value <name>
# Sets VALUE to the global tmux option, without a tmux call for one kept by
# keep_option: for the menus, where the time each call takes shows. Kept
# options are in variables named after them, OPT with @ as _a_ and - as _h_.
option_value() {
  local var="${1//-/_h_}"
  var="OPT${var//@/_a_}"
  if eval "[ -n \"\${$var+x}\" ]"; then
    VALUE="${!var}"
  else
    VALUE="$(tmux show-option -gqv "$1")"
  fi
}

# keep_option <name> <value>: for option_value.
keep_option() {
  local var="${1//-/_h_}"
  eval "OPT${var//@/_a_}=\$2"
}

# load_options <name>...
# Reads these options in one tmux call, as the format #{<name>} (the global
# value, unless a session or window has its own), and keeps them.
load_options() {
  local cmds=() name value
  for name in "$@"; do
    [ "${#cmds[@]}" -eq 0 ] || cmds+=(\;)
    cmds+=(display-message -p "#{$name}")
  done
  [ "${#cmds[@]}" -gt 0 ] || return 0
  while [ "$#" -gt 0 ] && IFS= read -r value; do
    keep_option "$1" "$value"
    shift
  done < <(tmux "${cmds[@]}")
}

# agent_default <agent> <field>
# Sets DEFAULT to the built-in default. Any agent runs a command of the same
# name unless configured otherwise, and is labelled with its name.
agent_default() {
  case "$1:$2" in
  claude:label) DEFAULT='Claude Code' ;;
  codex:label) DEFAULT='Codex' ;;
  copilot:label) DEFAULT='Copilot' ;;
  opencode:label) DEFAULT='OpenCode' ;;
  *:cmd | *:label) DEFAULT="$1" ;;
  *) DEFAULT='' ;;
  esac
}

# agent_option <agent> <field>
# Reads @agent_popup_<agent>_<field>, falling back to agent_default.
agent_option() {
  local DEFAULT
  agent_default "$1" "$2"
  get_option "@agent_popup_$1_$2" "$DEFAULT"
}

# agent_label <agent> [<model>]
# An agent's name for titles and messages. <agent> can be one on a local
# model ("copilot+local", see local_agents), which is named after its own
# agent and the model: "Copilot · qwen3".
agent_label() {
  local label
  label="$(agent_option "${1%+local}" label)"
  printf '%s' "$label${2:+ · $2}"
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

# local_agents
# The agents offered on a local model, one per line: the names in
# @agent_popup_local_agents, or else the configured agents that
# `ollama launch` can start. Such an agent runs as "<agent>+local", in a
# session of its own next to the agent's usual one.
local_agents() {
  local agent list
  list="$(get_option @agent_popup_local_agents '')"
  if [ -z "$list" ]; then
    for agent in $(configured_agents); do
      case "$agent" in
      claude | codex | copilot | opencode) list="$list $agent" ;;
      esac
    done
  fi
  for agent in $list; do
    case "$agent" in
    *[!A-Za-z0-9_-]*) continue ;;
    esac
    printf '%s\n' "$agent"
  done
}

# is_popup_client <client>
# True when <client> is the nested client inside one of our popups. tmux
# starts a popup's command itself, and attach-agent execs the client there, so
# its parent process is the tmux server.
is_popup_client() {
  local pids
  pids="$(tmux list-clients -F '#{client_name} #{client_pid} #{pid}' |
    awk -v c="$1" '$1 == c { print $2, $3 }')"
  [ -n "$pids" ] && [ "$(ps -o ppid= -p "${pids% *}" | tr -d ' ')" = "${pids#* }" ]
}

# popup_host <client> <pane>
# The client that the agent popup whose own client is <client> is shown on,
# as the popup noted when it opened (attach-agent); <pane> is the agent's.
# Nothing for a popup opened by an older version.
popup_host() {
  tmux display-message -p -t "$2" "#{@agent_popup_host_$1}"
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
# last. Other sessions give lines with no agent, which this leaves out.
AGENT_SESSIONS_FORMAT='#{@agent_popup_agent}:#{session_name}:#{?session_last_attached,#{session_last_attached},0}:#{session_attached}:#{pane_tty}:#{window_bell_flag}:#{@agent_popup_path}'
agent_sessions() {
  tmux list-sessions -F "$AGENT_SESSIONS_FORMAT" | awk -F: '$1 != ""'
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

# colour_sgr <30|40> <colour>
# Sets SGR to a tmux colour as SGR parameters, for the foreground (30) or
# background (40): by name, number (colour0 to colour255) or #rrggbb.
# Anything else is the terminal's default.
colour_sgr() {
  local base="$1" colour="$2" name i=0
  case "$colour" in
  bright*)
    base=$((base + 60))
    colour="${colour#bright}"
    ;;
  esac
  for name in black red green yellow blue magenta cyan white; do
    if [ "$colour" = "$name" ]; then
      SGR=$((base + i))
      return
    fi
    i=$((i + 1))
  done
  case "$colour" in
  colour[0-9]* | color[0-9]*) SGR="$(($1 + 8));5;${colour#colo*r}" ;;
  '#'[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
    SGR="$(($1 + 8));2;$((16#${colour:1:2}));$((16#${colour:3:2}));$((16#${colour:5:2}))"
    ;;
  *) SGR=$(($1 + 9)) ;;
  esac
}

# style_sgr <style>
# A tmux style as SGR parameters, e.g. "bg=yellow,fg=black" as "43;30": its
# colours and attributes. Reverse video for a style with neither, so that
# something shows.
style_sgr() {
  local part sgr='' IFS=', ' SGR
  for part in $1; do
    case "$part" in
    fg=*) colour_sgr 30 "${part#fg=}" && sgr="$sgr;$SGR" ;;
    bg=*) colour_sgr 40 "${part#bg=}" && sgr="$sgr;$SGR" ;;
    bold | bright) sgr="$sgr;1" ;;
    dim) sgr="$sgr;2" ;;
    italics) sgr="$sgr;3" ;;
    underscore) sgr="$sgr;4" ;;
    blink) sgr="$sgr;5" ;;
    reverse) sgr="$sgr;7" ;;
    hidden) sgr="$sgr;8" ;;
    strikethrough) sgr="$sgr;9" ;;
    esac
  done
  sgr="${sgr#;}"
  printf '%s' "${sgr:-7}"
}

# text_width <text>
# Sets WIDTH to how wide <text> is on screen: without colours (ANSI codes),
# and a column a character, however many bytes it takes (UTF-8's
# continuation bytes are \200 to \277). Without a process, for the menus.
text_width() {
  local LC_ALL=C text="$1" before after
  while [[ "$text" == *$'\033['* ]]; do
    before="${text%%$'\033['*}" after="${text#*$'\033['}"
    text="$before${after#*m}"
  done
  text="${text//[$'\200'-$'\277']/}"
  WIDTH="${#text}"
}

# show_menu <client> <title> <start> [<key> <label>]...
# A menu in a popup in the middle of the screen, framed like the agents'
# popups and laid out like tmux's menus, run by the menu script next to this
# file (see there for its keys). A label can have colours (ANSI codes), and
# <key> picks it; an item with the key - and no label is a separator. The
# highlight starts on item <start>, from 0. The colours follow tmux's
# menu-style and menu-selected-style, and with @agent_popup_border_style
# "default" the frame menu-border-style. Blocks until it closes, then sets
# MENU_CHOICE to the number of the item picked, "back", or nothing if it
# was closed. The terminal's size and the highlight's colours are kept, for
# the next menu, in MENU_SIZE and MENU_SGR.
show_menu() {
  local client="$1" title="$2" start="$3" keys=() labels=() widths=() width=0 hints=0
  local i inner hint pad row cols rows file frame border style sep='' WIDTH VALUE
  shift 3
  MENU_CHOICE=''
  while [ "$#" -ge 2 ]; do
    keys+=("$1")
    labels+=("$2")
    shift 2
  done
  [ "${#labels[@]}" -gt 0 ] || return 0
  for i in "${!labels[@]}"; do
    text_width "${labels[i]}"
    widths+=("$WIDTH")
    [ "$WIDTH" -le "$width" ] || width="$WIDTH"
    case "${keys[i]}" in
    '' | -) ;;
    *) hints=1 ;;
    esac
  done
  # As tmux lays them out: a space, the label, and the key in brackets.
  inner=$((width + 2 + hints * 4))
  file="$(mktemp)"
  for i in "${!labels[@]}"; do
    if [ "${keys[i]}" = - ]; then
      if [ -z "$sep" ]; then
        printf -v sep '%*s' "$inner" ''
        sep="${sep// /─}"
      fi
      row="$sep"
    else
      hint=''
      if [ "$hints" = 1 ]; then
        if [ -n "${keys[i]}" ]; then hint=" (${keys[i]})"; else hint='    '; fi
      fi
      printf -v pad '%*s' $((width - widths[i])) ''
      row=" ${labels[i]}$pad$hint "
    fi
    printf '%s\037%s\n' "${keys[i]}" "$row"
  done >"$file"
  # tmux refuses a popup bigger than the terminal; the menu then scrolls.
  [ -n "${MENU_SIZE:-}" ] ||
    MENU_SIZE="$(tmux display-message -p -c "$client" '#{client_width} #{client_height}')"
  [ -n "${MENU_SGR:-}" ] || MENU_SGR="$(style_sgr "$(get_option menu-selected-style '')")"
  cols="${MENU_SIZE% *}" rows="${MENU_SIZE#* }"
  option_value @agent_popup_border_style
  frame="${VALUE:-fg=green}" # as border_style
  if [ "$frame" = default ]; then
    option_value menu-border-style
    frame="$VALUE"
  fi
  option_value @agent_popup_border
  border="${VALUE:-rounded}"
  option_value menu-style
  style="${VALUE:-default}"
  # shellcheck disable=SC2016 # expanded by the popup's shell
  tmux display-popup -c "$client" \
    -w "$((inner + 2 > cols ? cols : inner + 2))" \
    -h "$((${#labels[@]} + 2 > rows ? rows : ${#labels[@]} + 2))" \
    -b "$border" -s "$style" -S "${frame:-default}" \
    -T "$(titled "$title")" \
    -e "AGENT_POPUP_MENU_SCRIPT=${BASH_SOURCE[0]%/*}/menu" \
    -e "AGENT_POPUP_MENU=$file" -e "AGENT_POPUP_MENU_START=$start" \
    -e "AGENT_POPUP_MENU_SELECTED=$MENU_SGR" \
    -E 'exec "$AGENT_POPUP_MENU_SCRIPT"' || :
  # shellcheck disable=SC2034 # for the caller
  [ ! -f "$file.choice" ] || IFS= read -r MENU_CHOICE <"$file.choice"
  rm -f "$file" "$file.choice"
}

# show_agent_popup <client> <session> <title>
# An agent's <session> in a popup on <client>, attached by attach-agent, next
# to this file. Blocks until it closes. The popup's command finds the script
# through the environment, so the install path needs no quoting for whatever
# shell runs it.
show_agent_popup() {
  # shellcheck disable=SC2016 # expanded by the popup's shell
  show_popup "$1" "$3" -e "AGENT_POPUP_ATTACH=$(dirname "${BASH_SOURCE[0]}")/attach-agent" \
    -e "AGENT_POPUP_SESSION=$2" -e "AGENT_POPUP_HOST=$1" -E 'exec "$AGENT_POPUP_ATTACH"'
}

# session_name <agent> <dir>
# One session per agent + directory: agent-<agent>-<basename>-<crc of path>,
# where <agent> can be one on a local model, e.g. "copilot+local". The
# basename is only there for humans. tmux reads . and : in a target as
# window/pane separators, so anything outside [A-Za-z0-9_-] becomes _.
session_name() {
  local base crc
  base="$(printf '%s' "${2##*/}" | LC_ALL=C tr -c 'A-Za-z0-9_-' '_' | cut -c1-24)"
  crc="$(printf '%s' "$2" | cksum)"
  printf 'agent-%s-%s-%08x' "$1" "$base" "${crc%% *}"
}
