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
        color_table = COLOR_TABLES[1]

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
        pixels = decompress_lz77(anim_data, abs_off + 2, color_table)
        sprites[sid] = {'width': w, 'height': h, 'pixels': pixels[:w * h]}

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
    pal_path = os.path.join(game_dir, 'MU1.PAL')

    if not os.path.exists(anim_path):
        print(f'Error: {anim_path} not found')
        sys.exit(1)

    anim_data = open(anim_path, 'rb').read() + b'\x00' * 256
    palette = load_palette(pal_path)
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
        ct = COLOR_TABLES[1]
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

    ct = COLOR_TABLES[1]
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
