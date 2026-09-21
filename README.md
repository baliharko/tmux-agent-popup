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
- [fzf](https://github.com/junegunn/fzf), for the session picker only

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
| `prefix u` | Pick from all running agents, in any directory   |

The first time you press `prefix a` in a directory, a menu asks which agent
to start. After that, `prefix a` toggles that agent's popup: press it inside
the popup to hide it (the agent keeps running), and again to bring it back.

To run a different agent in the same directory, press `prefix A`. Agents
already running there are marked with `●`. Once several are running,
`prefix a` reopens the one you used last.

Quitting the agent itself closes the popup and ends its session. `prefix d`
also hides the popup.

### Session picker

`prefix u` lists every running agent with a live preview of its screen: the
plugin's own sessions, and agents you started yourself in an ordinary pane.
The preview redraws ten times a second, so you can watch an agent work; the
list (and who's working) updates every second. On fzf versions without a
timer (before `every()` was added), both update once a second.

```
● idle     Claude Code  api                  open       ~/dev/api
● working  Codex        web                  0:2.0      ~/dev/web
● idle     Copilot      dotfiles             0:0.0      ~/dotfiles
```

An agent is **working** while the bottom of its screen offers to interrupt
it ("esc to interrupt" or "esc to cancel"), as Claude Code and Codex do
during a turn. The plugin's sessions come first, most recently opened at the
top, then agents in ordinary panes. The order doesn't change as agents start
and stop working, so rows don't move under the cursor.

`open` marks a session shown in a popup right now. `0:2.0` is the pane
(session:window.pane) where an agent you started yourself is running; the
picker finds those by process name, so a process named like one of
`@agent_popup_agents` counts.

The picker opens in **nav** mode:

| Key                  | Action                                                   |
| -------------------- | -------------------------------------------------------- |
| `j` / `k`            | Move down / up                                           |
| `l` / `enter`        | Open the agent: in the popup, or switch to its pane      |
| `h` / `q` / `esc`    | Close the picker                                         |
| `g` / `G`            | First / last agent                                       |
| `/` or any other key | Search                                                   |
| `ctrl-x`             | Kill it: the whole session, or just the agent in a pane  |

In **search** mode every key types into the filter and `enter` opens the
first match. `esc` goes back to nav mode and keeps the filter, so you can
move through the matches with `j` and `k`.

Nav and search mode need fzf 0.46 or newer. With older fzf the picker is a
plain fzf list: type to filter, arrows to move, `enter` to open, `ctrl-x` to
kill, `esc` to close.

A session opens in the picker's popup, so its title reads "Agents" rather
than the agent's name. tmux can't change a popup's title once it's open, and
closing the picker to open a new popup can leave the new one without
keyboard input.

### Moving around with the popup open

Window and pane keys pressed inside the popup act on the window under it:
`prefix n` closes the popup and moves to the next window, `prefix 3` to
window 3. Whatever these keys are bound to in your config still applies. By
default that's `0`–`9` and `n p l w s ( ) h j k`; set
`@agent_popup_passthrough_keys` to change the list. Other keys keep working
inside the popup, e.g. `prefix [` to scroll back through the agent's output.

## Options

```tmux
set -g @agent_popup_key        'a'        # toggle, after prefix
set -g @agent_popup_menu_key   'A'        # agent menu, after prefix
set -g @agent_popup_picker_key 'u'        # session picker, after prefix
set -g @agent_popup_root_key   ''         # toggle without prefix, e.g. 'M-a'
set -g @agent_popup_width      '90%'
set -g @agent_popup_height     '90%'
set -g @agent_popup_border     'rounded'  # any popup-border-lines value
set -g @agent_popup_status     'off'      # status bar inside the popup
set -g @agent_popup_passthrough_keys '0 1 2 3 4 5 6 7 8 9 n p l w s ( ) h j k'

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
agents. They need pyte, and fzf for the picker tests (skipped without it):

```sh
python3 -m pip install pyte
tests/run
```

## License

MIT
