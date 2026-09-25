# Changelog

## Unreleased

- Agents on a local model: with [ollama](https://ollama.com) installed,
  the `prefix A` menu ends with **Local model ›**, which asks for the agent
  (Claude Code, Codex, Copilot or OpenCode) and then one of the models
  you've downloaded, the one used last first. It starts with `ollama launch
  <agent> --model <model>`, in a session of its own, so it runs next to
  the agent's usual one. Popups, the menus and the picker show the model.
  `@agent_popup_local_agents` and `@agent_popup_local_cmd` change which
  agents are offered and how they start.
- The agent menu takes `h`/`l` and the left and right arrows: `l` or `→`
  picks the highlighted item, like `enter`, and `h` or `←` goes back to the
  menu before, on the item you came from (or closes the first menu). The
  menus are now the plugin's own, drawn in a popup as tmux draws its menus,
  since tmux's menus can't be given keys; numbers, `j`/`k`, the up and down
  arrows, `esc` and mouse clicks work as before, and the colours still
  follow `menu-style` and `menu-selected-style`. They also come up
  quicker, so that keys typed in one go, like `prefix A 5 3 1`, reach each
  menu in turn instead of the pane underneath.

- Keys pressed in an agent popup act on the terminal it's shown on, also
  when two terminals on one session show the agent at once (a second
  window, or Ghostty's quick terminal): `prefix u` and the navigation keys
  went to whichever terminal had opened it last. Each popup now notes its
  own terminal. Popups already open when you update close on the first
  such key.

- The picker's nav mode shows just the agents and the keys: the input
  line comes up only with `/` (fzf 0.59 and later), so other letters no
  longer start a search. A filter kept after `esc` shows in the key hints.
  In search mode the count sits at the end of the input line instead of on
  a line of its own; fzf's gutter left of the rows is blank instead of a
  dark bar, and the current row is highlighted across its whole width.
- `@agent_popup_transparent on` leaves agent panes' background to the
  terminal, for a see-through one: filled with the terminal's background
  colour, they came out solid. Agents asking for the background still get
  the terminal's, from the plugin rather than tmux (with perl), so Copilot
  keeps its theme and markdown styling, and Codex its shaded prompt.
- `prefix c` inside a popup closes it and opens the new window under it,
  as `prefix n` moves there, instead of adding a window to the agent's
  session. `c` is now in `@agent_popup_passthrough_keys` by default.
- Popups and the agent menu have a green frame: the terminal's green,
  title included. `@agent_popup_border_style` sets another style, or
  `default` for tmux's own `popup-border-style` and `menu-border-style`.
- `scripts/status` summarises the agents for the tmux status line: a red,
  yellow and green light (waiting, working, idle) with a count for each,
  or nothing when none runs.
- The picker's preview redraws ten times a second instead of once, so an
  agent's output streams in as it types. The list still updates every
  second.
- `prefix u` inside an agent popup goes straight to the picker instead of
  only closing the popup.
- The picker marks agents that need you as **waiting**: Claude Code's own
  status (through `claude agents`, with jq), or a terminal bell rung since
  you last looked at the agent. No notifications.
- OpenCode is one of the built-in agents.
- The picker opens about three times faster: it no longer builds the list
  twice, asks Claude Code for its status in parallel, and shows the list
  before Claude's status is in.
- The preview shows agents as their popup does, background colours
  included. Before, an agent that paints its own background (OpenCode)
  came out patchy, and Copilot's text field had a dark middle: the rows
  lost the spaces at their ends, and with them their background.
- Fixed: agents in the popup looked flat. They ask the terminal for its
  colours to shade their screens, which nothing answered in a popup; the
  plugin now learns the terminal's colours and hands them to agent panes.
  On tmux 3.6 and later also its palette, which Copilot takes its accent
  colours from.
- Fixed: the picker's preview was a few columns narrower than the agent's
  popup, so it cut off the right edge of the agent's screen; and newer fzf
  put its scroll position over the end of the first row.
- Fixed: an agent opened from the picker kept the picker's title, "Agents".
  It now gets a popup of its own, titled with its name, as with `prefix a`.
- Fixed: Copilot was shown as idle while working; its hint reads "esc
  interrupt", without "to".
- Fixed: Copilot and Codex were shown as working while they asked for your
  approval or asked you a question: the "esc to cancel" under the prompt
  counted as offering to interrupt them. A prompt like that now marks them
  waiting, in red.
- Fixed: the picker could list a phantom agent for a dead pane (kept by
  `remain-on-exit`), whose old tty had been given to another program.
- Fixed: `ctrl-x` in the picker could leave an agent running with no window
  when it ignored the hang-up tmux sends as the session closes. Its process
  now also gets a SIGTERM.

## 0.2.0

- `prefix u` opens a session picker: every running agent in fzf, with a live
  preview of its screen. It includes agents started by hand in ordinary
  panes. The list and preview update every second, and agents showing "esc to
  interrupt" are marked working. `enter` opens one, `ctrl-x` kills it.
- The picker opens in a nav mode: `j`/`k` move, `l` opens, `h`/`q` close,
  `/` or any other key searches (fzf 0.46 or newer).
- Window and pane keys pressed inside an agent popup (`prefix n`, `prefix 3`,
  ...) close it and act on the window underneath, using your own bindings.

## 0.1.0

First release.

- `prefix a` toggles an agent popup for the current directory. The first time,
  a menu asks which agent to start; after that the same key shows and hides
  it, and the agent keeps running while hidden.
- `prefix A` opens the agent menu to start or switch to another agent.
  Agents already running in the directory are marked.
- Optional prefix-less toggle key (`@agent_popup_root_key`).
- Claude Code, Codex and GitHub Copilot CLI out of the box; any other agent
  through `@agent_popup_agents`.
- Configurable commands, labels, popup size, border and status bar.
