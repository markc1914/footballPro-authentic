#!/usr/bin/env python3
"""
Brute-force explorer for FPS '93 .DDA cutscene streams (LOGOEND, DYNAMIX, INTROPT1/2).
- Assumes VGA palette in first 768 bytes (6-bit *4).
- Tries small opcode grammars over the main payload and writes candidate frames to /tmp for eyeballing.
- Designed to be run locally/iteratively; no dependencies beyond Pillow (for saving PNGs).

Usage:
  python3 tools/dda_bruteforce.py path/to/FILE.DDA --width 320 --height 200 --max-candidates 50

It will emit /tmp/dda_candidate_*.png and a CSV summary of attempts in /tmp/dda_candidates.csv
Edit the opcode grammars in `GRAMMARS` to widen search.
"""

import argparse
import itertools
import os
from pathlib import Path
from typing import List, Tuple
import struct
from PIL import Image

# A handful of small opcode grammars to try. Each entry is (name, decoder_fn)
# Decoder signature: decoder(data: bytes, expected: int) -> bytes


def make_nibble_rle(lit_bias: int, rep_bias: int, ctrl_mask: int):
    def decode(data: bytes, expected: int) -> bytes:
        out = bytearray()
        i = 0
        while i < len(data) and len(out) < expected:
            b = data[i]
            i += 1
            if b & ctrl_mask:
                if i >= len(data):
                    break
                run = (b & 0x3F) + rep_bias
                val = data[i]
                i += 1
                out.extend([val] * run)
            else:
                run = (b & 0x3F) + lit_bias
                out.extend(data[i : i + run])
                i += run
        return bytes(out)

    return decode


def make_marker_rle(marker: int, len_offset: int):
    def decode(data: bytes, expected: int) -> bytes:
        out = bytearray()
        i = 0
        while i < len(data) and len(out) < expected:
            b = data[i]
            i += 1
            if b == marker:
                if i + 1 > len(data):
                    break
                run = data[i] + len_offset
                val = data[i + 1]
                i += 2
                out.extend([val] * run)
            else:
                out.append(b)
        return bytes(out)

    return decode


# Expand the grammar search here if needed.
GRAMMARS = [
    (f"nibble_ctrl_{lb}_{rb}_{hex(ctrl)}", make_nibble_rle(lb, rb, ctrl))
    for lb, rb, ctrl in itertools.product([0, 1], [1, 2, 3], [0x80, 0xC0])
] + [
    (f"marker_fe_len{off}", make_marker_rle(0xFE, off)) for off in (0, 1, 2)
] + [
    (f"marker_c9_len{off}", make_marker_rle(0xC9, off)) for off in (0, 1, 2)
]


def load_palette(data: bytes, start: int = 0) -> List[Tuple[int, int, int]]:
    pal = data[start : start + 768]
    if len(pal) < 768:
        raise ValueError("Palette too short")
    colors = [
        (min(pal[i * 3] * 4, 255), min(pal[i * 3 + 1] * 4, 255), min(pal[i * 3 + 2] * 4, 255))
        for i in range(256)
    ]
    return colors


def save_png(buf: bytes, w: int, h: int, pal: List[Tuple[int, int, int]], path: Path):
    img = Image.new("P", (w, h))
    img.putdata(buf[: w * h])
    flat = []
    for c in pal:
        flat.extend(c)
    img.putpalette(flat)
    img.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dda", type=Path)
    ap.add_argument("--width", type=int, default=320)
    ap.add_argument("--height", type=int, default=200)
    ap.add_argument("--pal-offset", type=int, default=0, help="Start of palette bytes (default 0)")
    ap.add_argument(
        "--payload-offset",
        type=int,
        default=None,
        help="Override payload start; otherwise use first header u32 after 0x10 (LOGOEND) or 0x10 default",
    )
    ap.add_argument("--max-candidates", type=int, default=50)
    args = ap.parse_args()

    data = args.dda.read_bytes()
    pal = load_palette(data, args.pal_offset)

    # Heuristic payload start: LOGOEND has an offset at 0x10; others we default to 0x1F10
    if args.payload_offset is not None:
        payload_off = args.payload_offset
    else:
        if data[:4] == b"DDA:":
            payload_off = struct.unpack_from("<I", data, 0x10)[0]
        else:
            payload_off = 0x1F10
    payload = data[payload_off:]
    expected = args.width * args.height

    out_dir = Path("/tmp")
    csv_lines = ["name,len,unique,file"]
    hits = 0

    for name, decoder in GRAMMARS:
        out = decoder(payload, expected)
        unique = len(set(out))
        csv_lines.append(f"{name},{len(out)},{unique},")
        if len(out) == expected and hits < args.max_candidates:
            out_path = out_dir / f"dda_candidate_{args.dda.stem}_{name}.png"
            save_png(out, args.width, args.height, pal, out_path)
            csv_lines[-1] = f"{name},{len(out)},{unique},{out_path}"
            hits += 1
            print(f"HIT {name} -> {out_path}")

    csv_path = out_dir / f"dda_candidates_{args.dda.stem}.csv"
    csv_path.write_text("\n".join(csv_lines))
    print(f"Wrote {csv_path} (hits={hits})")


if __name__ == "__main__":
    main()
