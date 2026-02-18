#!/usr/bin/env bash
# Agent: verify main menu/end-state parity issue.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT_DIR/tools/agent_issue_verify.sh" --issue menu_endstate "$@"
