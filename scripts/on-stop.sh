#!/bin/bash
# stop → stop + ✓ tab title

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=should-use-structured.sh
source "$SCRIPT_DIR/should-use-structured.sh"
# shellcheck source=tab-title.sh
source "$SCRIPT_DIR/tab-title.sh"

INPUT=$(cat)

STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

SESSION_ID=$(extract_session_id_from_input "$INPUT")
DISPLAY_TITLE=$(extract_display_title "$INPUT")
[ -z "$DISPLAY_TITLE" ] && DISPLAY_TITLE=$(read_display_title "$SESSION_ID")
set_static_tab_title "$SESSION_ID" "$CURSOR_WARP_SYMBOL_DONE" "$DISPLAY_TITLE"

if ! should_use_structured; then
    exit 0
fi

# shellcheck source=build-payload.sh
source "$SCRIPT_DIR/build-payload.sh"

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
QUERY=""
RESPONSE=""

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    sleep 0.3
    QUERY=$(jq -rs '
        [
            .[] | select(.type == "user" or .role == "user") |
            if (.message.content // .content) | type == "string" then .
            elif [((.message.content // .content) // [])[] | select(.type == "text")] | length > 0 then .
            else empty
            end
        ] | last |
        if (.message.content // .content) | type == "array"
        then [(.message.content // .content)[] | select(.type == "text") | .text] | join(" ")
        else (.message.content // .content // empty)
        end
    ' "$TRANSCRIPT_PATH" 2>/dev/null)

    RESPONSE=$(jq -rs '
        [.[] | select(.type == "assistant" or .role == "assistant")] | last |
        if (.message.content // .content) | type == "array"
        then [(.message.content // .content)[] | select(.type == "text") | .text] | join(" ")
        else (.message.content // .content // empty)
        end
    ' "$TRANSCRIPT_PATH" 2>/dev/null)

    if [ -n "$QUERY" ] && [ ${#QUERY} -gt 200 ]; then
        QUERY="${QUERY:0:197}..."
    fi
    if [ -n "$RESPONSE" ] && [ ${#RESPONSE} -gt 200 ]; then
        RESPONSE="${RESPONSE:0:197}..."
    fi
fi

if [ -z "$QUERY" ]; then
    QUERY=$(format_tab_title "$CURSOR_WARP_SYMBOL_DONE" "$DISPLAY_TITLE")
fi

BODY=$(build_payload "$INPUT" "stop" \
    --arg query "$QUERY" \
    --arg response "$RESPONSE" \
    --arg transcript_path "$TRANSCRIPT_PATH")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
