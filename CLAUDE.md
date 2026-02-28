# Tactical RPG — Claude Instructions

## Notion Integration (MANDATORY — every session)

The project has a Notion workspace synced via the **Claude AI Notion connector** (not the local MCP server in `.mcp.json`).

### Notion IDs
- **Root page**: `3147700f-d0fb-8147-85dc-e1bb6aba4513` (Tactical RPG)
- **Tasks database data source**: `fe3e9c59-0d0b-4072-a5ee-96051dc534b9`
- **Tasks database columns**: Name (title), Status (Todo/In Progress/Done), Category (UI, Items, Combat, World, Audio, Story, Gamepad, Localisation, QoL, Map Editor, Prerequisites)

### Documentation Pages (under root)
- Architecture Overview
- Combat System
- Inventory & Grid System
- Items & Equipment
- Backpack Tier System
- Characters & Party
- Loot & Economy
- World & Overworld
- NPC & Dialogue System
- Shop System
- Crafting System
- Passive Skill Tree
- Save System
- Scene Management & UI
- Constants & Enums Reference

### Local Task Cache — `.claude/notion_tasks.md`

The Notion search API only returns ~10 results per semantic query — **it cannot list all database rows**. To work around this, a local task cache lives at `.claude/notion_tasks.md`.

- **Always read `.claude/notion_tasks.md` first** when looking up tasks, picking work, or checking what exists. This is the authoritative quick-reference.
- The file is organized by Category, then by Status (Todo / Done), with each task's Name and Notion ID.
- The file also contains a "3D Migration" section for tasks that are categorized under other Notion categories but grouped locally for clarity.
- **Use Notion search only when** you need task details (description, acceptance criteria, dependencies) — fetch the task page by its Notion ID from the local file.

#### Keeping the local cache in sync

- **When creating a new task in Notion**: Also add it to `.claude/notion_tasks.md` under the correct Category and Status section. Include the Name and Notion ID returned by the create call.
- **When changing a task status in Notion** (e.g. Todo → In Progress → Done): Move the row to the correct Status subsection in the local file.
- **When the user asks to commit**: After updating Notion tasks to "Done", move those rows from the "Todo" table to the "Done" table in the local file.
- **Update the `Total tasks` and `Last updated` comments** in the file header when adding or removing tasks.
- Keep the tables sorted alphabetically by Name within each section.

### Rules — Follow these EVERY session:

#### 0. Never act without being asked
- **Never commit files** (git add/commit) unless the user explicitly asks.
- **Never update Notion** (tasks, docs, changelogs) unless the user explicitly asks to commit.
- **NEVER mark tasks as "Done"** on your own — only when the user explicitly asks to commit.
- **NEVER update documentation pages or add changelog entries** on your own — only when the user explicitly asks to commit.
- The ONLY Notion write allowed without explicit commit request is setting a task to "In Progress" when starting work.
- When the user asks to commit: commit files, update Notion tasks to "Done", update affected documentation pages, and add changelog entries — all in one go.

#### 1. Tasks Tracking
- **Finding tasks**: Read `.claude/notion_tasks.md` to browse all tasks by category and status. Use the Notion ID from that file to fetch full task details from Notion when needed.
- **When user asks to work on a category**: Read the local task file, pick a Todo task from that category, set it to "In Progress" in Notion, move it in the local file, and start working.
- **Before starting work**: Check the local task file for related existing tasks. If one exists, set its status to "In Progress" in Notion and update the local file.
- **When implementing a feature or fixing a bug**: If no matching task exists in the local file, create one in the Notion Tasks DB with status "In Progress" and the appropriate Category, then add it to the local file.
- **When the user asks to commit**: Set completed task statuses to "Done" in Notion, move them to the Done section in the local file.
- **If new TODOs are discovered** during work (e.g. a bug found, a follow-up needed): Create new tasks in Notion with status "Todo" and add them to the local file.

#### 2. Documentation Updates
- **When the user asks to commit**: Update the corresponding Notion documentation pages to reflect the changes. Only update pages whose content is actually affected.
- **What to update**: Code structure changes, new properties/methods, changed formulas or constants, new resources or scenes, removed features.
- **What NOT to update**: Minor refactors that don't change behavior, variable renames, formatting changes.

#### 3. Change Log
- When updating a documentation page, **append a changelog entry** at the bottom of the page under a "Changelog" heading:
  ```
  ### Changelog
  - **2026-02-28** — Added quest system section (QuestData, QuestObjective, QuestManager)
  - **2026-02-27** — Initial page creation
  ```

#### 4. Notion Tools
- Use `mcp__claude_ai_Notion__*` tools (the Claude connector), NOT `mcp__notion__API-*` (the local MCP server token is invalid).
- To search: `mcp__claude_ai_Notion__notion-search`
- To create pages: `mcp__claude_ai_Notion__notion-create-pages`
- To create DB rows (tasks): `mcp__claude_ai_Notion__notion-create-pages` with `parent.data_source_id`
- To update pages: `mcp__claude_ai_Notion__notion-update-page`
- To read pages: `mcp__claude_ai_Notion__notion-fetch`

## GDScript Rules

See memory file for detailed GDScript error/warning patterns to avoid. Key rules:
- Never use `:=` when RHS returns Variant — use explicit type annotation
- No chained assignment (`a = b = value`)
- Use `.assign()` for typed arrays from `Dictionary.get()`
- Always cast int to enum: `item.rarity = idx as Enums.Rarity`
- Never shadow global identifiers (`sign`, `clamp`, `lerp`, etc.)
- Prefix unused params with `_`
