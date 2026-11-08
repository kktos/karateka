# karateka

Karateka (Jordan Mechner, 1984) on a ProDOS-order `.po`, booted by tiny-dos (from [conan](../conan)) from a
SmartPort / block device in any slot, instead of the original's RWTS reading a Disk II in slot 6.

The game itself is the Brutal Deluxe crack's code and data, untouched: only its disk loader is replaced.

## Build

```sh
cp "KARATEKA_S1 (Brutal Deluxe crack).dsk" assets/KARATEKA_S1.dsk   # not in the repo
python3 tools/extract.py        # assets/KARATEKA_S1.dsk -> bin/*.bin
tsasm karateka-conf.yaml        # -> dist/karateka.po
```

## How the original loads

All of its disk accesses go through two vectors, in page 3:

| Call                    | Loads                                   | Tracks                   |
| ----------------------- | --------------------------------------- | ------------------------ |
| boot (`$5300`)          | `$0800-$0FFF`, `$6000-$9FFF`, then `JMP $0200` | T1B-T20           |
| `$0303` (`JMP $03C8`)   | the title picture, `$A000-$BFFF`        | T04-T06                  |
| `$0300` with `A` = n    | chunk n: `$1000-$1FFF`, `$A000-$BFFF`   | T(4n+7)-T(4n+10), n=0-4  |

Tracks hold 12 sectors (logical 0-11, 3K). The loader ($0309 → T1 at `$4000` → T2 at `$5000`) reads whole tracks,
each sector to the page a table at `$5400` gives. `$0200-$07FF` comes from T0 S2-S7 (boot1 copies it there).
After loading chunk n, `$020C` checks `$BFFD-$BFFF` = n, n^`$3B`, n^`$49` and jumps to `$BFFA`.

## The .po

| File       | Load                                 | Blocks  |
| ---------- | ------------------------------------ | ------- |
| `KARATEKA` | `$1000`: what boot1 and `$5300` did   | 1       |
| `GAME`     | `$0200-$0FFF` + `$6000-$9FFF`         | 7 + 32  |
| `TITLE`    | `$A000-$BFFF`                         | 16      |
| `C0`-`C4`  | `$1000-$1FFF` + `$A000-$BFFF`         | 8 + 16  |

- `$0309-$03C7`, the RWTS loader, becomes [loader.asm](src/modules/game/loader.asm): `$0300` and `$0303` (whose
  `$03C8` calls `$0309` with `A=$10`) stay as they are. It saves the zero page in the language card, calls tiny-dos
  (LC bank 2), restores the zero page and the ROM, returns `A=0`.
- tiny-dos changes from conan's: its buffer is at `$DE00` (the game uses all of `$0800-$BFFF`), `LoadFromFileAt`
  loads blocks of a file at a given address (a file loads in 2 places), and `FindFile` skips the directory
  headers (it took the volume header, named `KARATEKA` too, for the file).
- Not reproduced: the original left its loader in `$4000-$5FFF` (HGR page 2), with the screen holes cleared, and
  the title load put 4 junk sectors at `$4000`.
