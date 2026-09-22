#!/usr/bin/env bash
# Remove cursor-warp hook entries from ~/.cursor/hooks.json.
# Use --purge to also delete the install directory.
set -euo pipefail

INSTALL_DIR="${CURSOR_WARP_INSTALL_DIR:-$HOME/.cursor/plugins/cursor-warp}"
HOOKS_FILE="${CURSOR_WARP_HOOKS_FILE:-$HOME/.cursor/hooks.json}"
PURGE=0

for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        -h|--help)
            echo "Usage: uninstall.sh [--purge]"
            exit 0
            ;;
    esac
done

if [ ! -f "$HOOKS_FILE" ]; then
    echo "cursor-warp: no hooks file at $HOOKS_FILE"
else
    backup="${HOOKS_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$HOOKS_FILE" "$backup"
    tmp=$(mktemp)
    jq '
      .hooks |= with_entries(
        .value |= map(select((.command // "") | tostring | contains("cursor-warp/scripts/") | not))
      )
      | .hooks |= with_entries(select(.value | length > 0))
    ' "$HOOKS_FILE" > "$tmp"
    mv "$tmp" "$HOOKS_FILE"
    echo "cursor-warp: removed hook entries (backup: $backup)"
fi

if [ "$PURGE" -eq 1 ]; then
    rm -rf "$INSTALL_DIR"
    echo "cursor-warp: removed $INSTALL_DIR"
else
    echo "cursor-warp: left $INSTALL_DIR in place (pass --purge to delete)"
fi
