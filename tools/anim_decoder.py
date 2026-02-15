#!/usr/bin/env python3
"""
ANIM.DAT Decoder for Front Page Sports: Football Pro (1993, Dynamix/Sierra)

Fully decodes all 71 player animations from ANIM.DAT, including:
- Index table parsing (animation names, frame counts, data offsets)
- Per-animation structure (frames, views, sprite references)
- LZ77/LZSS sprite bitmap decompression with color table remapping

Compression format (cracked 2026-02-14):
  - Sprite header: 2 bytes (width, height)
  - LZ77 header: uint16 LE (group_count - 1) + uint8 (tail_bits)
  - Per group: 1 flag byte, 8 decisions (MSB first)
  - After all groups: 1 flag byte for tail_bits remaining decisions
  - Decision bit=0: literal byte, mapped through 64-entry color table
  - Decision bit=1: back-reference uint16 LE
      low 4 bits = copy_length - 3 (copies 3..18 bytes)
      high 12 bits = distance back into output buffer
      copies from output[current_pos - distance - 1]
  - Color table provides team color remapping (5 tables x 64 entries)
  - Palette index 0 = transparent

Usage:
  python3 anim_decoder.py                        # Render all 71 animations
  python3 anim_decoder.py SKRUN                   # Render specific animation
  python3 anim_decoder.py --catalog               # Render overview catalog
  python3 anim_decoder.py --list                  # List all animations

Requires: ANIM.DAT, MU1.PAL in the game directory
          PIL/Pillow for image output
"""

import struct
import sys
import os

# ============================================================================
# Color Tables (extracted from A.EXE at file offset 0x4091D, 5 x 64 bytes)
# These tables remap compressed byte values (0-63) to VGA palette indices.
# Different tables handle different team color assignments.
# Table 1 is the default for gameplay sprites.
# ============================================================================

# Color Tables extracted from A.EXE at file offset 0x4091D (5 x 64 bytes).
# These remap compressed byte values 0-63 to VGA palette indices.
# CT1-4 handle team color assignments; CT0 preserves outlines.
#
# IMPORTANT: The game has TWO decompressors in the EXE:
#   0x40A5D — WITH color table (xlat instruction, used for team color remapping)
#   0x40B49 — WITHOUT color table (movsb direct, raw palette indices)
# The adraw function may use the NO-CT version for normal rendering,
# with color table remapping applied at a different stage.
#
# IDENTITY_CT passes through raw values unchanged — use this as default.
IDENTITY_CT = list(range(64))

COLOR_TABLES = [
    # Table 0: minimal (mostly zeros, only indices 46-47 mapped)
    [0]*46 + [0x2E, 0x2F] + [0]*16,
    # Table 1: team colors variant A (default)
    [0]*16 + [0x10,0x11,0x12,0x13] + [0]*12 +
    [0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x2C,0x2D,0,0] +
    [0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x3C,0x3D,0x3E,0x3F],
    # Table 2: team colors variant B
    [0]*16 + [0x10,0x11,0x12,0x13] + [0]*12 +
    [0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0,0] +
    [0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x3C,0x3D,0x3E,0x3F],
    # Table 3: team colors variant C
    [0]*16 + [0x10,0x11,0x12,0x13] + [0]*12 +
    [0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x2C,0x2D,0,0] +
    [0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F],
    # Table 4: team colors variant D
    [0]*16 + [0x10,0x11,0x12,0x13] + [0]*12 +
    [0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0,0] +
    [0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F],
]


def decompress_lz77(data, offset, color_table):
    """
    Decompress LZ77/LZSS compressed sprite data.

    Args:
        data: raw bytes (with safety padding at end)
        offset: byte offset where LZ77 header starts
        color_table: 64-entry list mapping compressed values to palette indices

    Returns:
        bytearray of decompressed palette indices
    """
    si = offset
    groups_m1 = data[si] | (data[si + 1] << 8)
    si += 2
    tail_bits = data[si]
    si += 1

    output = bytearray()

    def process_bit(si, flag_bit):
        if not flag_bit:
            bv = data[si]
            mapped = color_table[bv] if bv < 64 else bv
            output.append(mapped)
            return si + 1
        else:
            ref = data[si] | (data[si + 1] << 8)
            copy_len = (ref & 0x0F) + 3
            distance = ref >> 4
            copy_pos = len(output) - distance - 1
            for j in range(copy_len):
                if 0 <= copy_pos + j < len(output):
                    output.append(output[copy_pos + j])
                else:
                    output.append(0)
            return si + 2

    for g in range(groups_m1 + 1):
        flag = data[si]; si += 1
        for bit in range(8):
            si = process_bit(si, (flag >> 7) & 1)
            flag <<= 1

    if tail_bits > 0:
        flag = data[si]; si += 1
        for bit in range(tail_bits):
            si = process_bit(si, (flag >> 7) & 1)
            flag <<= 1

    return output


