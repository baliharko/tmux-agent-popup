# Changelog

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
