#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_VALUE="$(tr -d '[:space:]' < "$ROOT/VERSION")"
ZIP_PATH="${1:-$ROOT/dist/TrueShot-$VERSION_VALUE.zip}"
WOW_RETAIL="${WOW_RETAIL:-/Applications/World of Warcraft/_retail_}"
ADDONS_DIR="$WOW_RETAIL/Interface/AddOns"
TARGET="$ADDONS_DIR/TrueShot"

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "Package not found: $ZIP_PATH" >&2
    echo "Build it first with: scripts/build_package.sh --wow" >&2
    exit 1
fi

if [[ ! -d "$WOW_RETAIL" ]]; then
    echo "WoW retail path not found: $WOW_RETAIL" >&2
    exit 1
fi

mkdir -p "$ADDONS_DIR"

if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    if [[ -L "$TARGET" ]]; then
        rm "$TARGET"
    else
        echo "Refusing to replace non-symlink addon path: $TARGET" >&2
        echo "Move it aside manually if you want to install the package artifact there." >&2
        exit 2
    fi
fi

unzip -q "$ZIP_PATH" -d "$ADDONS_DIR"

if [[ ! -f "$TARGET/TrueShot.toc" ]]; then
    echo "Installed artifact is missing TrueShot.toc" >&2
    exit 1
fi

if ! grep -q "^## Version: $VERSION_VALUE$" "$TARGET/TrueShot.toc"; then
    echo "Installed artifact TOC does not match version $VERSION_VALUE" >&2
    exit 1
fi

echo "Installed package artifact: $ZIP_PATH -> $TARGET"