def parse_index(anim_data):
    """Parse the ANIM.DAT index table. Returns list of animation dicts."""
    count = struct.unpack('<H', anim_data[0:2])[0]
    animations = []
    for i in range(count):
        off = 2 + i * 14
        name = anim_data[off:off + 8].rstrip(b'\x00').decode('ascii')
        frame_count = struct.unpack('>H', anim_data[off + 8:off + 10])[0]
        data_offset = struct.unpack('<I', anim_data[off + 10:off + 14])[0]
        animations.append({
            'name': name,
            'frame_count': frame_count,
            'data_offset': data_offset,
        })
    return animations


def decode_animation(anim_data, anim_entry, color_table=None):
    """Decode a single animation. Returns dict with frames, views, refs, sprites."""
    if color_table is None:
        color_table = IDENTITY_CT  # Raw palette indices (no team color remapping)

    data_offset = anim_entry['data_offset']
    n_frames = anim_data[data_offset]
    n_views = anim_data[data_offset + 1]

    ref_start = data_offset + 4
    n_refs = n_frames * n_views

    refs = []
    sprite_ids = set()
    for i in range(n_refs):
        r = ref_start + i * 4
        flag = anim_data[r]
        sid = anim_data[r + 1]
        x_off = struct.unpack('b', anim_data[r + 2:r + 3])[0]
        y_off = struct.unpack('b', anim_data[r + 3:r + 4])[0]
        refs.append({'flag': flag, 'sprite_id': sid, 'x_off': x_off, 'y_off': y_off})
        sprite_ids.add(sid)

    n_sprites = max(sprite_ids) + 1
    bitmap_start = ref_start + n_refs * 4

    sprite_offsets = []
    for i in range(n_sprites):
        off = struct.unpack('<H', anim_data[bitmap_start + i * 2:bitmap_start + i * 2 + 2])[0]
        sprite_offsets.append(off)

    sprites = {}
    for sid in sprite_ids:
        abs_off = bitmap_start + sprite_offsets[sid]
        w = anim_data[abs_off]
        h = anim_data[abs_off + 1]
        col_major = decompress_lz77(anim_data, abs_off + 2, color_table)
        # Pixel data is stored COLUMN-MAJOR: x0y0, x0y1, ..., x0yH, x1y0, ...
        # Convert to row-major for standard image rendering
        row_major = bytearray(w * h)
        for x in range(w):
            for y in range(h):
                src = x * h + y
                dst = y * w + x
                if src < len(col_major):
                    row_major[dst] = col_major[src]
        sprites[sid] = {'width': w, 'height': h, 'pixels': row_major}

    return {
        'name': anim_entry['name'],
        'n_frames': n_frames,
        'n_views': n_views,
        'refs': refs,
        'sprites': sprites,
    }


def load_palette(pal_path):
    """Load a VGA palette file (PAL: + VGA: header + 256 RGB triplets)."""
    data = open(pal_path, 'rb').read()
    rgb = []
    for i in range(256):
        r = data[16 + i * 3]
        g = data[16 + i * 3 + 1]
        b = data[16 + i * 3 + 2]
        rgb.append((min(r * 4, 255), min(g * 4, 255), min(b * 4, 255)))
    return rgb


def load_gameplay_palette(game_dir):
    """
    Load the actual gameplay palette from FILE.DAT embedded PAL sections.
    MU1.PAL is a menu palette with zeros at 0x10-0x3F (the sprite color range).
    The game constructs its gameplay palette at runtime from FILE.DAT palettes
    plus team colors from NFLPA93.LGE.

    Returns a 256-entry list of (R8, G8, B8) tuples.
    """
    file_dat_path = os.path.join(game_dir, 'FILE.DAT')
    if not os.path.exists(file_dat_path):
        # Fall back to MU1.PAL with synthetic sprite colors
        return _synthetic_gameplay_palette(game_dir)

    data = open(file_dat_path, 'rb').read()

    # Find PAL: sections — #0 is the default gameplay palette, #5 has full gradients
    pal_offsets = []
    pos = 0
    while True:
        idx = data.find(b'PAL:', pos)
        if idx < 0:
            break
        pal_offsets.append(idx)
        pos = idx + 1

    if len(pal_offsets) < 6:
        return _synthetic_gameplay_palette(game_dir)

    # Use PAL #5 (offset ~0x5E60B) which has the fullest sprite color data:
    # 8-shade skin tones, equipment browns, field green markers, shadow
    pal_offset = pal_offsets[5]
    rgb_start = pal_offset + 16  # skip PAL:(8B) + VGA:(8B)
    palette = []
    for i in range(256):
        off = rgb_start + i * 3
        r, g, b = data[off], data[off + 1], data[off + 2]
        # VGA 6-bit to 8-bit conversion
        palette.append((min(r * 4, 255), min(g * 4, 255), min(b * 4, 255)))

    # Now overlay team colors from NFLPA93.LGE for a sample matchup
    # The game fills 0x20-0x27 (home) and 0x30-0x37 (away) at runtime
    lge_path = os.path.join(game_dir, 'NFLPA93.LGE')
    if os.path.exists(lge_path):
        _apply_team_colors(palette, lge_path)

    return palette


