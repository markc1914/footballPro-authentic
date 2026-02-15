#!/usr/bin/env python3
"""
palette_finder.py - FPS Football Pro '93 Gameplay Palette Analyzer

Discovers and documents the actual RGB palette values used for player sprites
during gameplay. The game constructs its gameplay palette at runtime using:
1. A base palette from FILE.DAT (PAL sections embedded in screen resources)
2. Team color gradients generated from 5 base colors per team (stored in NFLPA93.LGE)
3. A gradient interpolation algorithm in the EXE (function at ~0x44136)

Key findings:
- FILE.DAT PAL #0 (offset 0x376) = Stadium/gameplay base palette with team colors filled in
- FILE.DAT PAL #5 (offset 0x5E60B) = Alternate gameplay palette with full color gradients
- Palette indices 0x10-0x3F are the sprite color range
- Each team record in NFLPA93.LGE has 5 VGA RGB triplets at T00:+8+0x0A
- The EXE generates 4-shade gradients from team base colors using linear interpolation

Usage: python3 palette_finder.py
"""

import struct
import os
import sys
import json

GAME_DIR = os.path.expanduser('~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO')


def read_pal_file(path):
    """Read a standard PAL: file and return 256 RGB triplets (VGA 6-bit values)."""
    with open(path, 'rb') as f:
        data = f.read()
    if data[:4] != b'PAL:':
        return None
    # PAL: (4B) + size (4B) + VGA: (4B) + vga_size (4B) + 256*3 RGB
    rgb_start = 16
    palette = []
    for i in range(256):
        off = rgb_start + i * 3
        if off + 2 >= len(data):
            palette.append((0, 0, 0))
        else:
            palette.append((data[off], data[off+1], data[off+2]))
    return palette


def read_pal_from_data(data, offset):
    """Read a PAL: section from within a data file."""
    if data[offset:offset+4] != b'PAL:':
        return None
    vga_off = offset + 8
    if data[vga_off:vga_off+4] != b'VGA:':
        return None
    rgb_start = offset + 16
    palette = []
    for i in range(256):
        off = rgb_start + i * 3
        palette.append((data[off], data[off+1], data[off+2]))
    return palette


def vga_to_rgb8(r, g, b):
    """Convert VGA 6-bit (0-63) to 8-bit (0-255) RGB."""
    return (r * 4 + (r >> 4), g * 4 + (g >> 4), b * 4 + (b >> 4))


def generate_4shade_gradient(base_r, base_g, base_b):
    """
    Generate a 4-shade gradient from a base color (brightest to darkest).
    The game's gradient function interpolates linearly.
    Shade 0 = full brightness, Shade 3 = ~44% brightness.
    """
    shades = []
    # Based on analysis of PAL #5 gradients, the game uses 4 shades with
    # approximately: 100%, 79%, 59%, 49% of the base color
    factors = [1.0, 0.79, 0.59, 0.49]
    for f in factors:
        r = min(63, int(base_r * f))
        g = min(63, int(base_g * f))
        b = min(63, int(base_b * f))
        shades.append((r, g, b))
    return shades


def generate_12shade_gradient(bright_r, bright_g, bright_b, dark_r, dark_g, dark_b):
    """
    Generate a 12-shade gradient between two colors using linear interpolation.
    This matches the game's gradient function at EXE offset ~0x44136.
    """
    shades = []
    for i in range(12):
        t = i / 11.0  # 0.0 to 1.0
        r = int(bright_r + (dark_r - bright_r) * t)
        g = int(bright_g + (dark_g - bright_g) * t)
        b = int(bright_b + (dark_b - bright_b) * t)
        shades.append((r, g, b))
    return shades


