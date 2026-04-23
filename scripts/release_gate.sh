#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if command -v lua5.4 >/dev/null 2>&1; then
    LUA_BIN="lua5.4"
elif command -v lua-5.4 >/dev/null 2>&1; then
    LUA_BIN="lua-5.4"
elif [[ -x /opt/homebrew/opt/lua@5.4/bin/lua ]]; then
    LUA_BIN="/opt/homebrew/opt/lua@5.4/bin/lua"
elif command -v lua >/dev/null 2>&1; then
    LUA_BIN="lua"
else
    echo "Lua 5.4 not found. Install with: brew install lua@5.4" >&2
    exit 127
fi

if command -v luac5.4 >/dev/null 2>&1; then
    LUAC_BIN="luac5.4"
elif command -v luac-5.4 >/dev/null 2>&1; then
    LUAC_BIN="luac-5.4"
elif [[ -x /opt/homebrew/opt/lua@5.4/bin/luac ]]; then
    LUAC_BIN="/opt/homebrew/opt/lua@5.4/bin/luac"
elif command -v luac >/dev/null 2>&1; then
    LUAC_BIN="luac"
else
    echo "luac not found. Install Lua compiler with: brew install lua@5.4" >&2
    exit 127
fi

echo "== Lua syntax =="
"$LUAC_BIN" -p *.lua State/*.lua Profiles/*.lua tests/*.lua scripts/*.lua

echo "== Shell syntax =="
bash -n scripts/install_wow_addon.sh scripts/read_wow_smoke.sh scripts/wow_static_check.sh scripts/watch_wow_smoke.sh scripts/release_gate.sh

echo "== Compliance scan =="
scripts/compliance_scan.sh

echo "== Unit tests =="
scripts/run_tests.sh

echo "== Diff whitespace =="
git diff --check

if [[ "${1:-}" == "--wow" ]]; then
    WOW_RETAIL="${WOW_RETAIL:-/Applications/World of Warcraft/_retail_}"
    WTF_DIR="$WOW_RETAIL/WTF/Account"
    tmp_list="$(mktemp)"
    trap 'rm -f "$tmp_list"' EXIT

    echo "== WoW static check =="
    scripts/wow_static_check.sh

    find "$WTF_DIR" -path "*/SavedVariables/TrueShot.lua" -type f -print0 > "$tmp_list"
    if [[ ! -s "$tmp_list" ]]; then
        echo "No TrueShot SavedVariables file found for WoW smoke gate." >&2
        exit 1
    fi
    report_file="$(xargs -0 ls -t < "$tmp_list" | head -n 1)"

    echo "== WoW smoke gate =="
    "$LUA_BIN" scripts/check_wow_smoke.lua "$report_file"
else
    echo "== WoW smoke gate =="
    echo "Skipped. Run scripts/release_gate.sh --wow after in-client smoke tests."
fi

echo "Release gate passed."
