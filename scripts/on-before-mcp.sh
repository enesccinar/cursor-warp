#!/bin/bash
# beforeMCPExecution → permission_request + ⏸ tab title

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

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "MCP"' 2>/dev/null)
RAW_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)
if echo "$RAW_INPUT" | jq -e 'type == "string"' >/dev/null 2>&1; then
    TOOL_INPUT=$(echo "$RAW_INPUT" | jq -c 'fromjson? // {}' 2>/dev/null)
else
    TOOL_INPUT="$RAW_INPUT"
fi
[ -z "$TOOL_INPUT" ] && TOOL_INPUT='{}'

SUMMARY="Wants to run $TOOL_NAME"
SERVER=$(echo "$INPUT" | jq -r '.mcp_server_name // empty' 2>/dev/null)
if [ -n "$SERVER" ]; then
    SUMMARY="$SUMMARY ($SERVER)"
fi

BODY=$(build_payload "$INPUT" "permission_request" \
    --arg summary "$SUMMARY" \
    --arg query "$(format_tab_title "$CURSOR_WARP_SYMBOL_BLOCKED" "$DISPLAY_TITLE")" \
    --arg tool_name "$TOOL_NAME" \
    --argjson tool_input "$TOOL_INPUT")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