def read_team_colors():
    """Read 5 jersey color triplets for each of the 28 teams from NFLPA93.LGE."""
    lge_path = os.path.join(GAME_DIR, 'NFLPA93.LGE')
    with open(lge_path, 'rb') as f:
        data = f.read()

    teams = []
    pos = 0
    while True:
        idx = data.find(b'T00:', pos)
        if idx < 0:
            break
        size = int.from_bytes(data[idx+4:idx+8], 'little')
        td = data[idx+8:idx+8+size]

        # City name at offset 0x19 (the bytes before were misaligned in old decoder)
        # Actually the raw bytes show city at +0x19 based on "Buffalo" appearing there
        city_raw = td[0x19:0x30]
        city = city_raw.split(b'\x00')[0].decode('ascii', errors='replace').strip()
        mascot_raw = td[0x2A:0x3B]
        mascot = mascot_raw.split(b'\x00')[0].decode('ascii', errors='replace').strip()

        # 5 RGB color triplets at +0x0A through +0x18
        colors = []
        for c in range(5):
            off = 0x0A + c * 3
            colors.append((td[off], td[off+1], td[off+2]))

        teams.append({
            'city': city,
            'mascot': mascot,
            'id': td[0],
            'conference': td[1],
            'division': td[3],
            'city_index': td[4],
            'colors': colors,  # 5 VGA RGB triplets
        })
        pos = idx + 1

    return teams


def analyze_file_dat_palettes():
    """Find and analyze all PAL: sections in FILE.DAT."""
    file_dat_path = os.path.join(GAME_DIR, 'FILE.DAT')
    with open(file_dat_path, 'rb') as f:
        data = f.read()

    palettes = []
    pos = 0
    while True:
        idx = data.find(b'PAL:', pos)
        if idx < 0:
            break
        pal = read_pal_from_data(data, idx)
        if pal:
            palettes.append((idx, pal))
        pos = idx + 1

    return palettes


def analyze_gameplay_palette(palette, label=""):
    """Analyze a palette's sprite color range (0x10-0x3F) and identify its structure."""
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"{'='*70}")

    # Analyze the structure of indices 0x10-0x3F
    sections = {
        'Skin Tones / Team A Gradient': (0x10, 0x1F, 16),
        'Team Color Set A': (0x20, 0x2B, 12),
        'Equipment/Shared': (0x2C, 0x2D, 2),
        'Field Outline': (0x2E, 0x2F, 2),
        'Team Color Set B': (0x30, 0x3B, 12),
        'Highlights/Extra': (0x3C, 0x3F, 4),
    }

    for section_name, (start, end, count) in sections.items():
        print(f"\n  --- {section_name} (0x{start:02X}-0x{end:02X}, {count} entries) ---")
        for i in range(start, end + 1):
            r, g, b = palette[i]
            r8, g8, b8 = vga_to_rgb8(r, g, b)
            marker = " " if (r or g or b) else " [ZERO]"
            print(f"    [{i:02X}] VGA({r:2d},{g:2d},{b:2d})  RGB8({r8:3d},{g8:3d},{b8:3d})  #{r8:02X}{g8:02X}{b8:02X}{marker}")


