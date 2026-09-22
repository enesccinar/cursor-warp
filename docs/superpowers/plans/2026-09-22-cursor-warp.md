# cursor-warp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a public `enesccinar/cursor-warp` package that emits Warp `warp://cli-agent` OSC 777 events from Cursor hooks, with a curl|bash installer that merges into `~/.cursor/hooks.json`.

**Architecture:** Bash scripts adapted from `claude-code-warp`, Cursor hook names, `agent: "cursor"`, emit to `/dev/tty`. Installer clones to `~/.cursor/plugins/cursor-warp` and merges hook entries idempotently.

**Tech Stack:** Bash, jq, git, GitHub (`enesccinar/cursor-warp`)

## Global Constraints

- Protocol: Warp CLI-agent v1 OSC 777 title `warp://cli-agent`
- Agent slug: `"cursor"`
- Install dir: `~/.cursor/plugins/cursor-warp`
- Repo path: `/Users/tib3ria/Projects/plugins/cursor-warp`
- No idle_prompt in v1; permission via beforeShell/beforeMCP approximation
- Always emit via `/dev/tty` (Cursor has no documented terminalSequence hook output)
- Coexist with existing hooks; never wipe unrelated entries
- MIT license

## File structure

| Path | Responsibility |
| --- | --- |
| `scripts/should-use-structured.sh` | Warp capability gate |
| `scripts/build-payload.sh` | Common Warp JSON envelope (`agent: cursor`) |
| `scripts/emit-terminal-sequence.sh` | Write OSC to `/dev/tty` |
| `scripts/warp-notify.sh` | Gate + emit notify sequence |
| `scripts/on-*.sh` | Per-hook emitters |
| `hooks/hooks.fragment.json` | Cursor hook definitions (absolute-path placeholders resolved by installer) |
| `install.sh` / `uninstall.sh` | Merge/remove hooks |
| `tests/test-hooks.sh` | Fixture tests |
| `README.md` `LICENSE` `VERSION` | Docs / version |

---

### Task 1: Core emit library + tests

**Files:**
- Create: `scripts/should-use-structured.sh`
- Create: `scripts/build-payload.sh`
- Create: `scripts/emit-terminal-sequence.sh`
- Create: `scripts/warp-notify.sh`
- Create: `VERSION`
- Create: `tests/test-hooks.sh`
- Create: `tests/fixtures/prompt-submit.json`

**Interfaces:**
- Produces: `should_use_structured`, `build_payload`, `emit_terminal_sequence`, `warp-notify.sh`
- `build_payload "$INPUT" "$EVENT" [jq --arg...]: maps `session_id` from `.session_id // .conversation_id`, `cwd` from `.cwd // (.workspace_roots[0] // "")`

- [ ] **Step 1:** Add failing test that sources `build-payload.sh` with fixture and asserts `agent=cursor` and `event=prompt_submit`
- [ ] **Step 2:** Implement the four scripts + VERSION `0.1.0`
- [ ] **Step 3:** Run `tests/test-hooks.sh` — expect PASS
- [ ] **Step 4:** Commit `feat: add Warp emit core for cursor-warp`

### Task 2: Hook scripts

**Files:**
- Create: `scripts/on-session-start.sh`
- Create: `scripts/on-prompt-submit.sh`
- Create: `scripts/on-post-tool-use.sh`
- Create: `scripts/on-before-shell.sh`
- Create: `scripts/on-before-mcp.sh`
- Create: `scripts/on-stop.sh`
- Create: `hooks/hooks.fragment.json`

**Interfaces:**
- Consumes: Task 1 helpers
- Events: `session_start`, `prompt_submit`, `tool_complete`, `permission_request`, `stop`
- beforeShell: `tool_name=Shell`, summary from `.command`
- beforeMCP: `tool_name` from payload, summary `Wants to run $tool`
- stop: best-effort query/response from transcript if `.transcript_path` present; skip if `.stop_hook_active == true`

- [ ] **Step 1:** Extend tests for each event fixture
- [ ] **Step 2:** Implement hook scripts + fragment JSON using `__CURSOR_WARP_ROOT__` placeholder
- [ ] **Step 3:** Run tests — PASS
- [ ] **Step 4:** Commit `feat: add Cursor hook scripts for Warp status`

### Task 3: Installer + uninstall

**Files:**
- Create: `install.sh`
- Create: `uninstall.sh`

**Interfaces:**
- Install clones/updates `https://github.com/enesccinar/cursor-warp.git` → `~/.cursor/plugins/cursor-warp` (or copy from local `CURSOR_WARP_SRC` for testing)
- Backup `~/.cursor/hooks.json`
- Merge fragment: replace entries whose command contains `cursor-warp/scripts/`
- Uninstall removes those entries; `--purge` deletes install dir

- [ ] **Step 1:** Test merge against a temp hooks.json with an unrelated command
- [ ] **Step 2:** Implement install.sh / uninstall.sh
- [ ] **Step 3:** Commit `feat: add install and uninstall scripts`

### Task 4: README, LICENSE, GitHub publish

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `.gitignore`

- [ ] **Step 1:** Write README (features, gaps, install curl, uninstall, requirements)
- [ ] **Step 2:** MIT LICENSE, gitignore
- [ ] **Step 3:** Commit `docs: add README and license`
- [ ] **Step 4:** `gh repo create enesccinar/cursor-warp --public --source=. --remote=origin --push`

### Task 5: Local install verification

- [ ] **Step 1:** Run `./install.sh` (or `CURSOR_WARP_SRC=. ./install.sh`)
- [ ] **Step 2:** Confirm `~/.cursor/hooks.json` contains cursor-warp entries and still contains prior Orca hooks
- [ ] **Step 3:** Manual note in README: restart agent / verify in Warp

---

## Spec coverage check

- Architecture / scripts / installer / events / gaps / tests / success criteria → Tasks 1–5
- idle_prompt skipped → documented in README
- Permission approximation → on-before-shell/mcp
