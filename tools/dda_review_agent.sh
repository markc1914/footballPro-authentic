#!/usr/bin/env bash
# Collects top-ranked DDA candidate PNGs into /tmp/dda_review for quick viewing.
# Relies on /tmp/dda_top_candidates.txt produced by dda_rank_agent.py.

set -euo pipefail

DEST="/tmp/dda_review"
SRC_LIST="/tmp/dda_top_candidates.txt"

mkdir -p "$DEST"

if [[ ! -f "$SRC_LIST" ]]; then
  echo "Missing $SRC_LIST; run tools/dda_rank_agent.py first."
  exit 1
fi

echo "Copying top candidates to $DEST"
while IFS= read -r line; do
  # Expect format: "1. entropy=... file=/tmp/dda_candidate_....png"
  file=$(echo "$line" | sed -n 's/.*file=\\(.*\\.png\\).*/\\1/p')
  if [[ -n "$file" && -f "$file" ]]; then
    cp "$file" "$DEST"/
  fi
done < "$SRC_LIST"

echo "Done. Review folder: $DEST"
