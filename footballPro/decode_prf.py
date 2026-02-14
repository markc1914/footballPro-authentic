#!/usr/bin/env python3
"""
FPS Football Pro '93 (.PRF and .PLN) File Format Decoder
=========================================================
Decodes the binary play route format files from Dynamix/Sierra's
"Front Page Sports: Football Pro" (1993).

DISCOVERED FORMAT:
  PRF = 40-byte header + 15120 bytes data + 12-13 byte footer
  Data = 7 plays x 360 cells x 6 bytes/cell
  Grid = 20 rows x 18 columns (field grid)
  Rows 3,7,11,15 = formation/alignment rows
  Other rows = route instruction rows (5 phases of 4 rows each)

  PLN = 12-byte header + 86-slot offset table (172 bytes) + 18-byte entries + footer
  Header: "G93:" + 8 config bytes
  Offset table: 86 x 2-byte LE offsets (bytes 12-183), 0=empty slot
  Entry area starts at byte 0xB8 (184)
  Each entry = 18 bytes:
    Bytes 0-1:  Formation code (LE uint16)
    Bytes 2-3:  Formation mirror / sub-type (LE uint16)
    Bytes 4-11: Play name (8 ASCII chars, null-padded)
    Bytes 12-15: PRF reference (LE uint32, high word=page, low word=offset)
    Bytes 16-17: Play data size (LE uint16)
  Footer: "J93:" + metadata
"""

import struct
import os
from collections import Counter


# --- PLN Constants -----------------------------------------------------------
PLN_HEADER_SIZE = 12          # "G93:" + 8 config bytes
OFFSET_TABLE_SLOTS = 86       # 86 x 2-byte LE offsets
OFFSET_TABLE_SIZE = OFFSET_TABLE_SLOTS * 2  # 172 bytes
ENTRY_AREA_START = PLN_HEADER_SIZE + OFFSET_TABLE_SIZE  # 0xB8 = 184
PLN_ENTRY_SIZE = 18           # bytes per play entry

# --- Formation code to human-readable name mapping ---------------------------
FORMATION_NAMES = {
    0x8501: "I-Form", 0x8502: "I-Form Var", 0x8503: "Split Back",
    0x8504: "Pro Set", 0x8505: "Shotgun", 0x8506: "Singleback",
    0x8507: "Near Back", 0x8508: "Far Back", 0x8509: "Wishbone",
    0x850A: "Goal Line Off",
    0x8401: "4-3", 0x8402: "3-4", 0x8403: "4-4", 0x8404: "Nickel",
    0x8405: "Dime", 0x8406: "3-5-3", 0x8407: "Goal Line Def",
    0x8408: "Prevent",
    0x0004: "ST: Run", 0x0400: "ST: Pass", 0x0002: "ST: Blitz",
    0x0012: "ST: Special", 0x000C: "ST: Zone", 0x0008: "ST: Mix",
    0x0030: "GL: Run", 0x0032: "GL: Pass", 0x0022: "ST: Deep",
}

ST_SUBTYPES_OFF = {
    0x0101: "FG/PAT", 0x0102: "Kickoff", 0x0103: "Punt",
    0x0104: "Onside Kick", 0x0105: "Fake FG Run", 0x0106: "Fake FG Pass",
    0x0107: "Fake Punt Run", 0x0108: "Fake Punt Pass", 0x0109: "Free Kick",
    0x010A: "Squib", 0x010B: "Run Clock", 0x010C: "Stop Clock",
}

ST_SUBTYPES_DEF = {
    0x0001: "FG/PAT Def", 0x0002: "Kick Return", 0x0003: "Punt Return",
    0x0004: "Onside Return", 0x0005: "Fake FG Run D", 0x0006: "Fake FG Pass D",
    0x0007: "Fake Punt Run D", 0x0008: "Fake Punt Pass D",
    0x0009: "Free Return", 0x000A: "Squib Return",
}


