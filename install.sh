#!/usr/bin/env bash
# Install cursor-warp: clone/update into ~/.cursor/plugins/cursor-warp and
# merge hook entries into ~/.cursor/hooks.json.
set -euo pipefail

REPO_URL="${CURSOR_WARP_REPO_URL:-https://github.com/enesccinar/cursor-warp.git}"
INSTALL_DIR="${CURSOR_WARP_INSTALL_DIR:-$HOME/.cursor/plugins/cursor-warp}"
HOOKS_FILE="${CURSOR_WARP_HOOKS_FILE:-$HOME/.cursor/hooks.json}"
SRC_OVERRIDE="${CURSOR_WARP_SRC:-}"

die() { echo "cursor-warp: $*" >&2; exit 1; }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need_cmd jq
need_cmd bash

install_tree() {
    mkdir -p "$(dirname "$INSTALL_DIR")"
    if [ -n "$SRC_OVERRIDE" ]; then
        local src
        src=$(cd "$SRC_OVERRIDE" && pwd)
        echo "cursor-warp: copying from $src → $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
        # Prefer rsync if available; fall back to tar
        if command -v rsync >/dev/null 2>&1; then
            rsync -a --delete --exclude '.git' "$src"/ "$INSTALL_DIR"/
        else
            rm -rf "$INSTALL_DIR"
            mkdir -p "$INSTALL_DIR"
            tar -C "$src" --exclude '.git' -cf - . | tar -C "$INSTALL_DIR" -xf -
        fi
        return
    fi

    need_cmd git
    if [ -d "$INSTALL_DIR/.git" ]; then
        echo "cursor-warp: updating $INSTALL_DIR"
        git -C "$INSTALL_DIR" fetch --quiet origin
        git -C "$INSTALL_DIR" reset --hard origin/main 2>/dev/null \
            || git -C "$INSTALL_DIR" reset --hard origin/master
    else
        echo "cursor-warp: cloning $REPO_URL → $INSTALL_DIR"
        rm -rf "$INSTALL_DIR"
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
    fi
}

backup_hooks() {
    if [ -f "$HOOKS_FILE" ]; then
        local backup
        backup="${HOOKS_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$HOOKS_FILE" "$backup"
        echo "cursor-warp: backed up hooks → $backup"
    else
        mkdir -p "$(dirname "$HOOKS_FILE")"
        printf '%s\n' '{"version":1,"hooks":{}}' > "$HOOKS_FILE"
        echo "cursor-warp: created $HOOKS_FILE"
    fi
}

merge_hooks() {
    local fragment="$INSTALL_DIR/hooks/hooks.fragment.json"
    [ -f "$fragment" ] || die "missing fragment: $fragment"

    local resolved
    resolved=$(sed "s|__CURSOR_WARP_ROOT__|$INSTALL_DIR|g" "$fragment")

    local tmp
    tmp=$(mktemp)
    HOOKS_EXISTING=$(cat "$HOOKS_FILE")
    HOOKS_FRAGMENT="$resolved"
    export HOOKS_EXISTING HOOKS_FRAGMENT

    jq -n '
      (env.HOOKS_EXISTING | fromjson) as $existing |
      (env.HOOKS_FRAGMENT | fromjson) as $frag |
      ($existing.hooks // {}) as $eh |
      ($frag.hooks // {}) as $fh |
      reduce ($fh | keys[]) as $event (
        $existing;
        .hooks[$event] = (
          ((($eh[$event] // []) | map(select((.command // "") | tostring | contains("cursor-warp/scripts/") | not))))
          + $fh[$event]
        )
      )
      | .version = ($existing.version // 1)
    ' > "$tmp"

    mv "$tmp" "$HOOKS_FILE"
    echo "cursor-warp: merged hooks into $HOOKS_FILE"
}

chmod_scripts() {
    chmod +x "$INSTALL_DIR"/scripts/*.sh "$INSTALL_DIR"/install.sh "$INSTALL_DIR"/uninstall.sh 2>/dev/null || true
}

main() {
    install_tree
    chmod_scripts
    backup_hooks
    merge_hooks
    cat <<EOF

cursor-warp installed.

  Install dir: $INSTALL_DIR
  Hooks file:  $HOOKS_FILE

Next steps:
  1. Restart Cursor Agent / \`agent\` in Warp
  2. Submit a prompt — Warp tab status should show working, then complete on stop

Uninstall:
  $INSTALL_DIR/uninstall.sh
EOF
}

main "$@"
