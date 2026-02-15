#!/usr/bin/env python3
"""
SCR Decoder for Front Page Sports: Football Pro (1993, Dynamix/Sierra)

Decodes .SCR screen graphics files and renders them as PNG images.

SCR File Structure:
  - "SCR:" (4B) + uint32 LE section size (bit 31 = container flag)
  - Optional "DIM:" (4B) + uint32 LE size (4) + uint16 LE width + uint16 LE height
  - "BIN:" (4B) + uint32 LE compressed size
    - 1 byte: compression type (0x01=RLE, 0x02=LZW)
    - 4 bytes LE: uncompressed size
    - Compressed pixel data (low nibbles of 4-bit packed pixels)
  - "VGA:" (4B) + uint32 LE compressed size
    - Same sub-header format
    - Compressed pixel data (high nibbles of 4-bit packed pixels)

Image pixels are 4-bit (16-color) nibble-packed, 2 pixels per byte.
BIN: section provides low nibbles, VGA: section provides high nibbles.
Combined: pixel[i] = low_nibble[i] | (high_nibble[i] << 4) = 8-bit palette index.

Decompressed size = width * height / 2 (each section = half the pixels' bits).

LZW Compression (type 0x02):
  - Dynamix block-aligned LZW (DGDS engine)
  - 9-bit initial code size, max 12 bits
  - Code 0x100 (256) = clear/reset
  - No end code (decode until expected output size reached)
  - LSB-first bit packing
  - Block alignment: codes packed in blocks of (code_size * 8) bits
  - On clear: skip remaining bits in current block, then reset

PAL Format:
  - "PAL:" (8B) + "VGA:" (8B) + 256 x 3 bytes (6-bit VGA values x4 = 8-bit)
"""

import struct
import sys
import os
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow")
    sys.exit(1)

GAME_DIR = os.path.expanduser("~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")
OUTPUT_DIR = "/tmp"

WIDTH = 320
HEIGHT = 200


def load_palette(pal_path):
    """Load a VGA palette file. Returns list of 256 (R,G,B) tuples."""
    with open(pal_path, 'rb') as f:
        data = f.read()

    if data[:4] == b'PAL:':
        offset = 16  # Skip "PAL:" (8B) + "VGA:" (8B)
    else:
        offset = 0

    colors = []
    for i in range(256):
        r = min(data[offset + i*3] * 4, 255)
        g = min(data[offset + i*3 + 1] * 4, 255)
        b = min(data[offset + i*3 + 2] * 4, 255)
        colors.append((r, g, b))

    return colors


def hex_dump(data, count=64, prefix=""):
    """Print a hex dump of binary data."""
    for i in range(0, min(count, len(data)), 16):
        hex_part = ' '.join(f'{b:02X}' for b in data[i:i+16])
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data[i:i+16])
        print(f"  {prefix}{i:04X}: {hex_part:<48s} {ascii_part}")


class DynamixLZW:
    """
    Dynamix DGDS engine LZW decompressor.

    Block-aligned LZW with:
    - 9-bit initial code size, max 12 bits
    - Code 0x100 = clear/reset
    - No end code
    - LSB-first bit packing
    - Block alignment on clear (skip remaining bits in code_size*8 block)
    """

    BIT_MASKS = [0x0000, 0x0001, 0x0003, 0x0007,
                 0x000F, 0x001F, 0x003F, 0x007F,
                 0x00FF, 0x01FF, 0x03FF, 0x07FF,
                 0x0FFF, 0x1FFF, 0x3FFF, 0x7FFF]

    def __init__(self):
        self.reset()
        self._bits_data = 0
        self._bits_size = 0

    def reset(self):
        """Reset LZW state (table, code size, etc.)."""
        self._table = {}
        for i in range(256):
            self._table[i] = bytes([i])
        self._code_size = 9
        self._table_size = 0x101  # 256 literals + clear code
        self._table_max = 0x200   # 512
        self._table_full = False
        self._cache_bits = 0

    def _get_code(self, num_bits, data, pos):
        """
        Read num_bits from the data stream, LSB first.
        Returns (code, new_pos) or (None, pos) if insufficient data.
        """
        result = 0
        bits_needed = num_bits
        total_bits = num_bits

        while bits_needed > 0:
            if self._bits_size == 0:
                if pos[0] >= len(data):
                    return None, pos
                self._bits_data = data[pos[0]]
                pos[0] += 1
                self._bits_size = 8

            use_bits = min(bits_needed, self._bits_size)

            # Extract lowest use_bits from _bits_data
            extracted = self._bits_data & self.BIT_MASKS[use_bits]

            # Position in result: shift left by how many bits we've already placed
            result |= extracted << (total_bits - bits_needed)

            # Consume bits
            self._bits_data >>= use_bits
            self._bits_size -= use_bits
            bits_needed -= use_bits

        return result, pos

    def decompress(self, data, expected_size):
        """
        Decompress LZW data.
        data: bytes after the type+size header (raw LZW bitstream)
        expected_size: expected uncompressed output size
        """
        self.reset()
        self._bits_data = 0
        self._bits_size = 0

        output = bytearray()
        pos = [0]  # mutable position
        prev_string = None

        while len(output) < expected_size:
            code, pos = self._get_code(self._code_size, data, pos)
            if code is None:
                break

            # Update block alignment tracker
            self._cache_bits += self._code_size
            if self._cache_bits >= self._code_size * 8:
                self._cache_bits -= self._code_size * 8

            # Clear code
            if code == 0x100:
                # Skip remaining bits in current block to align
                if self._cache_bits > 0:
                    skip_bits = self._code_size * 8 - self._cache_bits
                    self._get_code(skip_bits, data, pos)

                self.reset()
                prev_string = None
                continue

            # Look up or create string for this code
            if code < self._table_size and code in self._table:
                current_string = self._table[code]
            elif code == self._table_size and prev_string is not None:
                # Special case: code == next table entry
                current_string = prev_string + bytes([prev_string[0]])
            else:
                # Invalid code
                print(f"  WARNING: Invalid LZW code {code} (table_size={self._table_size}, "
                      f"output={len(output)}/{expected_size})")
                break

            # Output
            output.extend(current_string)

            # Add new table entry
            if prev_string is not None and not self._table_full:
                self._table[self._table_size] = prev_string + bytes([current_string[0]])
                self._table_size += 1

                if self._table_size == self._table_max and self._code_size < 12:
                    self._code_size += 1
                    self._table_max = 1 << self._code_size
                elif self._table_size >= self._table_max:
                    self._table_full = True

            prev_string = current_string

        return bytes(output[:expected_size])


