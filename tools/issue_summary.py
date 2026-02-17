#!/usr/bin/env python3
"""Build issue-focused summaries from screenshot/reference comparison results."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from statistics import mean, median
from typing import Iterable


ISSUE_ORDER = [
    "playcalling",
    "field_geometry",
    "overlay_styling",
    "referee_popup",
    "menu_endstate",
]

ISSUE_DEFS: dict[str, dict[str, object]] = {
    "playcalling": {
        "title": "Play-calling screen mismatch",
        "impact": "High",
        "screenshots": [
            "03_playcalling_kickoff.png",
            "06_playcalling_defense.png",
            "12_playcalling_offense.png",
            "15_playcalling_specialteams.png",
            "18_playcalling_postscore.png",
            "20_playcalling_defense2.png",
        ],
    },
    "field_geometry": {
        "title": "Field presentation mismatch",
        "impact": "High",
        "screenshots": [
            "04_field_kickoff.png",
            "07_presnap.png",
            "10_presnap_formation2.png",
            "13_presnap_goalline.png",
            "16_fieldgoal_kick.png",
            "19_field_kickoff_return.png",
            "27_field_sprites_presnap.png",
            "28_field_sprites_midplay.png",
        ],
    },
    "overlay_styling": {
        "title": "Play result/overlay styling divergence",
        "impact": "High",
        "screenshots": [
            "05_play_result.png",
            "09_replay_controls.png",
            "11_play_result_injury.png",
            "14_play_result_4thdown.png",
            "29_play_result_sprites.png",
        ],
    },
    "referee_popup": {
        "title": "Referee popup style mismatch",
        "impact": "Medium",
        "screenshots": [
            "08_referee_firstdown.png",
            "17_referee_good.png",
        ],
    },
    "menu_endstate": {
        "title": "Main menu/end-state UI mismatch",
        "impact": "Medium",
        "screenshots": [
            "01_splash.png",
            "02_game_dialog.png",
            "21_main_menu.png",
            "22_team_selection.png",
            "23_roster_view.png",
            "24_player_card.png",
            "25_pregame_narration.png",
            "26_extra_point_choice.png",
            "30_halftime.png",
            "31_game_over.png",
            "32_pause_menu.png",
        ],
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compare-json", required=True, help="Path to compare report JSON.")
    parser.add_argument("--output-dir", required=True, help="Directory to write summaries.")
    parser.add_argument(
        "--issue",
        default="all",
        choices=["all"] + ISSUE_ORDER,
        help="Issue key to summarize. Default: all.",
    )
    return parser.parse_args()


def safe_stats(values: Iterable[float]) -> dict[str, float | int]:
    vals = list(values)
    if not vals:
        return {"count": 0, "mean": 0.0, "median": 0.0, "min": 0.0, "max": 0.0}
    return {
        "count": len(vals),
        "mean": float(mean(vals)),
        "median": float(median(vals)),
        "min": float(min(vals)),
        "max": float(max(vals)),
    }


def clean_row(row: dict[str, object]) -> dict[str, object]:
    out: dict[str, object] = {
        "screenshot": row.get("screenshot"),
        "combined": float(row.get("combined", 0.0)),
        "ssim_raw": float(row.get("ssim_raw", 0.0)),
        "ssim_edge": float(row.get("ssim_edge", 0.0)),
        "best_ref": row.get("best_ref"),
        "best_ref_index": row.get("best_ref_index"),
        "best_ref_time": row.get("best_ref_time"),
    }
    return out


def summarize_issue(
    issue_key: str,
    issue_cfg: dict[str, object],
    rows_by_name: dict[str, dict[str, object]],
) -> dict[str, object]:
    screenshot_names = [str(name) for name in issue_cfg["screenshots"]]
    matched: list[dict[str, object]] = []
    missing: list[str] = []

    for name in screenshot_names:
        row = rows_by_name.get(name)
        if row is None:
            missing.append(name)
            continue
        matched.append(clean_row(row))

    matched_sorted = sorted(matched, key=lambda r: float(r["combined"]))
    stats = safe_stats(float(r["combined"]) for r in matched_sorted)
    # Distance from perfect score. 0.0 means perfect parity, 1.0 means total divergence.
    divergence = float(1.0 - stats["mean"]) if stats["count"] else 1.0
    divergence = float(max(0.0, min(1.0, divergence)))

    return {
        "issue_key": issue_key,
        "title": issue_cfg["title"],
        "impact": issue_cfg["impact"],
        "target_screenshots": screenshot_names,
        "stats": stats,
        "divergence_index": divergence,
        "missing_screenshots": missing,
        "worst_3": matched_sorted[:3],
        "best_3": list(reversed(matched_sorted[-3:])),
    }


def fmt_score(value: float) -> str:
    if math.isnan(value):
        return "nan"
    return f"{value:.4f}"


def write_markdown(report: dict[str, object], out_path: Path) -> None:
    lines: list[str] = []
    lines.append("# Issue Comparison Summary")
    lines.append("")
    lines.append(f"- Source compare report: `{report['source_compare_json']}`")
    lines.append(f"- Total screenshots scored: `{report['rows_scored']}`")
    lines.append("")
    lines.append("## Issue Scores")
    lines.append("")
    for issue in report["issues"]:
        stats = issue["stats"]
        lines.append(f"### {issue['title']} ({issue['impact']})")
        lines.append(
            f"- Mean score: `{fmt_score(float(stats['mean']))}` "
            f"(divergence index `{fmt_score(float(issue['divergence_index']))}`)"
        )
        lines.append(
            f"- Count: `{stats['count']}` | min: `{fmt_score(float(stats['min']))}` "
            f"| max: `{fmt_score(float(stats['max']))}`"
        )
        if issue["missing_screenshots"]:
            joined = ", ".join(f"`{name}`" for name in issue["missing_screenshots"])
            lines.append(f"- Missing screenshots: {joined}")
        if issue["worst_3"]:
            lines.append("- Worst 3:")
            for row in issue["worst_3"]:
                lines.append(
                    "  "
                    + f"- `{row['screenshot']}` score `{fmt_score(float(row['combined']))}` "
                    + f"best ref `{row['best_ref']}`"
                )
        lines.append("")

    out_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    compare_path = Path(args.compare_json)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    data = json.loads(compare_path.read_text(encoding="utf-8"))
    rows = data.get("rows", [])
    rows_by_name = {str(row.get("screenshot")): row for row in rows}

    issue_keys = ISSUE_ORDER if args.issue == "all" else [args.issue]
    issue_reports: list[dict[str, object]] = []
    for key in issue_keys:
        issue_reports.append(summarize_issue(key, ISSUE_DEFS[key], rows_by_name))

    summary = {
        "source_compare_json": str(compare_path),
        "rows_scored": len(rows),
        "issues": issue_reports,
    }

    summary_json = output_dir / "issues_summary.json"
    summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_markdown(summary, output_dir / "issues_summary.md")

    for issue in issue_reports:
        out_path = output_dir / f"issue_{issue['issue_key']}.json"
        out_path.write_text(json.dumps(issue, indent=2), encoding="utf-8")

    print(f"[OK] Wrote {summary_json}")
    for issue in issue_reports:
        stats = issue["stats"]
        print(
            f"[ISSUE] {issue['issue_key']}: "
            f"mean={fmt_score(float(stats['mean']))} "
            f"divergence={fmt_score(float(issue['divergence_index']))} "
            f"count={stats['count']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
