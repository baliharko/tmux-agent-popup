# Changelog

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
