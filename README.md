# tmux-agent-popup

[![CI](https://github.com/baliharko/tmux-agent-popup/actions/workflows/ci.yml/badge.svg)](https://github.com/baliharko/tmux-agent-popup/actions/workflows/ci.yml)

Open coding agents (Claude Code, Codex, GitHub Copilot CLI, OpenCode, or
anything else you configure) in a large centered tmux popup.

Each agent runs in its own tmux session per project directory. Hide the popup
and the agent keeps working; bring it back and you're where you left off.

Inspired by [craftzdog/tmux-claude-hatch](https://github.com/craftzdog/tmux-claude-hatch).

## Requirements

- tmux 3.4 or newer
- bash (the macOS system bash 3.2 is fine)
- A Powerline or Nerd Font for the chevrons in the titles
- [fzf](https://github.com/junegunn/fzf), for the session picker only (0.46 or
  newer for its j/k navigation)
- [jq](https://jqlang.org), optional, for Claude Code's own status in the
  picker
- perl, for agents' colours with `@agent_popup_transparent on` (macOS and
  most Linux systems come with it)

## Install

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'baliharko/tmux-agent-popup'
```

Then press `prefix + I` to install it. Later, `prefix + U` updates it to the
latest version (both are TPM's own keys).

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

In the menu, press an item's number to pick it, or move with `j`/`k` or the
arrow keys and pick with `l`, `→` or `enter`. `h` or `←` goes back to the
menu before (see Local models), or closes the first one, as `q` and `esc`
do. A mouse click picks too.

### Local models

With [ollama](https://ollama.com) installed, the `prefix A` menu ends with
**Local model ›**, for an agent running on a model on your own machine. It
asks which agent, then which of the models you've downloaded (`ollama
list`), the one you used last first, and starts the agent with `ollama
launch <agent> --model <model>`. `l` and `h` (or the arrow keys) go back
and forth between the three menus, and numbers work in each: with the four
built-in agents, `prefix A 5 3 1` starts Copilot on the first model.

An agent on a local model has a session of its own, so it runs next to the
agent's usual one in the same directory. Its popup is titled with the model
(`Copilot · qwen3.5:35b-a3b-coding-nvfp4`), and the picker shows it after
the agent's name. `prefix a` reopens it like any other agent; to switch
models, quit the agent and pick another. While one runs, the menus mark it
with `●`, and picking it again reopens it without asking for a model.

### Session picker

`prefix u` lists every running agent with a live preview of its screen: the
plugin's own sessions, and agents you started yourself in an ordinary pane.
Pressed inside an agent popup, it swaps the popup for the picker.
The preview redraws ten times a second, so you can watch an agent work; the
list (and who's working) updates every second. The preview shows the agent
as its popup does, colours included, and as wide. On fzf versions without a
timer (before `every()` was added), both update once a second.

```
● waiting  Claude Code  api                  open       ~/dev/api
● working  Codex        web                  0:2.0      ~/dev/web
● idle     Copilot      dotfiles             0:0.0      ~/dotfiles
```

- **waiting**: the agent needs you. Claude Code reports this itself when it
  asks for permission or asks you a question (read through `claude agents`,
  which needs jq). Other agents are waiting while the bottom of their screen
  shows a prompt that esc cancels ("esc to cancel"), as Copilot's and
  Codex's approvals and questions do. Any agent also shows as waiting if it
  rang the terminal bell since you last looked at it; opening it clears
  that. Nothing else happens: no notification, no sound, just the mark in
  the list.
- **working**: Claude Code says it's busy, or the bottom of the agent's
  screen offers to interrupt it ("esc to interrupt" or "esc interrupt"), as
  Claude Code, Codex and Copilot do while they work.
- **idle**: neither; typically finished and ready for your next prompt.

The plugin's sessions come first, most recently opened at the top, then
agents in ordinary panes. The order doesn't change as agents start
and stop working, so rows don't move under the cursor.

`open` marks a session shown in a popup right now. `0:2.0` is the pane
(session:window.pane) where an agent you started yourself is running. The
picker finds those by process name: a process named like one of the agents in
`@agent_popup_agents`, or a node, bun, deno or python script of that name.
An agent whose name differs from its program's isn't found this way.

The picker opens in **nav** mode, which shows just the agents and the keys:

| Key                  | Action                                                   |
| -------------------- | -------------------------------------------------------- |
| `j` / `k`            | Move down / up                                           |
| `l` / `enter`        | Open the agent: in its popup, or switch to its pane      |
| `h` / `q` / `esc`    | Close the picker                                         |
| `g` / `G`            | First / last agent                                       |
| `/`                  | Search                                                   |
| `ctrl-x`             | Kill it: the whole session, or just the agent in a pane  |

In **search** mode an input line comes up: every key types into the filter,
and `enter` opens the highlighted match. `esc` hides the input line and goes
back to nav mode, keeping the filter, so you can move through the matches with
`j` and `k`; the key hints then start with the filter.

Nav and search mode need fzf 0.46 or newer, and hiding the input line in nav
mode 0.59. On fzf 0.46 to 0.58 the input line always shows, and any other
letter also starts a search. With older fzf the picker is a plain fzf list:
type to filter, arrows to move, `enter` to open, `ctrl-x` to kill, `esc` to
close.

A session opens in a popup of its own, titled with the agent's name, in
place of the picker's.

### Status line

`scripts/status` shows how many agents are waiting, working and idle, as
the picker marks them, for your tmux status line: a light in the picker's
colours and a count for each.

```
● 1  ● 2  ● 1        red: waiting · yellow: working · green: idle
```

States with no agents are left out, and with no agents running it prints
nothing. The lights use your terminal's red, yellow and green; the counts
are in the status line's default colour (`fg=default`). Add it to
`status-right`:

```tmux
set -ag status-right ' #(~/.config/tmux/plugins/tmux-agent-popup/scripts/status)'
```

Or, with a theme built on status-line segments, as a custom one. For
[dracula](https://draculatheme.com/tmux) and themes derived from it:

```tmux
set -g @dracula-plugins "custom:$HOME/.config/tmux/plugins/tmux-agent-popup/scripts/status time"
set -g @dracula-show-empty-plugins false  # hide it while no agent runs
set -g @dracula-custom-plugin-colors "dark_gray white"  # lights on a dark background
```

Use your plugin path. tmux reruns the script every `status-interval`
seconds; it takes a fraction of a second, a little longer with Claude Code
running, since it asks Claude Code for its status.

### Moving around with the popup open

Window and pane keys pressed inside the popup act on the window under it:
`prefix n` closes the popup and moves to the next window, `prefix 3` to
window 3, and `prefix c` opens a new window there rather than in the agent's
session. Whatever these keys are bound to in your config still applies, so
a `new-window -c "#{pane_current_path}"` starts in the directory of the pane
under the popup. The keys are `0`–`9` and `c n p l w s ( ) h j k` by
default; set `@agent_popup_passthrough_keys` to change the list. Other keys
keep working inside the popup, e.g. `prefix [` to scroll back through the
agent's output.

## Options

```tmux
set -g @agent_popup_key        'a'        # toggle, after prefix
set -g @agent_popup_menu_key   'A'        # agent menu, after prefix
set -g @agent_popup_picker_key 'u'        # session picker, after prefix
set -g @agent_popup_root_key   ''         # toggle without prefix, e.g. 'M-a'
set -g @agent_popup_width      '90%'
set -g @agent_popup_height     '90%'
set -g @agent_popup_border     'rounded'  # any popup-border-lines value
set -g @agent_popup_border_style 'fg=green' # frame and title colour
set -g @agent_popup_status     'off'      # status bar inside the popup
set -g @agent_popup_transparent 'off'     # 'on' for a see-through terminal
set -g @agent_popup_passthrough_keys '0 1 2 3 4 5 6 7 8 9 c n p l w s ( ) h j k'

set -g @agent_popup_claude_cmd  'claude'
set -g @agent_popup_codex_cmd   'codex'
set -g @agent_popup_copilot_cmd 'copilot'
set -g @agent_popup_opencode_cmd 'opencode'

set -g @agent_popup_local_agents 'claude codex copilot opencode' # under Local model
set -g @agent_popup_local_cmd    'ollama launch'
```

`@agent_popup_root_key` binds the toggle without the prefix. The key is then
taken from every program running in tmux, so pick one you don't use. On macOS,
`M-` keys need your terminal to send Option as Alt.

Commands can include arguments or wrappers:

```tmux
set -g @agent_popup_claude_cmd 'claude --dangerously-skip-permissions'
```

`@agent_popup_local_agents` lists the agents offered under Local model. By
default it's the built-in agents you have in `@agent_popup_agents`, which
`ollama launch` can all start; add others it can launch (e.g. `pi` or
`qwen`) by name. `@agent_popup_local_cmd` is the start of their command,
followed by the agent and `--model <model>`, and takes wrappers like the
others: `'direnv exec . ollama launch'`.

`@agent_popup_transparent` is for a terminal with a see-through background.
Agent panes are filled with your terminal's background colour, so that agents
asking for it get an answer (see Notes), and the terminal draws a filled
background solid. With `on` the background is left to the terminal, and shows
through as elsewhere. tmux can't answer for a background it doesn't draw, so
the plugin answers agents asking for it with your terminal's, and they look
as they do in an ordinary pane. That needs perl; without it they get no
answer and use their own defaults: Copilot falls back to plain colours, and
Codex leaves its prompt unshaded.

The frame of the popups and the agent menu, title included, is in your
terminal's green. `@agent_popup_border_style` takes any tmux style, e.g.
`fg=#7e9cd8`, or `default` to follow tmux's own `popup-border-style` and
`menu-border-style`. The menu's other colours follow `menu-style` and
`menu-selected-style`: the menus are the plugin's own, drawn in a popup
like tmux's menus, since those can't be given keys.

## Adding an agent

List it in `@agent_popup_agents`. The menu shows agents in this order:

```tmux
set -g @agent_popup_agents 'claude codex copilot opencode gemini'
set -g @agent_popup_gemini_cmd   'gemini'  # defaults to the agent name
set -g @agent_popup_gemini_label 'Gemini'  # menu and title; defaults to the name
```

The same `_cmd` and `_label` options override the built-in agents.

## Notes

- Agents ask the terminal for its colours, and some (Copilot) for its
  palette, to fit their screens to it; in a popup the terminal can't answer.
  So the plugin learns your terminal's colours and palette once, with a
  short-lived background window whose status-line entry is blank, and gives
  them to each new agent's pane; agents then look the same as in an ordinary
  pane. The palette needs tmux 3.6 or newer, which is also when tmux started
  passing palette questions on in ordinary panes. Both need a terminal tmux
  draws RGB colours on (the `RGB` terminal feature). Reloading the config
  learns them again, e.g. after changing your terminal's theme. Agents
  already running keep the colours they started with.
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
