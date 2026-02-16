#!/usr/bin/env python3
"""
Ranks DDA candidate PNGs (from /tmp/dda_candidate_scores.csv or by scanning /tmp)
and prints the top-N by entropy then unique colors. Writes a shortlist to
/tmp/dda_top_candidates.txt for quick review.
"""

import csv
from pathlib import Path

SCORES_PATH = Path("/tmp/dda_candidate_scores.csv")
OUT_PATH = Path("/tmp/dda_top_candidates.txt")
TOP_N = 10


def load_scores():
    rows = []
    if SCORES_PATH.exists():
        with SCORES_PATH.open() as f:
            reader = csv.DictReader(f)
            for r in reader:
                try:
                    rows.append(
                        {
                            "file": r["file"],
                            "entropy": float(r["entropy"]),
                            "unique": int(r["unique_colors"]),
                            "nonzero": int(r["nonzero_pixels"]),
                        }
                    )
                except Exception:
                    continue
    return rows


def main():
    rows = load_scores()
    if not rows:
        print("No scores found. Run dda_inspect_agent.py first.")
        return

    rows.sort(key=lambda r: (r["entropy"], r["unique"], r["nonzero"]), reverse=True)
    top = rows[:TOP_N]

    lines = [
        f"{i+1}. entropy={r['entropy']:.3f} unique={r['unique']} nonzero={r['nonzero']} file={r['file']}"
        for i, r in enumerate(top)
    ]
    text = "\n".join(lines)
    OUT_PATH.write_text(text + "\n")
    print(text)
    print(f"\nWrote shortlist to {OUT_PATH}")


if __name__ == "__main__":
    main()