def decompress_rle(data, expected_size):
    """
    Dynamix RLE decompression (type 0x01).
    Values <= 127: copy that many literal bytes
    Values > 128: repeat next byte (count = value - 128)
    """
    output = bytearray()
    pos = 0

    while pos < len(data) and len(output) < expected_size:
        cmd = data[pos]
        pos += 1

        if cmd & 0x80:  # repeat
            count = cmd & 0x7F
            if pos >= len(data):
                break
            val = data[pos]
            pos += 1
            output.extend([val] * count)
        else:  # literal
            count = cmd
            if count == 0:
                continue
            output.extend(data[pos:pos+count])
            pos += count

    return bytes(output[:expected_size])


def decompress_section(data):
    """
    Decompress a BIN: or VGA: section's payload.
    Format: type(1B) + uncompressed_size(4B LE) + compressed data
    """
    if len(data) < 5:
        return None

    comp_type = data[0]
    uncomp_size = struct.unpack_from('<I', data, 1)[0]
    payload = data[5:]

    print(f"    Compression type: 0x{comp_type:02X}, uncompressed size: {uncomp_size}")

    if comp_type == 0x00:
        # Uncompressed
        return bytes(payload[:uncomp_size])
    elif comp_type == 0x01:
        # RLE
        return decompress_rle(payload, uncomp_size)
    elif comp_type == 0x02:
        # LZW
        lzw = DynamixLZW()
        return lzw.decompress(payload, uncomp_size)
    else:
        print(f"    Unknown compression type: 0x{comp_type:02X}")
        return None


def parse_scr_file(filepath):
    """
    Parse an SCR file and extract its sections.
    Returns dict with 'bin_data', 'vga_data', 'width', 'height'.
    """
    with open(filepath, 'rb') as f:
        data = f.read()

    filename = os.path.basename(filepath)
    print(f"\nParsing: {filename} ({len(data)} bytes)")

    # Check for text files
    if not data[:4] == b'SCR:':
        print(f"  Not a binary SCR file")
        return None

    result = {
        'width': WIDTH,
        'height': HEIGHT,
        'bin_data': None,
        'vga_data': None,
        'vqt_data': None,
    }

    pos = 0

    # Parse SCR: header
    scr_tag = data[pos:pos+4]
    scr_size_raw = struct.unpack_from('<I', data, pos + 4)[0]
    scr_size = scr_size_raw & 0x7FFFFFFF
    is_container = bool(scr_size_raw & 0x80000000)
    print(f"  SCR: size={scr_size}, container={is_container}")
    pos += 8

    # Parse child sections
    while pos < len(data):
        if pos + 8 > len(data):
            break

        tag = data[pos:pos+4]
        try:
            tag_str = tag.decode('ascii')
        except UnicodeDecodeError:
            break

        size = struct.unpack_from('<I', data, pos + 4)[0]
        size_clean = size & 0x7FFFFFFF

        print(f"  Section '{tag_str}' at offset {pos}, size={size_clean}")

        section_data = data[pos+8:pos+8+size_clean]

        if tag == b'DIM:':
            if size_clean >= 4:
                w = struct.unpack_from('<H', section_data, 0)[0]
                h = struct.unpack_from('<H', section_data, 2)[0]
                result['width'] = w
                result['height'] = h
                print(f"    Dimensions: {w} x {h}")
        elif tag == b'BIN:':
            result['bin_data'] = section_data
        elif tag == b'VGA:':
            result['vga_data'] = section_data
        elif tag == b'VQT:':
            result['vqt_data'] = section_data
            print(f"    VQT (Vector Quantization) — separate codec")
        else:
            print(f"    Unknown section: {tag_str}")

        pos += 8 + size_clean

    return result


