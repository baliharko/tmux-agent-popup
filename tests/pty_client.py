"""Attach a real tmux client on a pty and drive it from a FIFO.

    pty_client.py <socket-name> <fifo>

Each line written to the FIFO is either typed into the client (Python escapes,
e.g. "\\x02a" for C-b a) or, when it starts with "#snap <file>", dumps the
client's rendered screen to <file>. Output is rendered with pyte, so a
snapshot shows what a terminal would: popups, menus and their titles.

Like a real terminal, it answers queries for its default colours (OSC 10 and
11) and its palette (OSC 4), with FG, BG and PALETTE below.
"""
import codecs
import fcntl
import re
import os
import pty
import select
import struct
import sys
import termios

import pyte

ROWS, COLS = 30, 100
FG, BG = b"rgb:dcdc/d7d7/baba", b"rgb:1f1f/1f1f/2828"
# Colour n is rgb:1n/2n/3n in hex, e.g. 1a2a3a for 10.
PALETTE = [b"rgb:1%x1%x/2%x2%x/3%x3%x" % ((n,) * 6) for n in range(16)]
COLOUR_QUERY = re.compile(rb"\033\](1[01]|4;(\d+));\?(\007|\033\\)")


class Screen(pyte.Screen):
    # tmux sends terminal queries pyte can't answer; ignore them.
    def report_device_status(self, *args, **kwargs):
        pass

    def report_device_attributes(self, *args, **kwargs):
        pass


def main():
    sock, fifo = sys.argv[1], sys.argv[2]
    pid, fd = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        os.environ.pop("TMUX", None)
        os.environ["TERM"] = "xterm-256color"
        os.environ["LANG"] = "en_US.UTF-8"
        # -u: CI runners may lack the locale, and the titles need UTF-8.
        os.execvp("tmux", ["tmux", "-u", "-L", sock, "attach-session", "-t", "main"])

    screen = Screen(COLS, ROWS)
    stream = pyte.ByteStream(screen)
    # O_RDWR keeps the FIFO open when writers come and go.
    ctl = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
    buf = b""
    seen = b""  # the end of the output, in case a query is split across reads
    while True:
        ready, _, _ = select.select([fd, ctl], [], [])
        if fd in ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            try:
                stream.feed(data)
            except Exception:
                pass
            seen = seen[-64:] + data
            for query in COLOUR_QUERY.finditer(seen):
                if query.group(2) is not None:
                    colour = PALETTE[int(query.group(2)) % 16]
                else:
                    colour = FG if query.group(1) == b"10" else BG
                os.write(fd, b"\033]" + query.group(1) + b";" + colour + query.group(3))
            seen = COLOUR_QUERY.sub(b"", seen)
        if ctl in ready:
            buf += os.read(ctl, 4096)
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.decode()
                if line.startswith("#snap "):
                    path = line[len("#snap "):]
                    with open(path + ".tmp", "w") as out:
                        out.write("\n".join(row.rstrip() for row in screen.display) + "\n")
                    os.rename(path + ".tmp", path)
                else:
                    keys = codecs.decode(line, "unicode_escape").encode("latin-1")
                    os.write(fd, keys)


if __name__ == "__main__":
    main()
