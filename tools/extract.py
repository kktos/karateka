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

usage: tools/extract.py [disk.dsk] [outdir]
"""

import os
import sys

TRACK_SECTORS = 16
SECTOR = 256


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    dsk = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "assets", "KARATEKA_S1.dsk")
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "..", "bin")

    disk = open(dsk, "rb").read()
    if len(disk) != 35 * TRACK_SECTORS * SECTOR:
        sys.exit(f"{dsk}: {len(disk)} bytes, not a 140K .dsk")

    def sector(track, sec):
        at = (track * TRACK_SECTORS + sec) * SECTOR
        return disk[at : at + SECTOR]

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


if __name__ == "__main__":
    main()
