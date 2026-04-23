#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-5}"
started="$(date +%s)"
tmp_output="$(mktemp)"
trap 'rm -f "$tmp_output"' EXIT

echo "Waiting up to ${TIMEOUT_SECONDS}s for TrueShot smoke report."
echo "In game: enable TrueShot, log into a Hunter, run /ts smoke, then /reload or logout."

while true; do
    if "$SCRIPT_DIR/read_wow_smoke.sh" > "$tmp_output" 2>&1; then
        cat "$tmp_output"
        exit 0
    fi

    now="$(date +%s)"
    elapsed="$((now - started))"
    if (( elapsed >= TIMEOUT_SECONDS )); then
        cat "$tmp_output" >&2
        echo "Timed out after ${elapsed}s waiting for smoke report." >&2
        exit 1
    fi

    sleep "$INTERVAL_SECONDS"
done
