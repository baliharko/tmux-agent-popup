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
case "$1" in
list-sessions)
  for ((i=0;i<PERF_N;i++)); do
    printf '%s:agent-%s:0:0:/dev/ttys%s:0::/tmp/project%s\n' "$PERF_AGENT" "$i" "$i" "$i"
  done ;;
capture-pane) printf 'ready\n' ;;
show-option)
  case "$*" in
  *@agent_popup_claude_states) cat "$PERF_DIR/cache" 2>/dev/null ;;
  esac ;;
set-option)
  if [ "$3" = @agent_popup_claude_states ]; then printf '%s' "$4" > "$PERF_DIR/cache"; fi ;;
esac
exit 0
''')
        self.script("ps", '#!/bin/sh\nprintf "ps\\n" >> "$PERF_DIR/calls"\n')
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

    def test_slow_claude_is_bounded_and_failure_cached(self):
        self.env.update(PERF_N="1", PERF_AGENT="claude", PERF_SLOW="1")
        start = time.monotonic()
        self.assertIn("1", self.run_picker())
        self.assertLess(time.monotonic() - start, 4)
        self.run_picker()
        self.assertEqual(self.calls("claude"), 1)


if __name__ == "__main__":
    unittest.main()