def _generate_4shade_gradient(base_r, base_g, base_b):
    """Generate 4 shades from a VGA base color (brightest to darkest)."""
    factors = [1.0, 0.79, 0.59, 0.49]
    shades = []
    for f in factors:
        r = min(255, int(base_r * 4 * f))
        g = min(255, int(base_g * 4 * f))
        b = min(255, int(base_b * 4 * f))
        shades.append((r, g, b))
    return shades


def _apply_team_colors(palette, lge_path):
    """Apply team colors from NFLPA93.LGE to palette indices 0x20-0x27, 0x30-0x37."""
    data = open(lge_path, 'rb').read()
    teams = []
    pos = 0
    while True:
        idx = data.find(b'T00:', pos)
        if idx < 0:
            break
        size = int.from_bytes(data[idx + 4:idx + 8], 'little')
        td = data[idx + 8:idx + 8 + size]
        colors = []
        for c in range(5):
            off = 0x0A + c * 3
            colors.append((td[off], td[off + 1], td[off + 2]))
        teams.append(colors)
        pos = idx + 1

    if len(teams) >= 2:
        # Default matchup: team 0 (Buffalo) vs team 1 (Indianapolis)
        # Home team primary → 0x20-0x23, secondary → 0x24-0x27
        home_c1 = _generate_4shade_gradient(*teams[0][0])
        home_c2 = _generate_4shade_gradient(*teams[0][1])
        for i, rgb in enumerate(home_c1):
            palette[0x20 + i] = rgb
        for i, rgb in enumerate(home_c2):
            palette[0x24 + i] = rgb

        # Away team primary → 0x30-0x33, secondary → 0x34-0x37
        away_c1 = _generate_4shade_gradient(*teams[1][0])
        away_c2 = _generate_4shade_gradient(*teams[1][1])
        for i, rgb in enumerate(away_c1):
            palette[0x30 + i] = rgb
        for i, rgb in enumerate(away_c2):
            palette[0x34 + i] = rgb


def _synthetic_gameplay_palette(game_dir):
    """Fallback: load MU1.PAL and fill sprite range with synthetic colors."""
    pal_path = os.path.join(game_dir, 'MU1.PAL')
    if os.path.exists(pal_path):
        palette = load_palette(pal_path)
    else:
        palette = [(0, 0, 0)] * 256

    # Skin tones (0x10-0x13 from CT1, or 0x14-0x1B from PAL#5)
    palette[0x10] = (227, 227, 227)  # helmet white
    palette[0x11] = (186, 186, 186)  # helmet gray
    palette[0x12] = (150, 150, 150)  # helmet mid
    palette[0x13] = (113, 113, 113)  # helmet dark
    palette[0x14] = (184, 120, 92)   # skin lightest
    palette[0x15] = (172, 108, 80)
    palette[0x16] = (160, 96, 68)
    palette[0x17] = (148, 84, 56)
    palette[0x18] = (140, 72, 48)
    palette[0x19] = (128, 60, 40)
    palette[0x1A] = (116, 52, 32)
    palette[0x1B] = (108, 44, 24)   # skin darkest
    # Home team A (red)
    for i in range(4):
        v = 220 - i * 40
        palette[0x20 + i] = (v, 20, 20)
    # Home team B (blue)
    for i in range(4):
        v = 220 - i * 40
        palette[0x24 + i] = (20, 20, v)
    # Equipment (brown)
    palette[0x28] = (144, 112, 64)
    palette[0x29] = (116, 88, 48)
    palette[0x2A] = (88, 64, 32)
    palette[0x2B] = (72, 52, 28)
    palette[0x2C] = (20, 20, 20)    # black
    palette[0x2D] = (52, 52, 52)    # shadow
    palette[0x2E] = (8, 64, 20)     # field green
    palette[0x2F] = (12, 80, 28)    # field green
    # Away team A (white)
    for i in range(4):
        v = 255 - i * 30
        palette[0x30 + i] = (v, v, v)
    # Away team B (gray)
    for i in range(4):
        v = 180 - i * 30
        palette[0x34 + i] = (v, v, v)
    # Away equipment
    palette[0x38] = (144, 112, 64)
    palette[0x39] = (116, 88, 48)
    palette[0x3A] = (88, 64, 32)
    palette[0x3B] = (72, 52, 28)
    palette[0x3C] = (200, 200, 200)
    palette[0x3D] = (220, 220, 220)
    palette[0x3E] = (240, 240, 240)
    palette[0x3F] = (255, 255, 255)
    return palette


