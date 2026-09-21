# tmux-agent-popup

[![CI](https://github.com/baliharko/tmux-agent-popup/actions/workflows/ci.yml/badge.svg)](https://github.com/baliharko/tmux-agent-popup/actions/workflows/ci.yml)

Open coding agents (Claude Code, Codex, GitHub Copilot CLI, or anything else
you configure) in a large centered tmux popup.

Each agent runs in its own tmux session per project directory. Hide the popup
and the agent keeps working; bring it back and you're where you left off.

Inspired by [craftzdog/tmux-claude-hatch](https://github.com/craftzdog/tmux-claude-hatch).

## Requirements

- tmux 3.4 or newer
- bash (the macOS system bash 3.2 is fine)
- A Powerline or Nerd Font for the chevrons in the titles

## Install

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'baliharko/tmux-agent-popup'
```

Then press `prefix + I`.

Manually:

```sh
git clone https://github.com/baliharko/tmux-agent-popup ~/.tmux/plugins/tmux-agent-popup
```

```tmux
run-shell ~/.tmux/plugins/tmux-agent-popup/agent-popup.tmux
```

## Usage

| Keys       | Action                                           |
| ---------- | ------------------------------------------------ |
| `prefix a` | Toggle the agent popup for the current directory |
| `prefix A` | Pick an agent from the menu                      |

The first time you press `prefix a` in a directory, a menu asks which agent
to start. After that, `prefix a` toggles that agent's popup: press it inside
the popup to hide it (the agent keeps running), and again to bring it back.

To run a different agent in the same directory, press `prefix A`. Agents
already running there are marked with `●`. Once several are running,
`prefix a` reopens the one you used last.

Quitting the agent itself closes the popup and ends its session. `prefix d`
also hides the popup.

## Options

```tmux
set -g @agent_popup_key       'a'        # toggle, after prefix
set -g @agent_popup_menu_key  'A'        # agent menu, after prefix
set -g @agent_popup_root_key  ''         # toggle without prefix, e.g. 'M-a'
set -g @agent_popup_width     '90%'
set -g @agent_popup_height    '90%'
set -g @agent_popup_border    'rounded'  # any popup-border-lines value
set -g @agent_popup_status    'off'      # status bar inside the popup

set -g @agent_popup_claude_cmd  'claude'
set -g @agent_popup_codex_cmd   'codex'
set -g @agent_popup_copilot_cmd 'copilot'
```

`@agent_popup_root_key` binds the toggle without the prefix. The key is then
taken from every program running in tmux, so pick one you don't use. On macOS,
`M-` keys need your terminal to send Option as Alt.

Commands can include arguments or wrappers:

```tmux
set -g @agent_popup_claude_cmd 'claude --dangerously-skip-permissions'
```

The border and menu colours follow tmux's own `popup-border-style`,
`menu-style` and `menu-selected-style`.

## Adding an agent

List it in `@agent_popup_agents`. The menu shows agents in this order:

```tmux
set -g @agent_popup_agents 'claude codex copilot opencode'
set -g @agent_popup_opencode_cmd   'opencode'  # defaults to the agent name
set -g @agent_popup_opencode_label 'OpenCode'  # menu and title; defaults to the name
```

The same `_cmd` and `_label` options override the built-in agents.

## Notes

- Agent sessions are named `agent-<agent>-<directory>-<hash>` and appear in
  `prefix s` like any other session. If you switch to one there, `prefix a`
  won't detach your terminal; switch back with `prefix s` or `prefix (`.
- Agents are started by the tmux server, so they get the environment tmux was
  started with, not your pane's. For per-project environments, wrap the
  command: `'direnv exec . claude'` or `'mise exec -- claude'`.
- If an agent exits as soon as it starts (a typo in a flag, say), you get a
  message instead of a popup. Run the command in a shell to see its error.
- Keep API keys out of the `_cmd` options: tmux options are readable by
  anything that can talk to your tmux server. Let the agents read keys from
  their usual config or environment.
- `destroy-unattached on` destroys agent sessions as soon as they are
  created, so the plugin can't work with it.

## Development

The end-to-end tests start a private tmux server, attach a real client on a
pty and drive it with key presses, using stand-in commands instead of real
agents:

```sh
python3 -m pip install pyte
tests/run
```

## License

MIT
