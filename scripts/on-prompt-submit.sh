#!/bin/bash
# beforeSubmitPrompt → prompt_submit + spinning tab title

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=should-use-structured.sh
source "$SCRIPT_DIR/should-use-structured.sh"
# shellcheck source=tab-title.sh
source "$SCRIPT_DIR/tab-title.sh"

INPUT=$(cat)
SESSION_ID=$(extract_session_id_from_input "$INPUT")
DISPLAY_TITLE=$(extract_display_title "$INPUT")
start_title_spinner "$SESSION_ID" "$DISPLAY_TITLE"

if ! should_use_structured; then
    exit 0
fi

# shellcheck source=build-payload.sh
source "$SCRIPT_DIR/build-payload.sh"

QUERY=$(format_tab_title "⠋" "$DISPLAY_TITLE")

BODY=$(build_payload "$INPUT" "prompt_submit" \
    --arg query "$QUERY")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
