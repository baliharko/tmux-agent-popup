"""Cursor regressions: python3 tests/cursor.py (integration needs pyte)."""
import importlib.util
import os
from pathlib import Path
import pty
import select
import shlex
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
RELAY = ROOT / "scripts/popup-client.py"
spec = importlib.util.spec_from_file_location("popup_client", RELAY)
relay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(relay)
HIDE, SHOW = relay.CursorFrames.hide, relay.CursorFrames.show
BEGIN, END = b"\x1b[?2026h", b"\x1b[?2026l"


class FramesTest(unittest.TestCase):
    def test_split_frames_hide_until_cursor_is_restored(self):
        frames = relay.CursorFrames()
        self.assertEqual(frames.feed(BEGIN + b"\x1b[8;20Hpaint"),
                         HIDE + b"\x1b[8;20Hpaint")
        self.assertEqual(frames.feed(SHOW + b"more"), b"more")
        self.assertEqual(frames.feed(b"\x1b[2;3H" + END),
                         b"\x1b[2;3H" + SHOW)

    def test_agent_can_leave_cursor_hidden(self):
        frames = relay.CursorFrames()
        self.assertEqual(frames.feed(BEGIN + HIDE + b"work" + END),
                         HIDE + b"work" + HIDE)
        self.assertEqual(frames.feed(SHOW), SHOW)

    def test_every_byte_boundary(self):
        data = (SHOW + BEGIN + b"\x1b[1;1H" + SHOW + b"paint" + HIDE +
                b"\x1b[2;3H" + END + SHOW + BEGIN + b"next" + END)
        expected = (SHOW + HIDE + b"\x1b[1;1Hpaint\x1b[2;3H" + HIDE +
                    SHOW + HIDE + b"next" + SHOW)
        for offset in range(len(data) + 1):
            frames = relay.CursorFrames()
            self.assertEqual(frames.feed(data[:offset]) + frames.feed(data[offset:]),
                             expected, offset)
        frames = relay.CursorFrames()
        self.assertEqual(b"".join(frames.feed(bytes([b])) for b in data), expected)

    def test_unrelated_sequences_and_utf8_pass_unchanged(self):
        data = "\x1b[38;2;1;2;3mhello 日本語\x1b]11;?\x1b\\\x1b[?1006h".encode()
        frames = relay.CursorFrames()
        self.assertEqual(b"".join(frames.feed(bytes([b])) for b in data), data)


class PopupTest(unittest.TestCase):
    def test_cursor_during_a_split_frame(self):
        import pyte
        from pty_client import Screen
        import fcntl
        import struct
        import termios

        with tempfile.TemporaryDirectory(prefix="popup-cursor-") as temp:
            tmux = ["tmux", "-S", temp + "/server"]
            env = dict(os.environ, TERM="xterm-256color")
            env.pop("TMUX", None)

            def run(*args):
                return subprocess.run(tmux + list(args), env=env, check=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE)

            fixture = Path(temp) / "draw"
            fixture.write_text(
                "#!" + sys.executable + "\n"
                "import os, tty\n"
                "tty.setraw(0)\n"
                "os.write(1, b'\\x1b[2;3HREADY\\x1b[?25h')\n"
                "os.read(0, 1)\n"
                "os.write(1, b'\\x1b[?2026h\\x1b[8;20HPAINT')\n"
                "os.read(0, 1)\n"
                "os.write(1, b'\\x1b[2;3H\\x1b[?25h\\x1b[?2026lDONE')\n"
                "os.read(0, 1)\n"
            )
            fixture.chmod(0o755)
            run("-f", "/dev/null", "new-session", "-d", "-s", "main",
                "-x", "100", "-y", "30")
            child = None
            master = None
            popup = None
            try:
                child, master = pty.fork()
                if child == 0:
                    fcntl.ioctl(0, termios.TIOCSWINSZ,
                                struct.pack("HHHH", 30, 100, 0, 0))
                    os.execvpe("tmux", tmux + ["attach-session", "-t", "main"], env)
                screen = Screen(100, 30)
                stream = pyte.ByteStream(screen)

                def until(predicate):
                    end = time.monotonic() + 5
                    while time.monotonic() < end:
                        if select.select([master], [], [], 0.02)[0]:
                            stream.feed(os.read(master, 65536))
                        if predicate():
                            return
                    self.fail("timed out waiting for popup output")

                until(lambda: bool(run("list-clients", "-F", "#{client_name}").stdout))
                # Baseline mode proves the assertion detects tmux's ignored
                # synchronized-output boundaries, not just our filter logic.
                command = [str(fixture)] if os.environ.get("CURSOR_BASELINE") else [
                    sys.executable, str(RELAY), str(fixture)]
                popup = subprocess.Popen(tmux + [
                    "display-popup", "-w", "90", "-h", "25", "-E",
                    " ".join(shlex.quote(arg) for arg in command)], env=env)
                until(lambda: "READY" in "\n".join(screen.display))
                self.assertFalse(screen.cursor.hidden)
                os.write(master, b"d")
                until(lambda: "PAINT" in "\n".join(screen.display))
                self.assertTrue(screen.cursor.hidden, "cursor exposed midway through a frame")
                os.write(master, b"f")
                until(lambda: "DONE" in "\n".join(screen.display))
                self.assertFalse(screen.cursor.hidden, "input cursor was not restored")
                os.write(master, b"q")
            finally:
                run("kill-server")
                if popup is not None:
                    popup.wait(timeout=5)
                if master is not None:
                    os.close(master)
                if child:
                    os.waitpid(child, 0)


if __name__ == "__main__":
    unittest.main()