def combine_nibbles(bin_pixels, vga_pixels, width, height):
    """
    Combine low nibbles (BIN:) and high nibbles (VGA:) into 8-bit palette indices.
    Each byte contains 2 pixels packed as nibbles.
    BIN: provides low nibbles, VGA: provides high nibbles.

    For loadBitmap4 with highByte=false (BIN):
      pixel[i] = byte & 0x0F, pixel[i+1] = (byte >> 4) & 0x0F
    For loadBitmap4 with highByte=true (VGA):
      pixel[i] = (byte >> 4) & 0x0F, pixel[i+1] = byte & 0x0F

    Wait: the DGDS code says BIN uses low nibble first, VGA uses high nibble first.
    But both sections produce their OWN pixel indices (0-15 each).
    The combination: final_pixel = bin_pixel | (vga_pixel << 4)
    """
    num_pixels = width * height
    packed_size = num_pixels // 2

    # Unpack BIN nibbles (low nibble first)
    bin_unpacked = bytearray(num_pixels)
    for i in range(min(packed_size, len(bin_pixels))):
        byte = bin_pixels[i]
        bin_unpacked[i * 2] = byte & 0x0F
        bin_unpacked[i * 2 + 1] = (byte >> 4) & 0x0F

    # Unpack VGA nibbles (high nibble first)
    vga_unpacked = bytearray(num_pixels)
    for i in range(min(packed_size, len(vga_pixels))):
        byte = vga_pixels[i]
        vga_unpacked[i * 2] = (byte >> 4) & 0x0F
        vga_unpacked[i * 2 + 1] = byte & 0x0F

    # Combine: final = bin_nibble | (vga_nibble << 4)
    pixels = bytearray(num_pixels)
    for i in range(num_pixels):
        pixels[i] = bin_unpacked[i] | (vga_unpacked[i] << 4)

    return pixels


def save_image(pixels, palette, output_path, width=WIDTH, height=HEIGHT, scale=2):
    """Save pixel data as a PNG using the given palette."""
    img = Image.new('RGB', (width, height))

    for y in range(height):
        for x in range(width):
            idx = y * width + x
            if idx < len(pixels):
                color_idx = pixels[idx]
                if color_idx < len(palette):
                    img.putpixel((x, y), palette[color_idx])
                else:
                    img.putpixel((x, y), (255, 0, 255))
            else:
                img.putpixel((x, y), (0, 0, 0))

    if scale > 1:
        img = img.resize((width * scale, height * scale), Image.NEAREST)

    img.save(output_path)
    print(f"  Saved: {output_path}")
    return img


