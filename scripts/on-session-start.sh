#!/bin/bash
# sessionStart → session_start

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=should-use-structured.sh
source "$SCRIPT_DIR/should-use-structured.sh"

if ! should_use_structured; then
    exit 0
fi

if ! command -v jq &>/dev/null; then
    exit 0
fi

# shellcheck source=build-payload.sh
source "$SCRIPT_DIR/build-payload.sh"

INPUT=$(cat)
PLUGIN_VERSION=$(tr -d '[:space:]' < "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")

BODY=$(build_payload "$INPUT" "session_start" \
    --arg plugin_version "$PLUGIN_VERSION")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
