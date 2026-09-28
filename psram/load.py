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

# Printed once the board is idle again, ready for the next command: by boot.c
# itself if no bundle is stored, or by the menu (see menu.c) once one is.
BANNER = (b"boot: waiting for image", b"boot: menu ready")
BUNDLE_SIZE = 1 << 20                                   # boot.c BUNDLE..BUNDLE_END

# ---- --keys: read the physical keyboard via evdev and send real press/release
# events to the board (protocol: press = code byte, release = 0xF0, code byte).
# Codes are either plain ASCII (which dg_uart.c's doomkey() already maps) or,
# for keys with no ASCII meaning, Doom's own KEY_* values (doomkeys.h), which
# doomkey() passes through unchanged since they're all >= 0x80.
KBD_GLOB = "/dev/input/by-id/*-event-kbd"
EVENT_FMT = "llHHi"                                     # struct input_event (native sizes)
EV_KEY = 1
DOOM_KEYS = {                                            # Linux keycode -> byte
    1: 27, 28: 13, 57: ord(" "), 15: 9, 14: 0x7f,         # Esc Enter Space Tab Backspace
    29: 0xa3, 97: 0xa3,                                   # Ctrl -> KEY_FIRE
    42: 0xb6, 54: 0xb6,                                   # Shift -> KEY_RSHIFT (run)
    56: 0xb8, 100: 0xb8,                                  # Alt -> KEY_RALT (strafe)
    103: 0xad, 108: 0xaf, 105: 0xac, 106: 0xae,            # arrows -> KEY_*ARROW
}
# Letters, digits and punctuation: Linux keycodes -> ASCII (lower case; Shift is 0xb6).
for row, first in (("qwertyuiop", 16), ("asdfghjkl", 30), ("zxcvbnm", 44)):
    for i, ch in enumerate(row):
        DOOM_KEYS[first + i] = ord(ch)
for i, ch in enumerate("1234567890-="):
    DOOM_KEYS[2 + i] = ord(ch)
DOOM_KEYS.update({51: ord(","), 52: ord("."), 53: ord("/"), 39: ord(";"), 26: ord("["), 27: ord("]")})


def read_keys(kfd, fd):
    """Forward one evdev keyboard's press/release events to the board, forever."""
    sz = struct.calcsize(EVENT_FMT)
    buf = b""
    while True:
        buf += os.read(kfd, 4096)
        while len(buf) >= sz:
            ev, buf = buf[:sz], buf[sz:]
            _, _, etype, code, value = struct.unpack(EVENT_FMT, ev)
            if etype == EV_KEY and value in (0, 1) and code in DOOM_KEYS:
                k = DOOM_KEYS[code]
                os.write(fd, bytes([k]) if value else bytes([0xf0, k]))


def start_keys(fd):
    """Start a reader thread per keyboard found via evdev. Returns True if at
    least one was opened (stdin keystrokes should then not also be forwarded),
    False to fall back to the old typed-keys behaviour."""
    paths = glob.glob(KBD_GLOB)
    if not paths:
        print(f"--keys: no keyboard found ({KBD_GLOB}); falling back to typed keys",
              file=sys.stderr)
        return False
    opened = []
    for p in paths:
        try:
            opened.append(os.open(p, os.O_RDONLY))
        except PermissionError:
            pass
    if not opened:
        print("--keys: can't read /dev/input (you're not in the 'input' group).\n"
              "Run: sudo usermod -aG input $USER, then log out and back in.\n"
              "Falling back to typed keys for now.", file=sys.stderr)
        return False
    for kfd in opened:
        threading.Thread(target=read_keys, args=(kfd, fd), daemon=True).start()
    return True


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
    ap.add_argument("image", nargs="*", help="one image, or several with --bundle")
    ap.add_argument("--attach", action="store_true", help="no upload: talk to the running program")
    ap.add_argument("--bundle", action="store_true", help="store the images for the menu")
    ap.add_argument("--out", help="write the bundle to this file instead of uploading it "
                                   "(for flashing at 0x100000; see psram/Makefile flash-bundle)")
    ap.add_argument("--port", help="serial device (default: find the iCEBreaker)")
    ap.add_argument("--baud", type=int, default=3140625, help="the SoC's UART rate (Makefile BAUD)")
    ap.add_argument("--timeout", type=float, default=600, help="seconds to wait for the program")
    ap.add_argument("--keys", action="store_true",
                     help="read the keyboard directly via evdev for real press/release events "
                          "(needs the 'input' group); Ctrl-C still quits")
    args = ap.parse_args()

    if args.attach:
        img = None
    elif args.bundle:
        img = bundle(args.image)
    elif len(args.image) == 1:
        img = open(args.image[0], "rb").read()
    else:
        sys.exit("several images need --bundle")

    if args.out:
        if not args.bundle:
            sys.exit("--out is for --bundle (the flash format has no length prefix)")
        open(args.out, "wb").write(img)
        return

    fd = open_port(args.port or find_port(), args.baud)

    if img is not None:
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
    forward_stdin = keys
    if args.keys and start_keys(fd):
        forward_stdin = None                            # evdev sends key events; don't double up
    try:
        run(fd, forward_stdin, img, float("inf") if args.bundle or args.attach else args.timeout,
            not (args.bundle or args.attach))
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
    checked = img is None                               # the checksum line was seen (or nothing sent)
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
        if until_boot and checked and any(b in out for b in BANNER):
            return                                      # program returned to the bootloader/menu
    sys.exit("\ntimeout" if checked else "\nno reply: is the board in the bootloader?")

if __name__ == "__main__":
    main()
