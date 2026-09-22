#!/bin/bash
# Builds a structured JSON notification payload for warp://cli-agent.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/build-payload.sh"
#   BODY=$(build_payload "$INPUT" "prompt_submit" --arg query "$QUERY")

PLUGIN_CURRENT_PROTOCOL_VERSION=1

negotiate_protocol_version() {
    local warp_version="${WARP_CLI_AGENT_PROTOCOL_VERSION:-1}"
    if [ "$warp_version" -lt "$PLUGIN_CURRENT_PROTOCOL_VERSION" ] 2>/dev/null; then
        echo "$warp_version"
    else
        echo "$PLUGIN_CURRENT_PROTOCOL_VERSION"
    fi
}

# Normalize Cursor hook JSON into Warp envelope fields.
# Cursor uses conversation_id; sessionStart also exposes session_id.
_extract_session_id() {
    echo "$1" | jq -r '.session_id // .conversation_id // empty' 2>/dev/null
}

_extract_cwd() {
    echo "$1" | jq -r '.cwd // (.workspace_roots[0] // empty)' 2>/dev/null
}

build_payload() {
    local input="$1"
    local event="$2"
    shift 2

    local protocol_version
    protocol_version=$(negotiate_protocol_version)

    local session_id cwd project
    session_id=$(_extract_session_id "$input")
    cwd=$(_extract_cwd "$input")
    project=""
    if [ -n "$cwd" ]; then
        project=$(basename "$cwd")
    fi

    jq -nc \
        --argjson v "$protocol_version" \
        --arg agent "agent" \
        --arg event "$event" \
        --arg session_id "$session_id" \
        --arg cwd "$cwd" \
        --arg project "$project" \
        "$@" \
        '{v:$v, agent:$agent, event:$event, session_id:$session_id, cwd:$cwd, project:$project} + $ARGS.named'
}
