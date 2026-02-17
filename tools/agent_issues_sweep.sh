#!/usr/bin/env bash
# Agent: run full issue sweep for all ISSUES.md priorities.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT_DIR/tools/agent_issue_verify.sh" --issue all "$@"
