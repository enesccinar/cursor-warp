#!/bin/bash
# sessionStart → session_start + idle tab title

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=should-use-structured.sh
source "$SCRIPT_DIR/should-use-structured.sh"
# shellcheck source=tab-title.sh
source "$SCRIPT_DIR/tab-title.sh"

if ! command -v jq &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
SESSION_ID=$(extract_session_id_from_input "$INPUT")
DISPLAY_TITLE=$(extract_display_title "$INPUT")
set_static_tab_title "$SESSION_ID" "$CURSOR_WARP_SYMBOL_IDLE" "$DISPLAY_TITLE"

if ! should_use_structured; then
    exit 0
fi

# shellcheck source=build-payload.sh
source "$SCRIPT_DIR/build-payload.sh"

PLUGIN_VERSION=$(tr -d '[:space:]' < "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")
BODY=$(build_payload "$INPUT" "session_start" \
    --arg plugin_version "$PLUGIN_VERSION" \
    --arg query "$(format_tab_title "$CURSOR_WARP_SYMBOL_IDLE" "$DISPLAY_TITLE")")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
