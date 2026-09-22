# cursor-warp

Warp terminal notifications and session status for [Cursor CLI](https://cursor.com/docs/cli) — the Cursor counterpart to [`claude-code-warp`](https://github.com/warpdotdev/claude-code-warp).

## Features

Emits Warp’s structured `warp://cli-agent` OSC 777 events so Warp can show:

- **Working** when you submit a prompt
- **Needs attention** (best-effort) when a shell or MCP tool is about to run under approval
- **Complete** when the agent turn stops
- **Tool complete** after tools finish (unblocks “waiting” state in Warp)

## Install

Requires [Warp](https://warp.dev), [Cursor CLI](https://cursor.com/docs/cli) (`agent`), and `jq`.

```bash
curl -fsSL https://raw.githubusercontent.com/enesccinar/cursor-warp/main/install.sh | bash
```

Or from a clone:

```bash
git clone https://github.com/enesccinar/cursor-warp.git
cd cursor-warp
CURSOR_WARP_SRC=. ./install.sh
```

Then **restart** Cursor Agent / `agent` inside Warp.

### What the installer does

1. Installs the package under `~/.cursor/plugins/cursor-warp`
2. Backs up `~/.cursor/hooks.json`
3. Merges cursor-warp hook entries **without removing** your other hooks

## Uninstall

```bash
~/.cursor/plugins/cursor-warp/uninstall.sh
# or purge install dir too:
~/.cursor/plugins/cursor-warp/uninstall.sh --purge
```

## How it works

Cursor hooks run small bash scripts that write:

```text
ESC ] 777 ; notify ; warp://cli-agent ; <JSON> BEL
```

to `/dev/tty` when Warp advertises `WARP_CLI_AGENT_PROTOCOL_VERSION`. Outside Warp the scripts no-op.

| Cursor hook | Warp event |
| --- | --- |
| `sessionStart` | `session_start` |
| `beforeSubmitPrompt` | `prompt_submit` |
| `postToolUse` | `tool_complete` |
| `beforeShellExecution` | `permission_request` (approximation) |
| `beforeMCPExecution` | `permission_request` (approximation) |
| `stop` | `stop` |

## Gaps vs Claude’s Warp plugin

Cursor does not expose Claude’s `Notification` (idle) or `PermissionRequest` hooks. This package:

- **Skips** idle-prompt notifications in v1
- **Approximates** permission requests via `beforeShellExecution` / `beforeMCPExecution`

Cursor’s built-in `/status-indicators` (OSC 0 titles) is separate and often ignored by Warp’s CLI-agent chrome — this package is the Warp-native path.

## Development

```bash
./tests/test-hooks.sh
```

## License

MIT