def main():
    print("=" * 70)
    print("  FPS Football Pro '93 — Gameplay Palette Finder")
    print("  Analyzing palette sources for sprite color indices 0x10-0x3F")
    print("=" * 70)

    # =========================================================================
    # 1. Check standalone PAL files
    # =========================================================================
    print("\n\n" + "=" * 70)
    print("  SECTION 1: Standalone .PAL Files")
    print("=" * 70)

    pal_files = ['CHAMP.PAL', 'DYNAMIX.PAL', 'GAMINTRO.PAL', 'INTRO.PAL',
                 'INTROPT1.PAL', 'INTROPT2.PAL', 'MU1.PAL', 'MU2.PAL', 'PICKER.PAL']

    for pf in pal_files:
        path = os.path.join(GAME_DIR, pf)
        if not os.path.exists(path):
            print(f"\n  {pf}: NOT FOUND")
            continue
        pal = read_pal_file(path)
        nonzero = sum(1 for i in range(0x10, 0x40) if any(c != 0 for c in pal[i]))
        print(f"\n  {pf}: {nonzero}/48 non-zero entries in sprite range")
        if pf in ('MU1.PAL', 'MU2.PAL'):
            print(f"    -> Menu palette. Sprite range is ALL ZEROS (filled at runtime)")

    # =========================================================================
    # 2. FILE.DAT embedded palettes (the key source!)
    # =========================================================================
    print("\n\n" + "=" * 70)
    print("  SECTION 2: FILE.DAT Embedded Palettes")
    print("=" * 70)

    file_palettes = analyze_file_dat_palettes()
    print(f"\n  Found {len(file_palettes)} PAL: sections in FILE.DAT")

    # Identify the gameplay palettes
    gameplay_pals = []
    for idx, (offset, pal) in enumerate(file_palettes):
        nonzero = sum(1 for i in range(0x10, 0x40) if any(c != 0 for c in pal[i]))
        # Check if it has structured data (not all same value like the blue placeholder 0,0,54)
        unique_vals = len(set(pal[0x10:0x40]))
        is_placeholder = unique_vals <= 3  # all same color = placeholder
        is_gameplay = nonzero > 20 and not is_placeholder

        status = "GAMEPLAY" if is_gameplay else ("PLACEHOLDER" if is_placeholder else "partial")
        print(f"  PAL {idx:2d} at 0x{offset:06X}: {nonzero}/48 non-zero, {unique_vals} unique values - {status}")

        if is_gameplay:
            gameplay_pals.append((idx, offset, pal))

    # =========================================================================
    # 3. Analyze gameplay palettes in detail
    # =========================================================================
    print("\n\n" + "=" * 70)
    print("  SECTION 3: Gameplay Palette Details")
    print("=" * 70)

    for idx, offset, pal in gameplay_pals:
        analyze_gameplay_palette(pal, f"FILE.DAT PAL #{idx} at offset 0x{offset:06X}")

    # =========================================================================
    # 4. THE KEY GAMEPLAY PALETTE (PAL #5 from FILE.DAT)
    # =========================================================================
    # PAL #5 has the most complete gameplay palette with:
    # - 12-shade skin tone gradient at 0x10-0x1F
    # - Team color A at 0x20-0x23 (red gradient for some team)
    # - Team color B at 0x30-0x33 (white/gray gradient)
    # - Equipment colors at 0x28-0x2B and 0x38-0x3B
    # - Field markers at 0x2E-0x2F and 0x3E-0x3F

    if len(file_palettes) > 5:
        _, gameplay_pal = file_palettes[5]
        print("\n\n" + "=" * 70)
        print("  SECTION 4: PRIMARY GAMEPLAY PALETTE (FILE.DAT PAL #5)")
        print("  This palette has the fullest sprite color data")
        print("=" * 70)

        # The layout based on analysis:
        print("\n  Palette Index Layout for Sprites:")
        print("  " + "-" * 64)

        layout = [
            ("SKIN TONES (12 shades, bright to dark)", 0x10, 0x1B),
            ("SKIN EXTRAS (darkest shades)", 0x1C, 0x1F),
            ("TEAM A PRIMARY (4 shades)", 0x20, 0x23),
            ("TEAM A SECONDARY (4 shades)", 0x24, 0x27),
            ("EQUIPMENT/LEATHER (4 shades)", 0x28, 0x2B),
            ("EQUIPMENT DARK", 0x2C, 0x2C),
            ("SHADOW", 0x2D, 0x2D),
            ("FIELD GREEN MARKERS", 0x2E, 0x2F),
            ("TEAM B PRIMARY (4 shades)", 0x30, 0x33),
            ("TEAM B SECONDARY (4 shades)", 0x34, 0x37),
            ("TEAM B EQUIPMENT (4 shades)", 0x38, 0x3B),
            ("TEAM B DARK", 0x3C, 0x3C),
            ("TEAM B SHADOW", 0x3D, 0x3D),
            ("TEAM B FIELD MARKERS", 0x3E, 0x3F),
        ]

        for name, start, end in layout:
            print(f"\n  {name}:")
            for i in range(start, end + 1):
                r, g, b = gameplay_pal[i]
                r8, g8, b8 = vga_to_rgb8(r, g, b)
                print(f"    [{i:02X}] VGA({r:2d},{g:2d},{b:2d})  ->  RGB8({r8:3d},{g8:3d},{b8:3d})  #{r8:02X}{g8:02X}{b8:02X}")

    # =========================================================================
    # 5. Team Colors from NFLPA93.LGE
    # =========================================================================
    print("\n\n" + "=" * 70)
    print("  SECTION 5: Team Jersey Colors (from NFLPA93.LGE)")
    print("  Each team has 5 VGA RGB base colors for jersey customization")
    print("  C1=Primary, C2=Secondary, C3=Pants/Alt1, C4=Pants/Alt2, C5=Trim")
    print("=" * 70)

    teams = read_team_colors()
    for team in teams:
        c = team['colors']
        city = team['city'] or f"Team#{team['id']}"
        mascot = team['mascot'] or ""
        print(f"\n  {city:16s} {mascot:16s}")
        labels = ['C1 Primary ', 'C2 Secondary', 'C3 Alt/Pants1', 'C4 Alt/Pants2', 'C5 Trim     ']
        for i, (r, g, b) in enumerate(c):
            r8, g8, b8 = vga_to_rgb8(r, g, b)
            print(f"    {labels[i]}: VGA({r:2d},{g:2d},{b:2d})  RGB8({r8:3d},{g8:3d},{b8:3d})  #{r8:02X}{g8:02X}{b8:02X}")

    # =========================================================================
    # 6. Generate example gameplay palette for a specific matchup
    # =========================================================================
    print("\n\n" + "=" * 70)
    print("  SECTION 6: Example Palette Construction")
    print("  Showing how the game builds a full palette for a matchup")
    print("=" * 70)

    if len(file_palettes) > 5 and len(teams) >= 2:
        _, base_pal = file_palettes[5]

        # Use Buffalo (team 0) vs Indianapolis (team 1) as example
        home = teams[0]  # Buffalo
        away = teams[1]  # Indianapolis

        print(f"\n  Matchup: {home['city']} vs {away['city']}")
        print(f"\n  Base palette: FILE.DAT PAL #5")
        print(f"  Home: {home['city']} C1=VGA{home['colors'][0]} C2=VGA{home['colors'][1]}")
        print(f"  Away: {away['city']} C1=VGA{away['colors'][0]} C2=VGA{away['colors'][1]}")

        # The game takes the team's C1 and generates 4 shades for palette 0x20-0x23
        # and takes C2 for 0x24-0x27 (home team)
        # Away team goes into 0x30-0x33 (C1) and 0x34-0x37 (C2)

        print(f"\n  HOME TEAM (palette 0x20-0x2B):")
        home_c1 = home['colors'][0]
        home_c2 = home['colors'][1]
        home_grad1 = generate_4shade_gradient(*home_c1)
        home_grad2 = generate_4shade_gradient(*home_c2)
        for i, (r, g, b) in enumerate(home_grad1):
            r8, g8, b8 = vga_to_rgb8(r, g, b)
            print(f"    [0x{0x20+i:02X}] VGA({r:2d},{g:2d},{b:2d})  RGB8({r8:3d},{g8:3d},{b8:3d})  #{r8:02X}{g8:02X}{b8:02X}")
        for i, (r, g, b) in enumerate(home_grad2):
            r8, g8, b8 = vga_to_rgb8(r, g, b)
            print(f"    [0x{0x24+i:02X}] VGA({r:2d},{g:2d},{b:2d})  RGB8({r8:3d},{g8:3d},{b8:3d})  #{r8:02X}{g8:02X}{b8:02X}")

        print(f"\n  AWAY TEAM (palette 0x30-0x3B):")
        away_c1 = away['colors'][0]
        away_c2 = away['colors'][1]
        away_grad1 = generate_4shade_gradient(*away_c1)
        away_grad2 = generate_4shade_gradient(*away_c2)
        for i, (r, g, b) in enumerate(away_grad1):
            r8, g8, b8 = vga_to_rgb8(r, g, b)
            print(f"    [0x{0x30+i:02X}] VGA({r:2d},{g:2d},{b:2d})  RGB8({r8:3d},{g8:3d},{b8:3d})  #{r8:02X}{g8:02X}{b8:02X}")
        for i, (r, g, b) in enumerate(away_grad2):
            r8, g8, b8 = vga_to_rgb8(r, g, b)
            print(f"    [0x{0x34+i:02X}] VGA({r:2d},{g:2d},{b:2d})  RGB8({r8:3d},{g8:3d},{b8:3d})  #{r8:02X}{g8:02X}{b8:02X}")

    # =========================================================================
    # 7. Export the definitive palette data as JSON
    # =========================================================================
    print("\n\n" + "=" * 70)
    print("  SECTION 7: Definitive Palette Export")
    print("=" * 70)

    if len(file_palettes) > 5:
        # PAL #0 from FILE.DAT (initial/default gameplay palette)
        _, pal0 = file_palettes[0]
        # PAL #5 from FILE.DAT (alternate/full gameplay palette)
        _, pal5 = file_palettes[5]

        export = {
            'description': 'FPS Football Pro 93 gameplay sprite palette (indices 0x10-0x3F)',
            'source': 'FILE.DAT embedded PAL sections',
            'format': 'VGA 6-bit (multiply by 4 for 8-bit, or by 4.047619 for exact)',
            'palettes': {
                'pal0_default': {
                    'description': 'FILE.DAT PAL #0 - Default gameplay palette (stadium view)',
                    'offset_in_file_dat': f'0x{file_palettes[0][0]:06X}',
                    'entries': {}
                },
                'pal5_alternate': {
                    'description': 'FILE.DAT PAL #5 - Alternate gameplay palette (with 12-shade skin)',
                    'offset_in_file_dat': f'0x{file_palettes[5][0]:06X}',
                    'entries': {}
                }
            },
            'fixed_indices': {
                'description': 'Non-team-specific palette entries (same across all matchups)',
                'skin_tones': {},
                'equipment': {},
                'field_markers': {},
                'shadow': {},
            },
            'team_color_indices': {
                'description': 'Palette entries that change based on team matchup',
                'home_primary': '0x20-0x23 (4 shades from C1)',
                'home_secondary': '0x24-0x27 (4 shades from C2)',
                'away_primary': '0x30-0x33 (4 shades from C3/away C1)',
                'away_secondary': '0x34-0x37 (4 shades from C4/away C2)',
            }
        }

        for i in range(0x10, 0x40):
            r0, g0, b0 = pal0[i]
            r5, g5, b5 = pal5[i]
            export['palettes']['pal0_default']['entries'][f'0x{i:02X}'] = {
                'vga': [r0, g0, b0],
                'rgb8': list(vga_to_rgb8(r0, g0, b0))
            }
            export['palettes']['pal5_alternate']['entries'][f'0x{i:02X}'] = {
                'vga': [r5, g5, b5],
                'rgb8': list(vga_to_rgb8(r5, g5, b5))
            }

        # Fixed skin tones from PAL #5
        for i in range(0x14, 0x1C):
            r, g, b = pal5[i]
            r8, g8, b8 = vga_to_rgb8(r, g, b)
            export['fixed_indices']['skin_tones'][f'0x{i:02X}'] = {
                'vga': [r, g, b], 'rgb8': [r8, g8, b8]
            }

        # Equipment
        for i in range(0x28, 0x2C):
            r, g, b = pal5[i]
            r8, g8, b8 = vga_to_rgb8(r, g, b)
            export['fixed_indices']['equipment'][f'0x{i:02X}'] = {
                'vga': [r, g, b], 'rgb8': [r8, g8, b8]
            }

        json_path = os.path.join(os.path.dirname(__file__), 'gameplay_palette.json')
        with open(json_path, 'w') as f:
            json.dump(export, f, indent=2)
        print(f"\n  Exported palette data to: {json_path}")

    # =========================================================================
    # Summary
    # =========================================================================
    print("\n\n" + "=" * 70)
    print("  SUMMARY")
    print("=" * 70)
    print("""
  KEY FINDINGS:

  1. GAMEPLAY PALETTES FOUND IN FILE.DAT:
     - PAL #0 (offset 0x376): Default gameplay palette with initial team colors
     - PAL #5 (offset 0x5E60B): Alternate gameplay palette with full gradients
     - PAL #11 (offset 0xC9D56): Color picker/preview palette

  2. PALETTE INDEX LAYOUT (0x10-0x3F):
     0x10-0x13: Grayscale gradient (white to mid-gray) OR special colors
     0x14-0x17: SKIN TONES (4 shades, warm brown)
                PAL#0: VGA(46,30,23) to VGA(27,11,6) = peach to brown
                PAL#5: VGA(46,30,23) to VGA(37,21,14) = 8-shade gradient start
     0x18-0x1F: Extended skin/shared colors (varies per palette)
     0x20-0x23: HOME TEAM PRIMARY color (4 shades, light to dark)
     0x24-0x27: HOME TEAM SECONDARY color (4 shades)
     0x28-0x2B: EQUIPMENT/LEATHER (4 shades, brown gradient)
     0x2C:      Black/dark (equipment shadow)
     0x2D:      Dark gray shadow
     0x2E-0x2F: FIELD GREEN markers
     0x30-0x33: AWAY TEAM PRIMARY color (4 shades)
     0x34-0x37: AWAY TEAM SECONDARY color (4 shades)
     0x38-0x3B: Away equipment/extra (4 shades)
     0x3C-0x3F: Away highlights/extra

  3. SKIN TONE VALUES (from PAL #5, the best source):
     [0x14] VGA(46,30,23) = RGB8(184,120,92) = #B8785C  (lightest)
     [0x15] VGA(43,27,20) = RGB8(172,108,80) = #AC6C50
     [0x16] VGA(40,24,17) = RGB8(160,96,68)  = #A06044
     [0x17] VGA(37,21,14) = RGB8(148,84,56)  = #945438
     [0x18] VGA(35,18,12) = RGB8(140,72,48)  = #8C4830
     [0x19] VGA(32,15,10) = RGB8(128,60,40)  = #803C28
     [0x1A] VGA(29,13, 8) = RGB8(116,52,32)  = #743420
     [0x1B] VGA(27,11, 6) = RGB8(108,44,24)  = #6C2C18  (darkest)

  4. EQUIPMENT/LEATHER VALUES (from PAL #5):
     [0x28] VGA(36,28,16) = RGB8(144,112,64) = #907040  (lightest)
     [0x29] VGA(29,22,12) = RGB8(116,88,48)  = #745830
     [0x2A] VGA(22,16, 8) = RGB8(88,64,32)   = #584020
     [0x2B] VGA(18,13, 7) = RGB8(72,52,28)   = #48341C  (darkest)

  5. SHADOW/OUTLINE VALUES:
     [0x2D] VGA(13,13,13) = RGB8(52,52,52)   = #343434

  6. FIELD MARKERS:
     [0x2E] VGA( 2,16, 5) = RGB8( 8,64,20)  = #084014
     [0x2F] VGA( 3,20, 7) = RGB8(12,80,28)   = #0C501C

  7. TEAM COLOR GENERATION:
     Each team has 5 base colors in NFLPA93.LGE (T00: section, offset +0x0A).
     The game generates 4-shade gradients from each base color using
     linear interpolation. The gradient function at EXE ~0x44136 blends
     between bright and dark versions of the team color.

  8. 28 TEAM BASE COLORS are listed in Section 5 above.
     Use generate_4shade_gradient(R, G, B) to build the actual palette entries.
""")


if __name__ == '__main__':
    main()