def render_spritesheet(decoded, palette, output_path, scale=4):
    """Render an animation as a sprite sheet (views as columns, frames as rows)."""
    from PIL import Image

    cell_w, cell_h = 40, 48
    n_views = max(decoded['n_views'], 1)
    n_frames = decoded['n_frames']
    img = Image.new('RGBA', (n_views * cell_w, n_frames * cell_h), (32, 96, 32, 255))

    for frame in range(n_frames):
        for view in range(decoded['n_views']):
            ri = frame * decoded['n_views'] + view
            if ri >= len(decoded['refs']):
                continue
            ref = decoded['refs'][ri]
            sid = ref['sprite_id']
            if sid not in decoded['sprites']:
                continue
            spr = decoded['sprites'][sid]
            w, h, px = spr['width'], spr['height'], spr['pixels']
            cx = view * cell_w + cell_w // 2 + ref['x_off']
            cy = frame * cell_h + cell_h - 4 + ref['y_off']
            for y in range(h):
                for x in range(w):
                    pi = y * w + x
                    if pi < len(px) and px[pi] != 0:
                        ppx, ppy = cx + x, cy + y
                        if 0 <= ppx < img.width and 0 <= ppy < img.height:
                            r, g, b = palette[px[pi]]
                            img.putpixel((ppx, ppy), (r, g, b, 255))

    if scale > 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(output_path)


def main():
    game_dir = os.path.expanduser('~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO')
    anim_path = os.path.join(game_dir, 'ANIM.DAT')

    if not os.path.exists(anim_path):
        print(f'Error: {anim_path} not found')
        sys.exit(1)

    anim_data = open(anim_path, 'rb').read() + b'\x00' * 256
    palette = load_gameplay_palette(game_dir)
    animations = parse_index(anim_data)

    if '--list' in sys.argv:
        print(f'{"#":>3} {"Name":<10} {"Frames":>6}')
        print('-' * 25)
        for i, a in enumerate(animations):
            print(f'{i:3d} {a["name"]:<10} {a["frame_count"]:6d}')
        print(f'\nTotal: {len(animations)} animations')
        return

    if '--catalog' in sys.argv:
        from PIL import Image
        cell_w, cell_h, cols = 32, 48, 10
        rows = (len(animations) + cols - 1) // cols
        img = Image.new('RGBA', (cols * cell_w, rows * cell_h), (32, 80, 32, 255))
        ct = IDENTITY_CT
        for idx, entry in enumerate(animations):
            try:
                decoded = decode_animation(anim_data, entry, ct)
                view_idx = min(4, decoded['n_views'] - 1)
                ref = decoded['refs'][view_idx]
                sid = ref['sprite_id']
                if sid not in decoded['sprites']:
                    continue
                spr = decoded['sprites'][sid]
                w, h, px = spr['width'], spr['height'], spr['pixels']
                col, row = idx % cols, idx // cols
                cx = col * cell_w + cell_w // 2 + ref['x_off']
                cy = row * cell_h + cell_h - 4 + ref['y_off']
                for y in range(h):
                    for x in range(w):
                        pi = y * w + x
                        if pi < len(px) and px[pi] != 0:
                            ppx, ppy = cx + x, cy + y
                            if 0 <= ppx < img.width and 0 <= ppy < img.height:
                                r, g, b = palette[px[pi]]
                                img.putpixel((ppx, ppy), (r, g, b, 255))
            except Exception as e:
                print(f'  Warning: {entry["name"]}: {e}')
        img = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
        img.save('/tmp/anim_catalog.png')
        print(f'Saved /tmp/anim_catalog.png ({len(animations)} animations)')
        return

    targets = [a for a in sys.argv[1:] if not a.startswith('-')]
    if not targets:
        targets = [a['name'] for a in animations]

    ct = IDENTITY_CT
    success = 0
    for target in targets:
        for entry in animations:
            if entry['name'] == target:
                try:
                    decoded = decode_animation(anim_data, entry, ct)
                    outpath = f'/tmp/{target.lower()}_spritesheet.png'
                    render_spritesheet(decoded, palette, outpath)
                    print(f'{target}: {decoded["n_frames"]}f x {decoded["n_views"]}v, '
                          f'{len(decoded["sprites"])} sprites -> {outpath}')
                    success += 1
                except Exception as e:
                    print(f'{target}: ERROR - {e}')
                break
    print(f'\nDecoded {success}/{len(targets)} animations')


if __name__ == '__main__':
    main()
