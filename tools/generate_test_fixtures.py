#!/usr/bin/env python3
"""
Generate test fixtures for VisualComparisonTests.swift.

Decodes 5 known sprites from ANIM.DAT using the Python decoder and exports
their metadata and first 128 pixel values as JSON for cross-language validation.

Usage:
    python3 tools/generate_test_fixtures.py

Output:
    footballPro/Tests/Fixtures/sprite_fixtures.json
"""

import json
import os
import sys

# Add tools directory to path so we can import anim_decoder
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anim_decoder import parse_index, decode_animation, IDENTITY_CT

# Game directory
GAME_DIR = os.path.expanduser('~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO')
ANIM_DAT = os.path.join(GAME_DIR, 'ANIM.DAT')

# Output path
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
FIXTURES_DIR = os.path.join(PROJECT_ROOT, 'footballPro', 'Tests', 'Fixtures')
OUTPUT_FILE = os.path.join(FIXTURES_DIR, 'sprite_fixtures.json')

# Sprites to export
SPRITES_TO_EXPORT = [
    ('RCSTAND', 0),
    ('SKRUN', 0),
    ('LMSTAND', 0),
    ('QBPSET', 0),
    ('RBRNWB', 0),
]


def main():
    if not os.path.exists(ANIM_DAT):
        print(f'ERROR: ANIM.DAT not found at {ANIM_DAT}')
        print('Please ensure the game files are at ~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO/')
        sys.exit(1)

    print(f'Reading ANIM.DAT from {ANIM_DAT}...')
    with open(ANIM_DAT, 'rb') as f:
        anim_data = f.read()

    # Parse index
    animations = parse_index(anim_data)
    anim_by_name = {a['name']: a for a in animations}
    print(f'Parsed {len(animations)} animations')

    # Decode each target sprite
    fixtures = []
    for anim_name, sprite_id in SPRITES_TO_EXPORT:
        if anim_name not in anim_by_name:
            print(f'WARNING: Animation {anim_name} not found in index, skipping')
            continue

        entry = anim_by_name[anim_name]
        decoded = decode_animation(anim_data, entry, IDENTITY_CT)

        if sprite_id not in decoded['sprites']:
            print(f'WARNING: Sprite {sprite_id} not found in {anim_name}, skipping')
            continue

        sprite = decoded['sprites'][sprite_id]
        pixels = list(sprite['pixels'])
        first_128 = pixels[:128]

        fixture = {
            'name': anim_name,
            'spriteID': sprite_id,
            'width': sprite['width'],
            'height': sprite['height'],
            'pixels': first_128,
        }
        fixtures.append(fixture)
        print(f'  {anim_name} sprite {sprite_id}: {sprite["width"]}x{sprite["height"]}, '
              f'{len(pixels)} total pixels, exporting first {len(first_128)}')

    # Write output
    os.makedirs(FIXTURES_DIR, exist_ok=True)
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(fixtures, f, indent=2)

    print(f'\nWrote {len(fixtures)} fixtures to {OUTPUT_FILE}')


if __name__ == '__main__':
    main()
