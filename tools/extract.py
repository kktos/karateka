#!/usr/bin/env python3
"""
Extract Karateka's memory images from the Brutal Deluxe crack (.dsk, DOS 3.3 order)
into bin/, as the original loader would have put them in memory.

The loader ($5500, read from T2) reads whole tracks of 12 sectors (logical 0-11),
each sector going to the page a table at $5400 gives (12 pages per track, 0 = end):

  boot     ($5300: A=$36, Y=$70)  T1B-T20 -> $0800-$0FFF, $6000-$9FFF
  title    ($0303: A=$10, Y=$00)  T04-T06 -> $A000-$BFFF (+ 4 sectors of junk at $4000)
  chunk n  ($0300: A=n,   Y=$30)  T(4n+7)-T(4n+10) -> $1000-$1FFF, $A000-$BFFF

Pages $0200-$07FF come from T0 S2-S7 (copied there by boot1 at $1000).

Side 2 (KARATEKA_S2) is the same game upside down. It differs from side 1 only in
  T1B S0-S1  $0800-$09FF  the hires row address tables ($0800 lo, $08C0 hi), reversed
  T04-T06    $A000-$BFFF  the title picture, flipped vertically
which this script checks, before writing these two as upside_*.bin.

usage: tools/extract.py [side1.dsk] [outdir] [side2.dsk]
"""

import os
import sys

TRACK_SECTORS = 16
SECTOR = 256


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    dsk = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "assets", "KARATEKA_S1.dsk")
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "..", "bin")
    dsk2 = sys.argv[3] if len(sys.argv) > 3 else os.path.join(here, "..", "assets", "KARATEKA_S2.dsk")

    def read_dsk(path):
        data = open(path, "rb").read()
        if len(data) != 35 * TRACK_SECTORS * SECTOR:
            sys.exit(f"{path}: {len(data)} bytes, not a 140K .dsk")
        return data

    disk = read_dsk(dsk)

    def sector(track, sec, data=None):
        at = (track * TRACK_SECTORS + sec) * SECTOR
        return (data or disk)[at : at + SECTOR]

    def load(first_track, pages):
        """The loader's read: 12 sectors a track, sector s to page pages[track*12 + s]."""
        mem = {}
        for i, page in enumerate(pages):
            track, sec = first_track + i // 12, i % 12
            mem[page] = sector(track, sec)
        return mem

    def image(mem, start, end):
        return b"".join(mem[p] for p in range(start >> 8, (end >> 8) + 1))

    os.makedirs(out, exist_ok=True)

    def write(name, data, start):
        path = os.path.join(out, name)
        open(path, "wb").write(data)
        print(f"  {name:28} ${start:04X}-${start + len(data) - 1:04X}  {len(data):5} bytes")

    # $0200-$07FF: T0 S2-S7. Split around the RWTS loader at $0309-$03C7, which the build replaces.
    resident = b"".join(sector(0, s) for s in range(2, 8))
    boot = load(0x1B, list(range(0x08, 0x10)) + list(range(0x60, 0xA0)))
    write("game_lo.0200-0308.bin", resident[: 0x309 - 0x200], 0x200)
    write("game_lo.03C8-0FFF.bin", resident[0x3C8 - 0x200 :] + image(boot, 0x0800, 0x0FFF), 0x3C8)
    write("game_hi.6000-9FFF.bin", image(boot, 0x6000, 0x9FFF), 0x6000)

    # the 4 sectors to $4000 are junk: T06 S8-SB, past the title picture
    title = load(0x04, list(range(0xA0, 0xC0)) + [0x40] * 4)
    write("title.A000-BFFF.bin", image(title, 0xA000, 0xBFFF), 0xA000)

    for n in range(5):
        chunk = load(4 * n + 7, list(range(0x10, 0x20)) + list(range(0xA0, 0xC0)))
        # what $020C checks after loading chunk n: $BFFD-$BFFF = n, n^$3B, n^$49
        sig = chunk[0xBF][0xFD:0x100]
        if sig != bytes([n, n ^ 0x3B, n ^ 0x49]):
            sys.exit(f"chunk {n}: bad signature {sig.hex(' ')}")
        write(f"c{n}_lo.1000-1FFF.bin", image(chunk, 0x1000, 0x1FFF), 0x1000)
        write(f"c{n}_hi.A000-BFFF.bin", image(chunk, 0xA000, 0xBFFF), 0xA000)

    # side 2: the game upside down
    disk2 = read_dsk(dsk2)
    rows_sectors = {(0x1B, 0), (0x1B, 1)}
    title_sectors = {(t, s) for t in range(0x04, 0x07) for s in range(12)}
    for track in range(35):
        for sec in range(TRACK_SECTORS):
            if (track, sec) in rows_sectors | title_sectors:
                continue
            if sector(track, sec) != sector(track, sec, disk2):
                sys.exit(f"{dsk2}: T{track:02X} S{sec:X} differs from side 1, not just the row tables and the title")

    rows = sector(0x1B, 0) + sector(0x1B, 1)
    rows2 = sector(0x1B, 0, disk2) + sector(0x1B, 1, disk2)
    for name, at in (("lo", 0x00), ("hi", 0xC0)):
        if rows2[at : at + 192] != rows[at : at + 192][::-1]:
            sys.exit(f"{dsk2}: the {name} row table at ${0x800 + at:04X} isn't side 1's reversed")
    if rows2[0x180:] != rows[0x180:]:
        sys.exit(f"{dsk2}: $0980-$09FF differs from side 1")

    def row(y):
        return (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28

    title1 = image(title, 0xA000, 0xBFFF)
    title2 = b"".join(sector(t, s, disk2) for t, s in sorted(title_sectors))[:0x2000]
    for y in range(192):
        if title2[row(y) : row(y) + 40] != title1[row(191 - y) : row(191 - y) + 40]:
            sys.exit(f"{dsk2}: title row {y} isn't side 1's row {191 - y}")

    write("upside_rows.0800-09FF.bin", rows2, 0x0800)
    write("upside_title.A000-BFFF.bin", title2, 0xA000)


if __name__ == "__main__":
    main()
