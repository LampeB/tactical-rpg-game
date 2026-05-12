# Quality Rules — Tactics-Hub RPG

> Read by Quality Gate and Quality Scanner agents.
> Edit this file to tune rules. Rules marked [FAIL] block merging.
> Rules marked [WARN] log but allow merging. [INFO] is logged only.

---

## Severity Levels
- FAIL — must be fixed before the task branch can merge
- WARN — logged in the Notion resolution, flagged to human, does not block merge
- INFO — logged only, no human notification

---

## Base Rules

### Clean Code
- [FAIL] Functions must do one thing. A function longer than 40 lines is a signal to review.
- [FAIL] Function names must describe what they do, not how.
- [FAIL] No magic numbers. Named constants only. (Bad: `if speed > 450` — Good: `if speed > MAX_SPEED`)
- [FAIL] No commented-out code in committed files. Delete it or create a Notion task for it.
- [WARN] No deeply nested logic (more than 3 levels of indentation inside a function)
- [WARN] Functions with more than 5 parameters should use a Dictionary or data class

### Dead Code
- [FAIL] No unreachable code (code after a return statement)
- [WARN] No functions that are defined but never called anywhere in the project
- [WARN] No variables that are assigned but never read
- [WARN] No preloads that are never used

### Error Handling
- [FAIL] No silent failures — if an operation can fail, the failure must be logged via DebugLogger
- [WARN] Functions that return null on failure must note it in a comment

### Performance
- [WARN] No expensive operations (file I/O, heavy computation) inside `_process()` or `_physics_process()`
- [WARN] No instantiation of new objects inside tight loops

### Security / Safety
- [FAIL] No hardcoded credentials, API keys, or absolute user-specific paths

---

## Project-Specific Rules

### GDScript
- [FAIL] All variables must use static typing (`var x: int`, not `var x`)
- [FAIL] No typed for-in loops over untyped collections — `for item: Type in untyped_array` causes silent parse failures in Godot 4.6. Use index loops instead.
- [FAIL] No chained assignment (`a = b = value`)
- [FAIL] No `:=` when right-hand side returns Variant — use explicit type annotation
- [FAIL] `class_name` scripts must not reference autoloads directly
- [WARN] Unused parameters must be prefixed with `_`
- [WARN] Do not shadow global GDScript identifiers (`sign`, `clamp`, `lerp`, `min`, `max`, `abs`, `floor`, `ceil`, `round`)
- [WARN] Enum casting must be explicit: `item.rarity = idx as Enums.Rarity`

### Architecture
- [FAIL] All signals must be defined in EventBus — never define signals directly on scene nodes for cross-system communication
- [FAIL] Scene files must not contain business logic — only UI wiring and signal connections
- [FAIL] Autoloads must not directly reference scene nodes — communicate via EventBus signals only
- [WARN] All UI scene backgrounds must use `UIColors.BG_*` constants — no hardcoded `Color(...)` values
- [WARN] Database resources must be accessed via database autoloads, never via `load()` directly in game code

---

## Excluded Paths
excluded:
  - addons/
  - .agent/
  - tools/
  - tests/
