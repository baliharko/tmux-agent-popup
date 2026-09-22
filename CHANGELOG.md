# Changelog

## Unreleased

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
- The preview drops the agents' background colours, so an agent that paints
  its own background (OpenCode) doesn't look patchy over yours.
- Fixed: Copilot was shown as idle while working; its hint reads "esc
  interrupt", without "to".
- Fixed: the picker could list a phantom agent for a dead pane (kept by
  `remain-on-exit`), whose old tty had been given to another program.

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
