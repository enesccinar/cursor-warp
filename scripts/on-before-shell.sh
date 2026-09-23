#!/bin/bash
# beforeShellExecution → permission_request + ⏸ tab title

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=should-use-structured.sh
source "$SCRIPT_DIR/should-use-structured.sh"
# shellcheck source=tab-title.sh
source "$SCRIPT_DIR/tab-title.sh"

INPUT=$(cat)
SESSION_ID=$(extract_session_id_from_input "$INPUT")
DISPLAY_TITLE=$(extract_display_title "$INPUT")
[ -z "$DISPLAY_TITLE" ] && DISPLAY_TITLE=$(read_display_title "$SESSION_ID")
set_static_tab_title "$SESSION_ID" "$CURSOR_WARP_SYMBOL_BLOCKED" "$DISPLAY_TITLE"

if ! should_use_structured; then
    exit 0
fi

# shellcheck source=build-payload.sh
source "$SCRIPT_DIR/build-payload.sh"

TOOL_NAME="Shell"
COMMAND=$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -c '{command: (.command // "")}' 2>/dev/null)
[ -z "$TOOL_INPUT" ] && TOOL_INPUT='{}'

SUMMARY="Wants to run Shell"
if [ -n "$COMMAND" ]; then
    TOOL_PREVIEW="$COMMAND"
    if [ ${#TOOL_PREVIEW} -gt 120 ]; then
        TOOL_PREVIEW="${TOOL_PREVIEW:0:117}..."
    fi
    SUMMARY="$SUMMARY: $TOOL_PREVIEW"
fi

BODY=$(build_payload "$INPUT" "permission_request" \
    --arg summary "$SUMMARY" \
    --arg query "$(format_tab_title "$CURSOR_WARP_SYMBOL_BLOCKED" "$DISPLAY_TITLE")" \
    --arg tool_name "$TOOL_NAME" \
    --argjson tool_input "$TOOL_INPUT")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
