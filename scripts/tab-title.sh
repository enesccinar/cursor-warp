#!/bin/bash
# Tab title format: "<symbol> <title>"
# Writes OSC 0 window titles. A background braille spinner animates while working.
#
# Terminals cannot show a GIF in the tab label — only characters/emoji.

CURSOR_WARP_STATE_DIR="${CURSOR_WARP_STATE_DIR:-${TMPDIR:-/tmp}/cursor-warp-titles}"
CURSOR_WARP_SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
CURSOR_WARP_SYMBOL_IDLE="·"
CURSOR_WARP_SYMBOL_DONE="✓"
CURSOR_WARP_SYMBOL_BLOCKED="⏸"

_tab_title_key() {
    local session_id="$1"
    if [ -n "$session_id" ]; then
        printf '%s' "$session_id" | tr -c 'A-Za-z0-9._-' '_'
        return
    fi
    if [ -n "${WARP_TERMINAL_SESSION_UUID:-}" ]; then
        printf '%s' "$WARP_TERMINAL_SESSION_UUID"
        return
    fi
    printf 'tty-%s' "$(basename "$(tty 2>/dev/null || echo unknown)")"
}

format_tab_title() {
    local symbol="$1"
    local title="$2"
    title=$(printf '%s' "$title" | tr '\n\r' '  ')
    title=$(printf '%s' "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$title" ] && title="Cursor"
    if [ ${#title} -gt 48 ]; then
        title="${title:0:45}..."
    fi
    printf '%s %s' "$symbol" "$title"
}

extract_display_title() {
    local input="$1"
    local name
    name=$(echo "$input" | jq -r '
        .session_name
        // .chat_name
        // .conversation_name
        // empty
    ' 2>/dev/null)
    if [ -z "$name" ]; then
        name=$(echo "$input" | jq -r '(.cwd // (.workspace_roots[0] // empty))' 2>/dev/null)
        if [ -n "$name" ]; then
            name=$(basename "$name")
        fi
    fi
    if [ -z "$name" ]; then
        name=$(echo "$input" | jq -r '.prompt // .text // empty' 2>/dev/null)
        name=$(printf '%s' "$name" | tr '\n\r' '  ')
    fi
    printf '%s' "$name"
}

set_osc_title() {
    local text="$1"
    printf '\033]0;%s\007' "$text" > /dev/tty 2>/dev/null || true
}

_title_paths() {
    local key
    key=$(_tab_title_key "$1")
    mkdir -p "$CURSOR_WARP_STATE_DIR"
    TITLE_FILE="$CURSOR_WARP_STATE_DIR/${key}.title"
    PID_FILE="$CURSOR_WARP_STATE_DIR/${key}.spinner.pid"
    LOCK_FILE="$CURSOR_WARP_STATE_DIR/${key}.spinning"
}

extract_session_id_from_input() {
    echo "$1" | jq -r '.session_id // .conversation_id // empty' 2>/dev/null
}

stop_title_spinner() {
    _title_paths "$1"
    rm -f "$LOCK_FILE"
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
}

remember_display_title() {
    _title_paths "$1"
    printf '%s' "$2" > "$TITLE_FILE"
}

read_display_title() {
    _title_paths "$1"
    if [ -f "$TITLE_FILE" ]; then
        cat "$TITLE_FILE"
        return
    fi
    printf '%s' "Cursor"
}

set_static_tab_title() {
    local session_id="$1"
    local symbol="$2"
    local title="$3"
    stop_title_spinner "$session_id"
    remember_display_title "$session_id" "$title"
    set_osc_title "$(format_tab_title "$symbol" "$title")"
}

start_title_spinner() {
    local session_id="$1"
    local title="$2"
    stop_title_spinner "$session_id"
    remember_display_title "$session_id" "$title"
    _title_paths "$session_id"
    touch "$LOCK_FILE"

    (
        local i=0
        while [ -f "$LOCK_FILE" ]; do
            set_osc_title "$(format_tab_title "${CURSOR_WARP_SPINNER_FRAMES[i]}" "$title")"
            i=$(( (i + 1) % ${#CURSOR_WARP_SPINNER_FRAMES[@]} ))
            sleep 0.12
        done
    ) >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
}
