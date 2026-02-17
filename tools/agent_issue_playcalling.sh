#!/usr/bin/env bash
# Agent: verify play-calling parity issue.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT_DIR/tools/agent_issue_verify.sh" --issue playcalling "$@"
