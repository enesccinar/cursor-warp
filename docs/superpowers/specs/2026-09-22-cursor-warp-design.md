# cursor-warp design

**Date:** 2026-09-22  
**Repo:** `enesccinar/cursor-warp`  
**Local path:** `/Users/tib3ria/Projects/plugins/cursor-warp`  
**Status:** Approved for implementation planning

## Goal

Give Cursor CLI the same Warp terminal integration Claude Code gets via `claude-code-warp`: structured OSC 777 `warp://cli-agent` events that drive Warp tab/session status badges, toasts, and desktop notifications.

## Non-goals (v1)

- Official Warp marketplace / first-party Warp maintenance
- Full idle-prompt parity (Cursor has no `Notification` / idle hook)
- True tool-permission UI parity (Cursor has no `PermissionRequest` hook)
- Changing Cursor CLI or Warp client code
- Replacing Cursor’s OSC 0 `/status-indicators` feature (orthogonal; Warp often ignores OSC 0 for detected CLI agents)

## Context

- Claude’s plugin emits OSC 777 with title `warp://cli-agent` and a JSON body (`agent: "claude"`, event name, session metadata).
- Warp advertises support via `WARP_CLI_AGENT_PROTOCOL_VERSION` and `WARP_CLIENT_VERSION`.
- Warp docs list Cursor as supported for toolbelt/vertical tabs but **not** for agent notifications — because Cursor does not emit this protocol today.
- Cursor integrates via `~/.cursor/hooks.json` (command hooks), not Claude’s plugin marketplace.

## Architecture

Public MIT repo mirroring the Claude adapter shape, adapted for Cursor hooks.

```text
cursor-warp/
  README.md
  LICENSE
  install.sh
  uninstall.sh
  hooks/hooks.fragment.json
  scripts/
    should-use-structured.sh
    build-payload.sh
    emit-terminal-sequence.sh
    warp-notify.sh
    on-session-start.sh
    on-prompt-submit.sh
    on-post-tool-use.sh
    on-before-shell.sh
    on-before-mcp.sh
    on-stop.sh
  tests/test-hooks.sh
  docs/superpowers/specs/...
```

**Runtime flow**

1. Cursor fires a hook and runs the matching script with JSON on stdin.
2. Script exits 0 immediately if `should_use_structured` fails (not Warp / broken Warp build).
3. Otherwise build Warp v1 payload with `agent: "cursor"` and emit via `warp-notify.sh` to `/dev/tty` (never corrupt hook stdout).
4. Warp parses the sequence and updates session UI / notifications.

**Install path**

- Installer clones/updates into `~/.cursor/plugins/cursor-warp` so hook commands use stable absolute paths.
- Development checkout may live at `~/Projects/plugins/cursor-warp`; installer still materializes the stable install dir (copy or symlink — implementation plan chooses one; prefer clone/update into `~/.cursor/plugins/cursor-warp`).

## Event mapping

| Claude / Warp concept | Cursor hook | Warp `event` | v1 behavior |
| --- | --- | --- | --- |
| SessionStart | `sessionStart` | `session_start` | Emit session announce / version |
| UserPromptSubmit | `beforeSubmitPrompt` | `prompt_submit` | Mark session working; include truncated prompt as `query` when present |
| PostToolUse | `postToolUse` | `tool_complete` | Signal tool finished (unblocked / still running) |
| Stop | `stop` | `stop` | Task complete; include summary fields when available from hook/transcript payload |
| PermissionRequest | `beforeShellExecution`, `beforeMCPExecution` | `permission_request` | Best-effort approximation when a gated shell/MCP call is about to run |
| Notification `idle_prompt` | — | `idle_prompt` | **Skipped in v1** (no Cursor hook) |
| StopFailure | — / best-effort `postToolUseFailure` if useful | optional later | Not required for v1 MVP |

Payload envelope (Warp protocol v1):

```json
{
  "v": 1,
  "agent": "cursor",
  "event": "<event>",
  "session_id": "<string>",
  "cwd": "<string>",
  "project": "<basename(cwd)>"
}
```

Event-specific fields follow Claude’s patterns (`query`, `summary`, `tool_name`, `tool_input`, `response`, etc.) when Cursor’s hook JSON provides equivalents. Field names from Cursor stdin may differ (`conversation_id` vs `session_id`, etc.); scripts normalize into the Warp schema.

## Installer

**`install.sh` (primary distribution: `curl | bash`)**

1. Require `bash`, `git` or tarball fetch, and `jq` (print install hint if missing).
2. Install/update repo under `~/.cursor/plugins/cursor-warp`.
3. Backup `~/.cursor/hooks.json` to `hooks.json.bak.<timestamp>` (create empty hooks file if missing).
4. Merge hook entries from `hooks/hooks.fragment.json` into `hooks.hooks.<event>` arrays.
5. Idempotent: remove/replace any existing entries whose command path contains `cursor-warp/scripts/` before inserting current ones.
6. Do not remove unrelated hooks (e.g. existing Orca hook commands).
7. Print restart + verification instructions.

**`uninstall.sh`**

- Remove only cursor-warp hook entries.
- Leave install directory unless `--purge`.

## Compatibility gates

Reuse Claude’s `should_use_structured` logic:

- Require `WARP_CLI_AGENT_PROTOCOL_VERSION`
- Require `WARP_CLIENT_VERSION`
- Skip known-broken Warp builds via the same channel thresholds as `claude-code-warp`

Outside Warp, scripts are silent no-ops.

## Testing

- Fixture-driven script tests: pipe sample Cursor hook JSON → capture emitted sequence (or dry-run mode that prints JSON body) → assert `agent`, `event`, and required fields.
- Manual checklist in README: Warp + Cursor CLI session shows working → optional permission approximation → complete on stop.
- Installer dry-run / merge test against a sample `hooks.json` that already has other commands.

## Success criteria

1. In Warp, a Cursor CLI session updates status through working and complete using Warp’s CLI-agent channel (not OSC 0 alone).
2. Installer is idempotent and coexists with pre-existing `~/.cursor/hooks.json` entries.
3. Non-Warp terminals are unaffected.
4. README clearly documents Claude parity gaps (`idle_prompt`, true `PermissionRequest`).

## Risks

| Risk | Mitigation |
| --- | --- |
| Cursor CLI does not fire some lifecycle hooks | Document CLI vs IDE; map to hooks known to fire; keep scripts cheap no-ops |
| Hook stdin schema differs from Claude | Normalize fields; tests with real Cursor payloads |
| Writing OSC to stdout breaks hooks | Always emit via `/dev/tty` (or Claude-compatible terminalSequence path only if Cursor documents it — default `/dev/tty`) |
| Installer corrupts hooks.json | Timestamped backup; JSON merge via `jq`; idempotent markers |
| Warp prefers `cli_agent_title` and still looks “wrong” | Emitting Warp protocol is the correct fix; document that `/status-indicators` alone is insufficient in Warp |

## Open implementation choices (deferred to plan)

- Symlink vs copy from `Projects/plugins/cursor-warp` into `~/.cursor/plugins/cursor-warp` for local contributors
- Whether to register `postToolUseFailure` in v1
- Exact Cursor stdin field mapping table (filled from live hook dumps during implementation)