def decode_formation(form_code, mirror_code):
    """Decode formation code and mirror to human-readable string."""
    if form_code <= 0x0100:
        st_name = ST_SUBTYPES_OFF.get(mirror_code) or ST_SUBTYPES_DEF.get(mirror_code)
        if st_name:
            return f"ST: {st_name}"
        return f"ST: 0x{form_code:04x}/0x{mirror_code:04x}"
    name = FORMATION_NAMES.get(form_code, f"Form 0x{form_code:04x}")
    if mirror_code != form_code:
        return f"{name} (m:0x{mirror_code:04x})"
    return name


def extract_play_grid(data, play_index):
    """Extract 20x18 grid for play (0-6) from PRF data. Each cell = 6 bytes."""
    grid = []
    for row in range(20):
        row_data = []
        for col in range(18):
            group_index = row * 18 + col
            group_offset = 0x28 + group_index * 42
            record_offset = group_offset + play_index * 6
            record = data[record_offset:record_offset + 6]
            row_data.append(tuple(record))
        grid.append(row_data)
    return grid


def decode_action(code):
    """Decode action byte to string."""
    actions = {
        0x00: 'ZERO', 0x02: 'MOVE_A', 0x03: 'MOVE_B', 0x04: 'MOVE_C',
        0x05: 'MOVE_D', 0x0a: 'BREAK', 0x0c: 'CUT', 0x10: 'POS_A',
        0x13: 'POS_B', 0x16: 'SPECIAL', 0x17: 'HOLD', 0x18: 'HOLD+1',
        0x19: 'DEEP', 0x1a: 'BLOCK',
    }
    return actions.get(code, f'ACT_{code:02x}')


def decode_pln(filepath):
    """Decode PLN play plan file. Returns (header, entries, footer, offsets)."""
    with open(filepath, 'rb') as f:
        data = f.read()
    header = {
        'magic': data[:4].decode('ascii', errors='replace'),
        'config': data[4:12].hex(),
    }
    footer_idx = data.find(b'J93:')
    footer = data[footer_idx:].hex() if footer_idx >= 0 else 'NOT_FOUND'

    offsets = []
    for i in range(OFFSET_TABLE_SLOTS):
        off = struct.unpack_from('<H', data, PLN_HEADER_SIZE + i * 2)[0]
        offsets.append(off)

    entries = []
    end_pos = footer_idx if footer_idx >= 0 else len(data)
    pos = ENTRY_AREA_START

    while pos + PLN_ENTRY_SIZE <= end_pos:
        entry_data = data[pos:pos + PLN_ENTRY_SIZE]
        form_code = struct.unpack_from('<H', entry_data, 0)[0]
        form_mirror = struct.unpack_from('<H', entry_data, 2)[0]
        name = entry_data[4:12].rstrip(b'\x00').decode('ascii', errors='replace')
        prf_ref = struct.unpack_from('<I', entry_data, 12)[0]
        play_size = struct.unpack_from('<H', entry_data, 16)[0]

        if not name or not all(0x20 <= ord(c) <= 0x7E for c in name):
            break

        entries.append({
            'offset': pos, 'formation': form_code, 'formation_mirror': form_mirror,
            'name': name, 'prf_page': (prf_ref >> 16) & 0xFFFF,
            'prf_offset': prf_ref & 0xFFFF, 'prf_ref_raw': prf_ref, 'size': play_size,
        })
        pos += PLN_ENTRY_SIZE

    return header, entries, footer, offsets


