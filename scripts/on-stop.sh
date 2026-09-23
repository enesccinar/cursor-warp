#!/bin/bash
# stop → stop (task complete)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=should-use-structured.sh
source "$SCRIPT_DIR/should-use-structured.sh"

if ! should_use_structured; then
    exit 0
fi

# shellcheck source=build-payload.sh
source "$SCRIPT_DIR/build-payload.sh"

INPUT=$(cat)

STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
QUERY=""
RESPONSE=""

# Small delay so the current turn can flush (same approach as claude-code-warp).
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

# Fall back to prompt fields on the stop payload when present
if [ -z "$QUERY" ]; then
    QUERY=$(echo "$INPUT" | jq -r '.prompt // .status // empty' 2>/dev/null)
fi

BODY=$(build_payload "$INPUT" "stop" \
    --arg query "$QUERY" \
    --arg response "$RESPONSE" \
    --arg transcript_path "$TRANSCRIPT_PATH")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
