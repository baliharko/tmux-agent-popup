#!/usr/bin/env python3
"""Isolated subprocess-budget and slow-dependency regression tests."""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PerformanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="agent-popup-perf-")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.env = dict(os.environ, PATH=f"{self.path}:{os.environ['PATH']}",
                        PERF_DIR=str(self.path), PERF_N="0", PERF_AGENT="codex")
        self.env.pop("AGENT_POPUP_CACHE", None)
        self.script("tmux", r'''#!/bin/bash
printf 'tmux %s\n' "$*" >> "$PERF_DIR/calls"
command() {
case "$1" in
list-sessions)
  for ((i=0;i<PERF_N;i++)); do
    printf '%s:agent-%s:0:0:/dev/ttys%s:0::/tmp/project%s\n' "$PERF_AGENT" "$i" "$i" "$i"
  done ;;
list-panes)
  if [ "${PERF_LOOSE:-0}" = 1 ]; then
    printf 'T:/dev/ttys99:%%99:main:0.0::0:0:/tmp/project\n'
  fi ;;
capture-pane) printf '%s\n' "${PERF_SCREEN:-ready}" ;;
display-message)
  value="${!#}"
  case "$value" in
  agent-popup-*) printf '%s\n' "$value" ;;
  *) printf '\n' ;;
  esac ;;
show-option)
  case "$*" in
  *@agent_popup_claude_states) cat "$PERF_DIR/cache" 2>/dev/null ;;
  *@agent_popup_processes) cat "$PERF_DIR/processes" 2>/dev/null ;;
  esac ;;
set-option)
  case "$3" in
  @agent_popup_claude_states) printf '%s' "${4:-}" > "$PERF_DIR/cache" ;;
  @agent_popup_processes) printf '%s' "${4:-}" > "$PERF_DIR/processes" ;;
  esac ;;
esac
}
args=()
for arg in "$@"; do
  if [ "$arg" = ';' ]; then command "${args[@]}"; args=(); else args+=("$arg"); fi
done
command "${args[@]}"
exit 0
''')
        self.script("ps", '#!/bin/sh\nprintf "ps\\n" >> "$PERF_DIR/calls"\nprintf "ttys99 123 codex\\n"\n')
        self.script("claude", '''#!/bin/sh
printf 'claude\n' >> "$PERF_DIR/calls"
if [ "${PERF_SLOW:-0}" = 1 ]; then exec sleep 30; fi
printf '[]\n'
''')
        # No external jq dependency; these cases use an empty Claude response.
        self.script("jq", '#!/bin/sh\ncat >/dev/null\n')

    def script(self, name, content):
        path = self.path / name
        path.write_text(content)
        path.chmod(0o755)

    def run_picker(self, mode="--status"):
        return subprocess.run([str(ROOT / "scripts/pick-session"), mode],
                              env=self.env, capture_output=True, text=True,
                              check=True, timeout=6).stdout

    def calls(self, prefix):
        return sum(line.startswith(prefix) for line in
                   (self.path / "calls").read_text().splitlines())

    def test_no_claude_lookup_without_claude_agents(self):
        self.assertEqual(self.run_picker(), "")
        self.env["PERF_N"] = "3"
        self.assertIn("3", self.run_picker())
        self.assertEqual(self.calls("claude"), 0)

    def test_cache_shared_between_status_and_picker(self):
        self.env.update(PERF_N="1", PERF_AGENT="claude")
        self.run_picker()
        self.run_picker("--list")
        self.run_picker()
        self.assertEqual(self.calls("claude"), 1)
        (self.path / "cache").write_text("0:")
        self.run_picker()
        self.assertEqual(self.calls("claude"), 2)

    def test_tmux_connections_do_not_grow_with_agent_count(self):
        for mode in ("--status", "--list"):
            counts = []
            for count in (1, 10, 50):
                (self.path / "calls").write_text("")
                self.env["PERF_N"] = str(count)
                self.run_picker(mode)
                counts.append(self.calls("tmux"))
            self.assertEqual(counts, [counts[0]] * 3)
            self.assertLessEqual(counts[0], 5)
        self.assertEqual(self.calls("ps"), 0)

    def test_process_scan_is_cached_and_expired(self):
        self.env["PERF_LOOSE"] = "1"
        self.run_picker()
        self.run_picker()
        self.assertEqual(self.calls("ps"), 1)
        (self.path / "processes").write_text("0:\n")
        self.run_picker()
        self.assertEqual(self.calls("ps"), 2)

    def test_batched_screen_states_use_last_eight_nonblank_lines(self):
        self.env.update(PERF_N="3", PERF_SCREEN="esc to interrupt")
        self.assertIn("fg=yellow", self.run_picker())
        self.env["PERF_SCREEN"] = "esc to interrupt\nesc to cancel"
        self.assertIn("fg=red", self.run_picker())
        self.env["PERF_SCREEN"] = "esc to interrupt\n" + "ready\n" * 8
        self.assertIn("fg=green", self.run_picker())

    def test_slow_claude_is_bounded_and_failure_cached(self):
        self.env.update(PERF_N="1", PERF_AGENT="claude", PERF_SLOW="1")
        start = time.monotonic()
        self.assertIn("1", self.run_picker())
        self.assertLess(time.monotonic() - start, 4)
        self.run_picker()
        self.assertEqual(self.calls("claude"), 1)


if __name__ == "__main__":
    unittest.main()