def analyze_prf_file(filepath, verbose=False):
    """Analyze a PRF file."""
    with open(filepath, 'rb') as f:
        data = f.read()
    filename = os.path.basename(filepath)
    is_defense = 'DEF' in filename.upper()

    print(f"\n{'='*70}")
    print(f"PRF: {filename} ({len(data)} bytes, {'defense' if is_defense else 'offense'})")
    print(f"{'='*70}")

    footer_offset = data.find(b'#I93:')
    data_size = footer_offset - 0x28
    print(f"  Header: {data[:6].decode('ascii')} | Data: {data_size} bytes | Footer at 0x{footer_offset:04x}")
    print(f"  = {data_size//6} records = {data_size//42} groups = 20 rows x 18 cols x 7 plays")

    uniform = sum(1 for g in range(360)
                  if all(data[0x28+g*42+r*6:0x28+g*42+r*6+6] == data[0x28+g*42:0x28+g*42+6]
                         for r in range(1, 7)))
    print(f"  Uniform groups: {uniform}/360 ({uniform*100//360}%) | Varying: {360-uniform}")

    for play in range(7):
        grid = extract_play_grid(data, play)
        active = sum(1 for c in range(18) if grid[3][c][1] == 0x0a)
        actions = Counter()
        for r in range(20):
            if r in (3, 7, 11, 15):
                continue
            for c in range(18):
                actions[decode_action(grid[r][c][0])] += 1
        top = ', '.join(f"{a}:{n}" for a, n in actions.most_common(4))
        print(f"  Play {play}: {active} active cols | {top}")

    if verbose:
        for play_index in range(7):
            _print_play_grid(data, play_index)


def _print_play_grid(data, play):
    """Print detailed grid for one play."""
    grid = extract_play_grid(data, play)
    print(f"\n  PLAY {play} DETAILED GRID:")
    for row in range(20):
        phase = row // 4
        rtype = "FORM " if row in (3, 7, 11, 15) else "ROUTE"
        print(f"\n  Row {row:2d} [Phase {phase} {rtype}]:")
        for col in range(18):
            r = grid[row][col]
            print(f"    [{col:2d}] {r[0]:02x} {r[1]:02x} {r[2]:02x} | {r[3]:02x} {r[4]:02x} {r[5]:02x}"
                  f"  {decode_action(r[0]):>8s}")


def analyze_pln_file(filepath):
    """Analyze a PLN file."""
    print(f"\n{'='*70}")
    print(f"PLN: {os.path.basename(filepath)}")
    print(f"{'='*70}")
    header, entries, footer, offsets = decode_pln(filepath)
    with open(filepath, 'rb') as f:
        size = len(f.read())

    active_slots = sum(1 for o in offsets if o != 0)
    print(f"  Size: {size} bytes | Magic: {header['magic']} | Entries: {len(entries)}")
    print(f"  Offset table: {OFFSET_TABLE_SLOTS} slots, {active_slots} active")

    regular = [e for e in entries if e['formation'] > 0x0100]
    special = [e for e in entries if e['formation'] <= 0x0100]
    print(f"  Regular plays: {len(regular)} | Special teams: {len(special)}")

    formations = Counter(e['formation'] for e in entries)
    print(f"  Formations ({len(formations)} unique):")
    for f_code, count in sorted(formations.items()):
        name = FORMATION_NAMES.get(f_code, f"0x{f_code:04x}")
        print(f"    {name}: {count} plays")

    pages = Counter(e['prf_page'] for e in entries)
    print(f"  PRF pages: " + ', '.join(f"pg{p}({c})" for p, c in sorted(pages.items())))

    print(f"\n  {'#':>3} {'Name':>10} {'Formation':>20} {'Pg':>3} {'Offset':>7} {'Size':>5}")
    print(f"  {'-'*52}")
    for i, e in enumerate(entries):
        form_str = decode_formation(e['formation'], e['formation_mirror'])
        print(f"  {i:3d} {e['name']:>10} {form_str:>20} {e['prf_page']:3d} {e['prf_offset']:7d} {e['size']:5d}")
    return entries


