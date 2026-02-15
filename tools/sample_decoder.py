#!/usr/bin/env python3
"""
SAMPLE.DAT Decoder for Front Page Sports: Football Pro (1993, Dynamix/Sierra)

File format:
  - uint16 LE: sample count (115)
  - (count + 1) × uint32 LE: offset table (last entry = file size, sentinel)
  - Raw audio data: 8-bit unsigned PCM, 11025 Hz, mono

Each sample is raw PCM with no per-sample header. Sample boundaries are
determined by consecutive offsets in the table.

Usage:
  python3 sample_decoder.py [--input SAMPLE.DAT] [--output /tmp/fps_samples/]
                            [--rate 11025] [--list] [--extract N]
"""

import struct
import wave
import os
import sys
import argparse

DEFAULT_INPUT = os.path.expanduser(
    "~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO/SAMPLE.DAT"
)
DEFAULT_OUTPUT = "/tmp/fps_samples"
DEFAULT_RATE = 11025


def parse_sample_dat(filepath):
    """Parse SAMPLE.DAT and return (count, offsets, raw_data)."""
    with open(filepath, "rb") as f:
        data = f.read()

    file_size = len(data)
    count = struct.unpack_from("<H", data, 0)[0]

    # Read count+1 offsets (last is sentinel = file size)
    offsets = []
    for i in range(count + 1):
        off = struct.unpack_from("<I", data, 2 + i * 4)[0]
        offsets.append(off)

    # Validate
    expected_table_end = 2 + (count + 1) * 4
    assert offsets[0] == expected_table_end, (
        f"First offset {offsets[0]} != expected {expected_table_end}"
    )
    assert offsets[-1] == file_size, (
        f"Sentinel offset {offsets[-1]} != file size {file_size}"
    )

    return count, offsets, data


def extract_sample(data, offsets, index):
    """Extract raw PCM bytes for sample at given index."""
    start = offsets[index]
    end = offsets[index + 1]
    return data[start:end]


def write_wav(filepath, pcm_data, sample_rate=DEFAULT_RATE):
    """Write 8-bit unsigned PCM data as a WAV file."""
    with wave.open(filepath, "wb") as wav:
        wav.setnchannels(1)       # mono
        wav.setsampwidth(1)       # 8-bit
        wav.setframerate(sample_rate)
        wav.writeframes(pcm_data)


def categorize_sample(index, size, pcm_data):
    """Heuristic categorization based on size and waveform characteristics."""
    duration = size / DEFAULT_RATE

    # Compute basic stats
    vals = list(pcm_data)
    if not vals:
        return "empty"

    avg = sum(vals) / len(vals)
    max_val = max(vals)
    min_val = min(vals)
    amplitude = (max_val - min_val) / 2.0

    # Very short samples
    if duration < 0.02:
        return "silence/marker"

    # Samples 83-92 are all ~0.333s — likely numbered count sounds or similar
    if 83 <= index <= 92:
        return "count/number"

    # Very long samples (>2s) are likely crowd/ambient
    if duration > 2.0:
        return "crowd/ambient"

    # High amplitude, medium duration — hits, whistles
    if amplitude > 80 and duration < 0.6:
        return "impact/whistle"

    # Medium amplitude, longer — crowd reactions
    if duration > 0.8:
        return "crowd/reaction"

    return "effect"


def main():
    parser = argparse.ArgumentParser(
        description="Decode SAMPLE.DAT from FPS Football Pro '93"
    )
    parser.add_argument(
        "--input", "-i", default=DEFAULT_INPUT,
        help="Path to SAMPLE.DAT"
    )
    parser.add_argument(
        "--output", "-o", default=DEFAULT_OUTPUT,
        help="Output directory for WAV files"
    )
    parser.add_argument(
        "--rate", "-r", type=int, default=DEFAULT_RATE,
        help="Sample rate in Hz (default: 11025)"
    )
    parser.add_argument(
        "--list", "-l", action="store_true",
        help="List samples without extracting"
    )
    parser.add_argument(
        "--extract", "-e", type=int, nargs="*",
        help="Extract only specific sample indices"
    )
    args = parser.parse_args()

    # Parse the file
    print(f"Reading: {args.input}")
    count, offsets, data = parse_sample_dat(args.input)
    file_size = len(data)

    print(f"File size: {file_size:,} bytes")
    print(f"Samples:   {count}")
    print(f"Offset table: {2 + (count + 1) * 4} bytes (uint16 count + {count + 1} × uint32 offsets)")
    print(f"Audio data: {offsets[-1] - offsets[0]:,} bytes")
    print(f"Format:    8-bit unsigned PCM, {args.rate} Hz, mono")
    print()

    # Catalog
    print(f"{'#':>4}  {'Offset':>8}  {'Size':>7}  {'Duration':>8}  {'Category'}")
    print("-" * 60)

    total_duration = 0.0
    sizes = []

    for i in range(count):
        pcm = extract_sample(data, offsets, i)
        size = len(pcm)
        duration = size / args.rate
        total_duration += duration
        sizes.append(size)
        category = categorize_sample(i, size, pcm)

        print(f"{i:4d}  0x{offsets[i]:06X}  {size:7,}  {duration:7.3f}s  {category}")

    print("-" * 60)
    print(f"Total: {count} samples, {sum(sizes):,} bytes, {total_duration:.1f}s ({total_duration/60:.1f} min)")
    print(f"Shortest: sample {sizes.index(min(sizes))} ({min(sizes)} bytes, {min(sizes)/args.rate:.3f}s)")
    print(f"Longest:  sample {sizes.index(max(sizes))} ({max(sizes):,} bytes, {max(sizes)/args.rate:.3f}s)")
    print()

    if args.list:
        return

    # Extract
    os.makedirs(args.output, exist_ok=True)

    indices = args.extract if args.extract is not None else range(count)

    extracted = 0
    for i in indices:
        if i < 0 or i >= count:
            print(f"Warning: sample {i} out of range (0-{count-1}), skipping")
            continue

        pcm = extract_sample(data, offsets, i)
        wav_path = os.path.join(args.output, f"sample_{i:03d}.wav")
        write_wav(wav_path, pcm, args.rate)
        extracted += 1

    print(f"Extracted {extracted} WAV files to {args.output}/")


if __name__ == "__main__":
    main()