def process_scr_file(scr_path, pal_path=None):
    """Process a single SCR file: parse, decompress, combine, and save."""
    if not os.path.exists(scr_path):
        print(f"File not found: {scr_path}")
        return False

    info = parse_scr_file(scr_path)
    if info is None:
        return False

    width = info['width']
    height = info['height']
    base_name = os.path.splitext(os.path.basename(scr_path))[0]

    # Handle VQT files (not supported yet)
    if info['vqt_data'] is not None and info['bin_data'] is None:
        print(f"  VQT format not yet supported")
        return False

    # Decompress BIN: section
    if info['bin_data'] is None:
        print(f"  No BIN: section found")
        return False

    print(f"  Decompressing BIN: ({len(info['bin_data'])} bytes)...")
    bin_pixels = decompress_section(info['bin_data'])
    if bin_pixels is None:
        print(f"  BIN: decompression failed")
        return False
    print(f"    Decompressed: {len(bin_pixels)} bytes")

    # Decompress VGA: section
    vga_pixels = None
    if info['vga_data'] is not None:
        print(f"  Decompressing VGA: ({len(info['vga_data'])} bytes)...")
        vga_pixels = decompress_section(info['vga_data'])
        if vga_pixels is not None:
            print(f"    Decompressed: {len(vga_pixels)} bytes")

    # Load palette
    palette = None
    if pal_path and os.path.exists(pal_path):
        palette = load_palette(pal_path)
        print(f"  Loaded palette: {os.path.basename(pal_path)}")

    if palette is None:
        # Generate a default VGA palette
        palette = [(i, i, i) for i in range(256)]
        print(f"  Using grayscale fallback palette")

    # Combine nibbles and save
    if vga_pixels is not None:
        # Two-plane 4-bit mode
        print(f"  Combining BIN+VGA nibbles for {width}x{height} image...")
        pixels = combine_nibbles(bin_pixels, vga_pixels, width, height)

        output_path = os.path.join(OUTPUT_DIR, f"scr_{base_name}.png")
        save_image(pixels, palette, output_path, width, height)

        # Also save individual planes for debugging
        bin_debug = bytearray(width * height)
        for i in range(min(len(bin_pixels), width * height // 2)):
            byte = bin_pixels[i]
            bin_debug[i*2] = (byte & 0x0F) * 16
            bin_debug[i*2+1] = ((byte >> 4) & 0x0F) * 16
        debug_pal = [(i, i, i) for i in range(256)]
        save_image(bin_debug, debug_pal,
                   os.path.join(OUTPUT_DIR, f"scr_{base_name}_bin_plane.png"), width, height)
    else:
        # Single plane — might be 8-bit direct or 4-bit
        expected_8bit = width * height
        expected_4bit = width * height // 2

        if len(bin_pixels) == expected_8bit:
            # Direct 8-bit pixels
            output_path = os.path.join(OUTPUT_DIR, f"scr_{base_name}.png")
            save_image(bin_pixels, palette, output_path, width, height)
        elif len(bin_pixels) == expected_4bit:
            # 4-bit packed, single plane (use only low nibble as index)
            pixels = bytearray(expected_8bit)
            for i in range(len(bin_pixels)):
                pixels[i*2] = bin_pixels[i] & 0x0F
                pixels[i*2+1] = (bin_pixels[i] >> 4) & 0x0F
            output_path = os.path.join(OUTPUT_DIR, f"scr_{base_name}.png")
            save_image(pixels, palette, output_path, width, height)
        else:
            print(f"  Unexpected pixel data size: {len(bin_pixels)} "
                  f"(expected {expected_8bit} for 8-bit or {expected_4bit} for 4-bit)")
            # Save what we have anyway
            output_path = os.path.join(OUTPUT_DIR, f"scr_{base_name}_raw.png")
            save_image(bin_pixels, palette, output_path, width, height)

    return True


def find_palette(scr_name):
    """Find the matching palette for a given SCR file."""
    base = os.path.splitext(os.path.basename(scr_name))[0]

    # Try exact match first
    candidates = [
        os.path.join(GAME_DIR, f"{base}.PAL"),
        os.path.join(GAME_DIR, "TTM", f"{base}.PAL"),
        os.path.join(GAME_DIR, "INTRO.PAL"),
        os.path.join(GAME_DIR, "DYNAMIX.PAL"),
    ]

    # Special mappings
    pal_map = {
        "GAMINTRO": "GAMINTRO.PAL",
        "CHAMP": "CHAMP.PAL",
        "INTDYNA": os.path.join("TTM", "INTDYNA.PAL"),
        "CREDIT": os.path.join("TTM", "CREDIT.PAL"),
        "BALL": "INTRO.PAL",
        "KICK": "INTRO.PAL",
    }

    if base in pal_map:
        path = os.path.join(GAME_DIR, pal_map[base])
        if os.path.exists(path):
            return path

    for c in candidates:
        if os.path.exists(c):
            return c

    return None


def main():
    print("=" * 60)
    print("FPS Football Pro '93 -- SCR Screen Decoder")
    print("=" * 60)

    # List all SCR files
    scr_files = []
    for root, dirs, files in os.walk(GAME_DIR):
        for f in files:
            if f.upper().endswith('.SCR'):
                scr_files.append(os.path.join(root, f))

    scr_files.sort()
    print(f"\nFound {len(scr_files)} SCR files:")
    for f in scr_files:
        rel = os.path.relpath(f, GAME_DIR)
        size = os.path.getsize(f)
        print(f"  {rel}: {size:,} bytes")

    print()

    # Process each file
    success_count = 0
    for scr_path in scr_files:
        base = os.path.splitext(os.path.basename(scr_path))[0]

        # Skip text files (INSTALL.SCR)
        with open(scr_path, 'rb') as f:
            magic = f.read(4)
        if magic != b'SCR:':
            print(f"\nSkipping {base} (not binary SCR format)")
            continue

        pal_path = find_palette(scr_path)
        if process_scr_file(scr_path, pal_path):
            success_count += 1

    print(f"\n{'='*60}")
    print(f"Decoded {success_count}/{len(scr_files)} SCR files")
    print(f"Output images saved to {OUTPUT_DIR}/scr_*.png")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
