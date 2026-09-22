#!/bin/bash
# Emits an OSC terminal escape sequence to the controlling TTY.
#
# Cursor hooks do not document a terminalSequence stdout field, so we always
# write to /dev/tty and never print the OSC on stdout (which would corrupt
# hook JSON responses).
#
# Usage:
#   source "$SCRIPT_DIR/emit-terminal-sequence.sh"
#   emit_terminal_sequence "$SEQ"

emit_terminal_sequence() {
    local seq="$1"
    [ -z "$seq" ] && return 0
    printf '%s' "$seq" > /dev/tty 2>/dev/null || true
}