def compare_prf_files(file_a, file_b):
    """Compare two PRF files."""
    with open(file_a, 'rb') as f:
        da = f.read()
    with open(file_b, 'rb') as f:
        db = f.read()
    print(f"\n  Comparing {os.path.basename(file_a)} vs {os.path.basename(file_b)}:")
    for play in range(7):
        ga = extract_play_grid(da, play)
        gb = extract_play_grid(db, play)
        diffs = sum(1 for r in range(20) for c in range(18) if ga[r][c] != gb[r][c])
        print(f"    Play {play}: {diffs}/360 cells differ ({diffs*100//360}%)")


def main():
    base = os.path.expanduser("~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")
    stock = os.path.join(base, "STOCK")

    print("=" * 70)
    print("FPS FOOTBALL PRO '93 - PLAY FORMAT DECODER")
    print("=" * 70)

    print("\n\n" + "#" * 70)
    print("# SECTION 1: PLN (Play Plan Index) FILES")
    print("#" * 70)
    for pf in ["STOCK/OFFPA1.PLN", "STOCK/OFFRA1.PLN", "STOCK/DEFPA1.PLN", "OFF.PLN", "DEF.PLN"]:
        path = os.path.join(base, pf)
        if os.path.exists(path):
            analyze_pln_file(path)

    print("\n\n" + "#" * 70)
    print("# SECTION 2: PRF (Play Route Format) FILES")
    print("#" * 70)
    first = True
    for pf in ["OFF1.PRF", "OFF2.PRF", "DEF1.PRF", "STOCK/OFFPA1.PRF", "STOCK/OFFRA1.PRF", "STOCK/DEFPA1.PRF"]:
        path = os.path.join(base, pf)
        if os.path.exists(path):
            analyze_prf_file(path, verbose=first)
            first = False

    print("\n\n" + "#" * 70)
    print("# SECTION 3: COMPARISONS")
    print("#" * 70)
    pairs = [("OFF1.PRF", "OFF2.PRF"), ("STOCK/OFFPA1.PRF", "STOCK/OFFRA1.PRF")]
    for a, b in pairs:
        pa, pb = os.path.join(base, a), os.path.join(base, b)
        if os.path.exists(pa) and os.path.exists(pb):
            compare_prf_files(pa, pb)

    print("\n\n" + "#" * 70)
    print("# FORMAT SUMMARY")
    print("#" * 70)
    print("""
PRF FILE (Play Route Format) - 15,176 bytes (offense) / 15,177 bytes (defense):
  [Header: 40 bytes]
    "F93:1;" + padding + "F\\x00U\\x00" x 8
  [Data: 15,120 bytes]
    2520 six-byte records in 360 groups of 7
    7 records = 7 plays per PRF file
    360 groups = 20 rows x 18 columns (field grid)
    Formation rows at indices 3, 7, 11, 15
    5 phases of 4 rows: pre-snap, initial, primary, secondary, terminal
  [Footer: 12-13 bytes]
    "#I93:" + metadata

  6-byte cell record:
    Bytes 0,2,4: Player type IDs (0x10-0x15) or action codes
    Bytes 1,3,5: Position state (0x0a=active, 0x01=inactive, 0x80+=flagged)
    Action codes: 0x17=HOLD/BLOCK, 0x02-0x05=MOVE, 0x0a=BREAK,
                  0x16=SPECIAL, 0x19=DEEP, 0x1a=BLOCK

PLN FILE (Play Plan Index) - 1,568 bytes (offense) / 1,531 bytes (defense):
  [Header: 12 bytes] "G93:" + 8 config bytes
  [Offset table: 172 bytes] 86 x 2-byte LE offsets (0=empty slot)
  [Entries: 18 bytes each, starting at byte 0xB8]
    Bytes 0-1:  Formation code (LE uint16)
    Bytes 2-3:  Formation mirror / sub-type (LE uint16)
    Bytes 4-11: Play name (8 chars, null-padded ASCII)
    Bytes 12-15: PRF reference (LE uint32, page:offset)
    Bytes 16-17: Play data size (LE uint16)
  [Footer: 16 bytes] "J93:" + metadata
""")


if __name__ == '__main__':
    main()
