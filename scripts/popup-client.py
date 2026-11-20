#!/usr/bin/env python3
"""Keep the cursor hidden while the nested tmux client paints a frame.

Popup input does not implement DEC synchronized output (2026), even on
tmux 3.8. Translate its frame boundaries into cursor visibility instead.
Use a pty so tmux still gets a terminal, including input and resize events.
"""
import errno
import fcntl
import os
import pty
import re
import select
import signal
import sys
import termios
import tty


class CursorFrames:
    # tmux emits these as individual DEC private modes. Keep incomplete
    # sequences between reads: a pty read need not end at a frame boundary.
    pattern = re.compile(rb"\x1b\[\?(2026|25)([hl])")
    hide = b"\x1b[?25l"
    show = b"\x1b[?25h"

    def __init__(self):
        self.pending = b""
        self.visible = True
        self.sync = False

    def feed(self, data):
        data = self.pending + data
        self.pending = b""
        # Only hold back a suffix that could be one of our mode sequences.
        tail = data.rfind(b"\x1b")
        if tail >= 0 and any(seq.startswith(data[tail:]) for seq in (
            b"\x1b[?2026h", b"\x1b[?2026l", self.hide, self.show
        )):
            if not self.pattern.fullmatch(data[tail:]):
                self.pending, data = data[tail:], data[:tail]
        out, start = [], 0
        for match in self.pattern.finditer(data):
            out.append(data[start:match.start()])
            mode, state = match.groups()
            enabled = state == b"h"
            if mode == b"25":
                self.visible = enabled
                if not self.sync:
                    out.append(match.group())
            elif enabled:
                self.sync = True
                out.append(self.hide)
            else:
                self.sync = False
                out.append(self.show if self.visible else self.hide)
            start = match.end()
        out.append(data[start:])
        return b"".join(out)


def write_all(fd, data):
    while data:
        count = os.write(fd, data)
        data = data[count:]


def main():
    original = termios.tcgetattr(0)
    size = fcntl.ioctl(0, termios.TIOCGWINSZ, b"\0" * 8)
    pid, fd = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, size)
        os.environ["AGENT_POPUP_RELAY"] = str(os.getppid())
        os.execv(sys.argv[1], sys.argv[1:])

    def resize(*_):
        fcntl.ioctl(fd, termios.TIOCSWINSZ,
                    fcntl.ioctl(0, termios.TIOCGWINSZ, b"\0" * 8))

    def stop(*_):
        raise SystemExit(0)

    signal.signal(signal.SIGWINCH, resize)
    for sig in (signal.SIGHUP, signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, stop)
    frames = CursorFrames()
    ready_for_input = False
    try:
        # Do not flush keys typed while the popup was opening. tmux flushes
        # its own pty on startup, so hold input until its first output too.
        tty.setraw(0, termios.TCSANOW)
        while True:
            ready, _, _ = select.select([0, fd] if ready_for_input else [fd], [], [])
            if fd in ready:
                try:
                    data = os.read(fd, 65536)
                except OSError as exc:
                    if exc.errno != errno.EIO:
                        raise
                    break
                if not data:
                    break
                write_all(1, frames.feed(data))
                ready_for_input = True
            if 0 in ready:
                data = os.read(0, 65536)
                if not data:
                    break
                write_all(fd, data)
    finally:
        os.close(fd)  # HUP the client; the agent's session keeps running.
        try:
            termios.tcsetattr(0, termios.TCSADRAIN, original)
        except termios.error as exc:
            if exc.args[0] != errno.EIO:  # popup already closed
                raise
        finally:
            _, status = os.waitpid(pid, 0)
    return os.WEXITSTATUS(status) if os.WIFEXITED(status) else 128 + os.WTERMSIG(status)


if __name__ == "__main__":
    sys.exit(main())
