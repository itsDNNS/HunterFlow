#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WOW_RETAIL="${WOW_RETAIL:-/Applications/World of Warcraft/_retail_}"
ADDONS_DIR="$WOW_RETAIL/Interface/AddOns"
TARGET="$ADDONS_DIR/TrueShot"

if [[ ! -d "$WOW_RETAIL" ]]; then
    echo "WoW retail path not found: $WOW_RETAIL" >&2
    exit 1
fi

mkdir -p "$ADDONS_DIR"

if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    if [[ -L "$TARGET" ]]; then
        current="$(readlink "$TARGET" || true)"
        if [[ "$current" == "$ROOT" ]]; then
            echo "TrueShot already linked: $TARGET -> $ROOT"
            exit 0
        fi
        rm "$TARGET"
    else
        echo "Refusing to replace non-symlink addon path: $TARGET" >&2
        echo "Move it aside manually if you want this repo linked there." >&2
        exit 2
    fi
fi

ln -s "$ROOT" "$TARGET"
echo "Linked TrueShot addon: $TARGET -> $ROOT"
