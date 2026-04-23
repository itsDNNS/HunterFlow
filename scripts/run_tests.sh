#!/usr/bin/env sh
set -eu

if command -v lua5.4 >/dev/null 2>&1; then
  LUA_BIN="lua5.4"
elif command -v lua-5.4 >/dev/null 2>&1; then
  LUA_BIN="lua-5.4"
elif [ -x /opt/homebrew/opt/lua@5.4/bin/lua ]; then
  LUA_BIN="/opt/homebrew/opt/lua@5.4/bin/lua"
elif command -v lua >/dev/null 2>&1; then
  LUA_BIN="lua"
else
  echo "Lua 5.4 not found. Install with: brew install lua@5.4" >&2
  exit 127
fi

for f in tests/*.lua; do
  echo "RUN:$f"
  "$LUA_BIN" "$f"
done
