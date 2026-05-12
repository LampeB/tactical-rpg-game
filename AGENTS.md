# Active Agents — Tactics-Hub RPG

> Project-specific agent configuration. Read by the Orchestrator at session start.
> Agent role definitions and prompts live in ai_dev_studio.md (the system spec).

---

## Agents Enabled

| Agent | Status | Notes |
|---|---|---|
| Orchestrator | ✓ | Pipeline conductor — spawns all others as subagents via Agent tool |
| Task Writer | ✓ | |
| Dependency Checker | ✓ | |
| Task Splitter | ✓ | |
| Scene Reader | ✓ | Auto-triggered for any task listing a .tscn file |
| Coder | ✓ | |
| Reviewer | ✓ | |
| Quality Gate | ✓ | |
| Quality Scanner | ✓ | On-demand only — never runs inside the task pipeline |
| Notion Updater | ✓ | |

---

## Notion Configuration
- Tasks database data source ID: `fe3e9c59-0d0b-4072-a5ee-96051dc534b9`
- Root page ID: `3147700f-d0fb-8147-85dc-e1bb6aba4513`
- Use `mcp__claude_ai_Notion__*` tools — NOT `mcp__notion__API-*` (local token is invalid)
- Task categories: UI, Items, Combat, World, Audio, Story, Gamepad, Localisation, QoL, Map Editor, Prerequisites, Cleanup
- Local task cache: `.claude/notion_tasks.md` — read this first for quick lookup, then fetch Notion page by ID for full details

---

## Project-Specific Agent Rules

### All agents
- Read `PROJECT_CONFIG.md` at the start of every session before touching any code.
- Read `QUALITY_RULES.md` before reviewing or quality-checking any code.
- The local Notion cache at `.claude/notion_tasks.md` must be updated in sync with every Notion status change.

### Coder
- Never touch `scenes/battle/`, `scripts/systems/combat*`, or the cinematic camera system unless those files are explicitly listed in the current subtask.
- For new UI scenes: reference the closest existing scene (e.g. shop for a new shop-style screen, crafting for a new crafting-style screen). Document which scene you referenced in the commit message.

### Reviewer
- Before approving any subtask that removes a file: confirm the file has zero references in the codebase. Run a search for the filename and for any `preload`/`load` calls referencing it.

### Notion Updater
- Always update `.claude/notion_tasks.md` in sync with Notion status changes.
- When setting a task to Done, move it to the Done section in the local cache.

---

## Phase Status
- **Phase 1 — Audit**: COMPLETE. `ARCHITECTURE.md` written 2026-05-11.
- **Phase 2 — Notion cleanup**: In progress. See below.
- **Phase 3 — Pipeline execution**: Blocked on Phase 2.

---

## Phase 1 Audit Instructions (run once, manually)

Start a new Claude Code session and use this prompt:

```
You are running a one-time Phase 1 codebase audit.
Do NOT create any Notion tasks. Do NOT make any code changes.

Read the entire codebase. Produce ARCHITECTURE.md at the repo root with:
1. Every autoload/singleton: name, file path, what it does, what it connects to
2. Every major scene: path, purpose, current status (working / in-progress / likely dead)
3. Every system: what it does, what it depends on, what depends on it
4. A list of files that appear to be dead code (not referenced anywhere)
5. A list of hardcoded or bypassed connections (POC glue from the old direction)
6. A list of all EventBus signals and which systems emit/connect to each one

Output "AUDIT COMPLETE" when ARCHITECTURE.md is written.
```

## Orchestrator Invocation (Phase 3, after audit + Notion cleanup)

Start a new Claude Code session and use this prompt:

```
You are the Orchestrator. Read PROJECT_CONFIG.md, ARCHITECTURE.md, and AGENTS.md.

Select the highest priority Todo task from the Notion task database
(data source: fe3e9c59-0d0b-4072-a5ee-96051dc534b9) and run the full pipeline
as defined in AGENTS.md — spawning each downstream agent as a subagent
using the Agent tool.

Stop and flag me only if you hit a HUMAN INPUT REQUIRED case.
```
