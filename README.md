# tmux-agent-popup

Open coding agents (Claude Code, Codex, GitHub Copilot CLI, or anything else
you configure) in a large centered tmux popup.

Each agent runs in its own tmux session per project directory. Dismiss the
popup and the agent keeps working; open it again from the same directory and
you're back where you left it.

Inspired by [craftzdog/tmux-claude-hatch](https://github.com/craftzdog/tmux-claude-hatch).

## Requirements

- tmux 3.3 or newer
- bash

## Install

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin '<you>/tmux-agent-popup'
```

Then press `prefix + I`.

Manually:

```tmux
run-shell ~/path/to/tmux-agent-popup/agent-popup.tmux
```

## Usage

| Keys             | Action          |
| ---------------- | --------------- |
| `prefix a C`     | Claude Code     |
| `prefix a c`     | Codex           |
| `prefix a g`     | Copilot         |

The popup opens in the current pane's directory.

- **Dismiss:** press the same keys again inside the popup, or `prefix d`. The
  agent keeps running.
- **Reopen:** press the keys again from the same directory.
- **Quit:** exit the agent itself. The popup closes and its session ends.

## Options

```tmux
set -g @agent_popup_key     'a'        # key after prefix that opens the agent table
set -g @agent_popup_width   '90%'
set -g @agent_popup_height  '90%'
set -g @agent_popup_border  'rounded'  # any popup-border-lines value
set -g @agent_popup_status  'off'      # status bar inside the popup

set -g @agent_popup_claude_cmd  'claude'
set -g @agent_popup_codex_cmd   'codex'
set -g @agent_popup_copilot_cmd 'copilot'
```

Commands can include arguments or wrappers:

```tmux
set -g @agent_popup_claude_cmd 'claude --dangerously-skip-permissions'
```

The border colour follows tmux's own `popup-border-style`.

## Adding an agent

List it in `@agent_popup_agents` and give it a key:

```tmux
set -g @agent_popup_agents 'claude codex copilot opencode'
set -g @agent_popup_opencode_key   'o'
set -g @agent_popup_opencode_cmd   'opencode'  # defaults to the agent name
set -g @agent_popup_opencode_label 'OpenCode'  # popup title; defaults to the name
```

The same `_key`, `_cmd` and `_label` options override the built-in agents.

## Binding keys directly

To skip the `prefix a` table, bind `open-agent` yourself (adjust the path to
where the plugin is installed):

```tmux
bind C run-shell -b '~/.tmux/plugins/tmux-agent-popup/scripts/open-agent claude #{q:client_name} #{q:pane_id}'
```

The toggle still works: the same key dismisses the popup.

## Notes

- Sessions are named `agent-<agent>-<directory>-<hash>` and appear in
  `prefix s` like any other session.
- Agents are started by the tmux server, so they get the environment tmux was
  started with, not your pane's. For per-project environments, wrap the
  command: `'direnv exec . claude'` or `'mise exec -- claude'`.
- `destroy-unattached on` destroys agent sessions as soon as they are
  created, so the plugin can't work with it.
