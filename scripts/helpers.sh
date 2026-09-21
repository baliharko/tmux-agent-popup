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
# Built-in defaults for the agents the plugin ships with. Any other agent runs
# a command of the same name, uses its name as the label, and has no key.
agent_default() {
  case "$1:$2" in
  claude:key) printf 'C' ;;
  claude:label) printf 'Claude Code' ;;
  codex:key) printf 'c' ;;
  codex:label) printf 'Codex' ;;
  copilot:key) printf 'g' ;;
  copilot:label) printf 'Copilot' ;;
  *:cmd | *:label) printf '%s' "$1" ;;
  esac
}

# agent_option <agent> <field>
# Reads @agent_popup_<agent>_<field>, falling back to agent_default.
agent_option() {
  get_option "@agent_popup_$1_$2" "$(agent_default "$1" "$2")"
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
