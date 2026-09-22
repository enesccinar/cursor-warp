#!/usr/bin/env bash
# Fixture tests for cursor-warp payload builders and installer merge.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT/scripts"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

pass=0
fail=0

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "PASS: $name"
        pass=$((pass + 1))
    else
        echo "FAIL: $name"
        echo "  expected: $expected"
        echo "  actual:   $actual"
        fail=$((fail + 1))
    fi
}

assert_contains() {
    local name="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "PASS: $name"
        pass=$((pass + 1))
    else
        echo "FAIL: $name (missing '$needle')"
        echo "  in: $haystack"
        fail=$((fail + 1))
    fi
}

# shellcheck source=../scripts/build-payload.sh
source "$SCRIPT_DIR/build-payload.sh"
# shellcheck source=../scripts/should-use-structured.sh
source "$SCRIPT_DIR/should-use-structured.sh"

# --- build_payload ---
INPUT='{"conversation_id":"conv-1","cwd":"/Users/me/Projects/demo","prompt":"hello world"}'
BODY=$(build_payload "$INPUT" "prompt_submit" --arg query "hello world")
# Warp resolves the OSC "agent" field via CLIAgent::command_prefixes().
# CursorCli's prefix is "agent" (the cursor-agent binary), not "cursor".
assert_eq "agent slug matches Warp CursorCli prefix" "agent" "$(echo "$BODY" | jq -r .agent)"
assert_eq "event is prompt_submit" "prompt_submit" "$(echo "$BODY" | jq -r .event)"
assert_eq "session_id from conversation_id" "conv-1" "$(echo "$BODY" | jq -r .session_id)"
assert_eq "project basename" "demo" "$(echo "$BODY" | jq -r .project)"
assert_eq "query field" "hello world" "$(echo "$BODY" | jq -r .query)"

INPUT2='{"session_id":"sess-9","workspace_roots":["/tmp/ws"]}'
BODY2=$(build_payload "$INPUT2" "session_start" --arg plugin_version "0.1.0")
assert_eq "session_id preferred" "sess-9" "$(echo "$BODY2" | jq -r .session_id)"
assert_eq "cwd from workspace_roots" "/tmp/ws" "$(echo "$BODY2" | jq -r .cwd)"

# --- should_use_structured ---
unset WARP_CLI_AGENT_PROTOCOL_VERSION WARP_CLIENT_VERSION || true
if should_use_structured; then
    echo "FAIL: should_use_structured without env"
    fail=$((fail + 1))
else
    echo "PASS: should_use_structured rejects missing env"
    pass=$((pass + 1))
fi

export WARP_CLI_AGENT_PROTOCOL_VERSION=1
export WARP_CLIENT_VERSION="v0.2026.08.19.08.15.stable_01"
if should_use_structured; then
    echo "PASS: should_use_structured accepts modern Warp"
    pass=$((pass + 1))
else
    echo "FAIL: should_use_structured rejected modern Warp"
    fail=$((fail + 1))
fi

# --- installer merge ---
EXISTING="$TMPDIR_TEST/hooks.json"
FRAGMENT_RESOLVED="$TMPDIR_TEST/fragment.json"
cat > "$EXISTING" <<'EOF'
{
  "version": 1,
  "hooks": {
    "stop": [
      {"command": "/other/orca.sh", "timeout": 10}
    ],
    "beforeSubmitPrompt": [
      {"command": "/old/cursor-warp/scripts/on-prompt-submit.sh", "timeout": 5}
    ]
  }
}
EOF

sed "s|__CURSOR_WARP_ROOT__|/tmp/fake-cursor-warp|g" \
    "$ROOT/hooks/hooks.fragment.json" > "$FRAGMENT_RESOLVED"

HOOKS_EXISTING=$(cat "$EXISTING")
HOOKS_FRAGMENT=$(cat "$FRAGMENT_RESOLVED")
export HOOKS_EXISTING HOOKS_FRAGMENT
MERGED=$(jq -n '
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
')

ORCA_COUNT=$(echo "$MERGED" | jq '[.hooks.stop[] | select(.command|test("orca"))] | length')
WARP_STOP=$(echo "$MERGED" | jq '[.hooks.stop[] | select(.command|contains("cursor-warp/scripts/on-stop"))] | length')
OLD_GONE=$(echo "$MERGED" | jq '[.hooks.beforeSubmitPrompt[] | select(.command|test("/old/cursor-warp"))] | length')
NEW_PROMPT=$(echo "$MERGED" | jq '[.hooks.beforeSubmitPrompt[] | select(.command|contains("/tmp/fake-cursor-warp"))] | length')

assert_eq "keeps orca stop hook" "1" "$ORCA_COUNT"
assert_eq "adds warp stop hook" "1" "$WARP_STOP"
assert_eq "replaces old warp prompt hook" "0" "$OLD_GONE"
assert_eq "adds new warp prompt hook" "1" "$NEW_PROMPT"

echo
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
