# Changelog

## Unreleased

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
