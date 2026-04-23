#!/usr/bin/env bash
set -euo pipefail

WOW_RETAIL="${WOW_RETAIL:-/Applications/World of Warcraft/_retail_}"
WTF_DIR="$WOW_RETAIL/WTF/Account"

if [[ ! -d "$WTF_DIR" ]]; then
    echo "No WoW account SavedVariables directory found yet: $WTF_DIR" >&2
    echo "Log into WoW once, enable TrueShot, run /ts smoke, then /reload or logout." >&2
    exit 1
fi

tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT
find "$WTF_DIR" -path "*/SavedVariables/TrueShot.lua" -type f -print0 > "$tmp_list"

if [[ ! -s "$tmp_list" ]]; then
    echo "No TrueShot SavedVariables file found." >&2
    echo "In game: run /ts smoke, then /reload or logout so WoW writes SavedVariables." >&2
    exit 1
fi

report_file="$(xargs -0 ls -t < "$tmp_list" | head -n 1)"

echo "SavedVariables: $report_file"

if ! grep -q "smokeReport" "$report_file"; then
    echo "No smokeReport found in SavedVariables." >&2
    echo "In game: run /ts smoke, then /reload or logout." >&2
    exit 2
fi

echo
echo "Smoke report summary:"
grep -nE "smokeReport|smokeHistory|timestamp|buildVersion|buildNumber|interfaceVersion|acAvailable|profileID|profile|specID|heroTalentSubTreeID|strict|passed|failed|total|name|ok|detail|reasonCode|source" "$report_file" || true

echo
echo "Smoke profiles found:"
grep -nE "\\[\"profile\"\\]|\\[\"profileID\"\\]|\\[\"timestamp\"\\]|\\[\"passed\"\\]|\\[\"failed\"\\]" "$report_file" || true

if command -v lua5.4 >/dev/null 2>&1; then
    LUA_BIN="lua5.4"
elif command -v lua-5.4 >/dev/null 2>&1; then
    LUA_BIN="lua-5.4"
elif [[ -x /opt/homebrew/opt/lua@5.4/bin/lua ]]; then
    LUA_BIN="/opt/homebrew/opt/lua@5.4/bin/lua"
else
    LUA_BIN=""
fi

if [[ -n "$LUA_BIN" ]]; then
    echo
    echo "Smoke history table:"
    "$LUA_BIN" "$(dirname "${BASH_SOURCE[0]}")/summarize_wow_smoke.lua" "$report_file" || true
fi

echo
echo "Relevant logs:"
for log in "$WOW_RETAIL/Logs/taint.log" "$WOW_RETAIL/Logs/FrameXML.log"; do
    if [[ -f "$log" ]]; then
        echo "- $log"
        grep -ni "trueshot" "$log" | tail -n 20 || true
    fi
done
