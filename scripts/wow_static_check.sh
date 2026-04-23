#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WOW_RETAIL="${WOW_RETAIL:-/Applications/World of Warcraft/_retail_}"
ADDON_PATH="$WOW_RETAIL/Interface/AddOns/TrueShot"
BUILD_INFO="$(dirname "$WOW_RETAIL")/.build.info"

echo "WoW retail path: $WOW_RETAIL"
if [[ ! -d "$WOW_RETAIL" ]]; then
    echo "FAIL: WoW retail path not found" >&2
    exit 1
fi

if [[ -d "$WOW_RETAIL/World of Warcraft.app" ]]; then
    echo "OK: World of Warcraft.app found"
else
    echo "FAIL: World of Warcraft.app missing" >&2
    exit 1
fi

if [[ -f "$BUILD_INFO" ]]; then
    version="$(grep -Eo "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" "$BUILD_INFO" | head -n 1 || true)"
    if [[ -n "$version" ]]; then
        echo "OK: installed WoW build: $version"
    fi
fi

blizzard_source="$(find "$WOW_RETAIL/World of Warcraft.app" -maxdepth 6 -type f \( -name "*.lua" -o -name "*.toc" \) -print -quit 2>/dev/null || true)"
if [[ -z "$blizzard_source" ]]; then
    echo "INFO: no readable Blizzard Lua/TOC source files found in the installed app bundle"
else
    echo "OK: readable Blizzard UI source detected under app bundle"
fi

if [[ -L "$ADDON_PATH" ]]; then
    target="$(readlink "$ADDON_PATH" || true)"
    echo "OK: addon symlink exists: $ADDON_PATH -> $target"
    if [[ "$target" != "$ROOT" ]]; then
        echo "WARN: addon symlink does not point at this repo"
    fi
elif [[ -e "$ADDON_PATH" ]]; then
    echo "OK: addon path exists as installed package directory: $ADDON_PATH"
else
    echo "WARN: addon is not installed yet. Run scripts/install_wow_addon.sh"
fi

if [[ -f "$ADDON_PATH/TrueShot.toc" ]]; then
    echo "OK: installed TOC visible"
    grep -E "^## Interface:|^## Title:|^## Version:" "$ADDON_PATH/TrueShot.toc"
fi

if [[ -d "$WOW_RETAIL/WTF/Account" ]]; then
    echo "OK: WTF account directory exists"
else
    echo "INFO: no WTF account directory yet; launch WoW and log in once"
fi

if [[ -d "$WOW_RETAIL/Logs" ]]; then
    echo "OK: Logs directory exists"
    find "$WOW_RETAIL/Logs" -maxdepth 1 -type f -name "*.log" -print | sort
else
    echo "INFO: no Logs directory yet"
fi
