#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ralph-loop.sh <max_iters> <sentinel> <iter_cmd>
# Example:
#   ralph-loop.sh 5 "STATUS: COMPLETE" "bash -lc 'pnpm test || true'"

MAX_ITERS="${1:-5}"
SENTINEL="${2:-STATUS: COMPLETE}"
ITER_CMD="${3:-true}"
PLAN="IMPLEMENTATION_PLAN.md"
LOG_DIR=".openclaw/.ralph"
LOG_FILE="$LOG_DIR/loop.log"
mkdir -p "$LOG_DIR"

for i in $(seq 1 "$MAX_ITERS"); do
  echo "=== iteration $i/$MAX_ITERS ===" | tee -a "$LOG_FILE"

  # Run iteration command supplied by the caller (agent/tooling)
  bash -lc "$ITER_CMD" | tee -a "$LOG_FILE"

  if [[ -f "$PLAN" ]] && grep -Fq "$SENTINEL" "$PLAN"; then
    echo "COMPLETED: sentinel found" | tee -a "$LOG_FILE"
    exit 0
  fi

done

echo "MAX_ITERATIONS_REACHED" | tee -a "$LOG_FILE"
exit 1
