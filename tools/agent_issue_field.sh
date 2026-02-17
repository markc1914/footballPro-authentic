#!/usr/bin/env bash
# Agent: verify field geometry/details parity issue.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT_DIR/tools/agent_issue_verify.sh" --issue field_geometry "$@"
