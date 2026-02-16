#!/usr/bin/env python3
"""
Scans generated DDA candidate PNGs in /tmp and ranks them by heuristic quality.
Outputs /tmp/dda_candidate_scores.csv with columns:
  file,unique_colors,entropy,nonzero_pixels,mean,stdev
Use to quickly spot promising decodes without manual eyeballing.
"""

import math
from pathlib import Path
from typing import List, Tuple

from PIL import Image


def score_image(path: Path) -> Tuple[int, float, int, float, float]:
    img = Image.open(path).convert("P")
    data = img.getdata()
    hist = img.histogram()

    total = len(data)
    nonzero = total - hist[0]
    unique = sum(1 for c in hist if c)

    # Entropy over palette indices
    entropy = 0.0
    for count in hist:
        if count == 0:
            continue
        p = count / total
        entropy -= p * math.log2(p)

    # Simple mean/stdev of palette indices
    mean = sum(i * count for i, count in enumerate(hist)) / total
    var = sum(((i - mean) ** 2) * count for i, count in enumerate(hist)) / total
    stdev = math.sqrt(var)

    return unique, entropy, nonzero, mean, stdev


def main():
    out_lines: List[str] = ["file,unique_colors,entropy,nonzero_pixels,mean,stdev"]
    candidates = sorted(Path("/tmp").glob("dda_candidate_*.png"))
    for path in candidates:
        unique, entropy, nonzero, mean, stdev = score_image(path)
        out_lines.append(
            f"{path},{unique},{entropy:.3f},{nonzero},{mean:.2f},{stdev:.2f}"
        )

    out_path = Path("/tmp/dda_candidate_scores.csv")
    out_path.write_text("\n".join(out_lines))
    print(f"Wrote {out_path} ({len(candidates)} files scored)")


if __name__ == "__main__":
    main()
