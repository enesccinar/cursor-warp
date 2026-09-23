#!/bin/bash
# postToolUse → tool_complete + resume spinner

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=should-use-structured.sh
source "$SCRIPT_DIR/should-use-structured.sh"
# shellcheck source=tab-title.sh
source "$SCRIPT_DIR/tab-title.sh"

INPUT=$(cat)
SESSION_ID=$(extract_session_id_from_input "$INPUT")
DISPLAY_TITLE=$(extract_display_title "$INPUT")
[ -z "$DISPLAY_TITLE" ] && DISPLAY_TITLE=$(read_display_title "$SESSION_ID")
start_title_spinner "$SESSION_ID" "$DISPLAY_TITLE"

if ! should_use_structured; then
    exit 0
fi

# shellcheck source=build-payload.sh
source "$SCRIPT_DIR/build-payload.sh"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

BODY=$(build_payload "$INPUT" "tool_complete" \
    --arg tool_name "$TOOL_NAME" \
    --arg query "$(format_tab_title "⠋" "$DISPLAY_TITLE")")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
