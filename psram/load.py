#!/usr/bin/env python3
"""Upload a PSRAM image to the UART bootloader (boot.c) and print the program's output.

The board must be sitting in the bootloader: just flashed, after the reset button,
or after the previous program returned. Output is streamed until the program
returns to the bootloader, or until --timeout seconds pass. Keys typed meanwhile
go to the program; Ctrl-C quits.

With --bundle, the images are stored together in the top 1 MB of PSRAM instead
(until power-off), and the bootloader's menu runs them: this then stays a
terminal until Ctrl-C.
"""
import argparse
import fcntl
import glob
import os
import queue
import re
import select
import struct
import sys
import termios
import threading
import time
import tty

BANNER = b"boot: waiting for image"
BUNDLE_SIZE = 1 << 20                                   # boot.c BUNDLE..BUNDLE_END


def bundle(paths):
    """magic, then per image {len, name[12]} and its bytes padded to 4, then len 0."""
    out = b"BNDL"
    for p in paths:
        img = open(p, "rb").read()
        name = os.path.splitext(os.path.basename(p))[0][:11].encode()
        out += struct.pack("<I12s", len(img), name) + img + bytes(-len(img) % 4)
    out += bytes(4)
    if len(paths) > 9 or len(out) > BUNDLE_SIZE:
        sys.exit("bundle: at most 9 images and 1 MB")
    return out


def find_port():
    """The iCEBreaker UART is interface 1 of its FT2232H (0403:6010); the ttyUSB
    number moves around, e.g. after iceprog re-enumerates the chip."""
    for tty in sorted(glob.glob("/sys/class/tty/ttyUSB*")):
        iface = os.path.dirname(os.path.realpath(os.path.join(tty, "device")))
        usb = os.path.dirname(iface)
        try:
            ids = [open(os.path.join(usb, f)).read().strip() for f in ("idVendor", "idProduct")]
        except OSError:
            continue
        if ids == ["0403", "6010"] and iface.endswith(":1.1"):
            return "/dev/" + os.path.basename(tty)
    sys.exit("iCEBreaker UART not found")


def open_port(dev, baud):
    fd = os.open(dev, os.O_RDWR | os.O_NOCTTY)
    cc = termios.tcgetattr(fd)[6]
    cc[termios.VMIN], cc[termios.VTIME] = 0, 1          # reads return after 0.1 s idle
    cflag = termios.CS8 | termios.CREAD | termios.CLOCAL
    termios.tcsetattr(fd, termios.TCSANOW,
                      [0, 0, cflag, 0, termios.B3000000, termios.B3000000, cc])
    # Any rate via Linux termios2 (BOTHER); the FT2232H driver picks its nearest,
    # 12 MHz / n with n in eighths: 3140625 gives 12 / 3.875 = 3.097 Mbaud.
    TCGETS2, TCSETS2, CBAUD, BOTHER = 0x802C542A, 0x402C542B, 0o10017, 0o10000
    t = bytearray(44)                                   # struct termios2
    fcntl.ioctl(fd, TCGETS2, t)
    struct.pack_into("<I", t, 8, struct.unpack_from("<I", t, 8)[0] & ~CBAUD | BOTHER)
    struct.pack_into("<II", t, 36, baud, baud)          # c_ispeed, c_ospeed
    fcntl.ioctl(fd, TCSETS2, t)
    termios.tcflush(fd, termios.TCIOFLUSH)
    return fd


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("image", nargs="+", help="one image, or several with --bundle")
    ap.add_argument("--bundle", action="store_true", help="store the images for the menu")
    ap.add_argument("--port", help="serial device (default: find the iCEBreaker)")
    ap.add_argument("--baud", type=int, default=3140625, help="the SoC's UART rate (Makefile BAUD)")
    ap.add_argument("--timeout", type=float, default=600, help="seconds to wait for the program")
    args = ap.parse_args()

    if args.bundle:
        img = bundle(args.image)
    elif len(args.image) == 1:
        img = open(args.image[0], "rb").read()
    else:
        sys.exit("several images need --bundle")
    fd = open_port(args.port or find_port(), args.baud)

    os.write(fd, b"\2" if args.bundle else b"\1")    # command, then let boot.c reach rx()
    time.sleep(0.01)
    payload = len(img).to_bytes(4, "little") + img
    while payload:
        payload = payload[os.write(fd, payload):]
    termios.tcdrain(fd)

    keys = sys.stdin.fileno() if sys.stdin.isatty() else None
    if keys is not None:
        saved = termios.tcgetattr(keys)
        tty.setcbreak(keys)                             # unbuffered, no echo; Ctrl-C still works
    try:
        run(fd, keys, img, float("inf") if args.bundle else args.timeout, not args.bundle)
    except KeyboardInterrupt:
        pass
    finally:
        if keys is not None:
            termios.tcsetattr(keys, termios.TCSADRAIN, saved)


def run(fd, keys, img, timeout, until_boot):
    # A thread only drains the port: the tty layer buffers just 4 KB and there is
    # no flow control, so at 300 KB/s a reader slowed by the terminal loses bytes.
    rx = queue.Queue()
    threading.Thread(target=lambda: [rx.put(os.read(fd, 65536)) for _ in iter(int, 1)], daemon=True).start()
    out = b""                                           # output so far, until checked
    checked = None                                      # the checksum line was seen
    deadline = time.time() + timeout
    while time.time() < deadline:
        if keys is not None and select.select([keys], [], [], 0)[0]:
            os.write(fd, os.read(keys, 64))
        try:
            chunk = rx.get(timeout=0.02)
        except queue.Empty:
            continue
        if not chunk:
            continue
        sys.stdout.buffer.write(chunk)
        sys.stdout.flush()
        out = out[-64:] + chunk if checked else out + chunk
        if not checked:
            m = re.search(rb"boot: ([0-9A-F]{8}) bytes, sum ([0-9A-F]{8})", out)
            if m:
                checked = True
                out = out[m.end():]
                n, s = int(m[1], 16), int(m[2], 16)
                if (n, s) != (len(img), sum(img) & 0xFFFFFFFF):
                    sys.exit(f"\nupload corrupted: board got {n} bytes sum {s:08X}, "
                             f"sent {len(img)} bytes sum {sum(img) & 0xFFFFFFFF:08X}")
        if until_boot and checked and BANNER in out:
            return                                      # program returned to the bootloader
    sys.exit("\ntimeout" if checked else "\nno reply: is the board in the bootloader?")

if __name__ == "__main__":
    main()
