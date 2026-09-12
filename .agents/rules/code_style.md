---
trigger: always_on
---

# Code Style and Software Design Principles

This rule defines the core software engineering principles and code style standards for the codebase, synthesized from CodeAesthetic design philosophies. Every contributor and agent MUST adhere to these guidelines across all code changes, refactors, and architectural designs.

---

## 1. Abstraction vs. Coupling: The Hidden Trade-off

> *"Coupling is an equal and opposite reaction of abstraction. For every bit of abstraction you add, you add more coupling."*

### 1.1 The Repetition Trap
Engineers are conditioned to believe that *code repetition is inherently bad* and *abstraction is inherently good*. This instinct causes premature abstraction that creates rigid, fragile coupling.
- **A little code repetition is far less painful than the wrong abstraction.**
- Duplicated trivial code (e.g. assigning a field, invoking a single method) is cheap and isolated.
- Shared abstractions couple disparate subsystems together, forcing them to evolve at the same pace or adhere to artificial constraints.

### 1.2 The "Not Worth It" Camp
Do **NOT** introduce an abstraction, common parent struct, or interface if:
- It only saves a few lines of trivial variable assignment or straightforward logic.
- It couples classes/structs to an identical input signature (e.g., forcing all savers to take a file path when a future saver might need a database or network stream).
- It only removes a single duplicated call site behind an `if` branch.

### 1.3 When Abstraction IS Justified
Only introduce abstractions, polymorphic dispatch, or extracted interfaces when:
1. **The Rule of Three**: There are **three or more** distinct implementations sharing meaningful structural behavior.
2. **Separation of Decision from Execution**: You must decouple **which** concrete implementation is selected from **when or how** it is executed (e.g., deferred execution, interval tickers, dependency injection, room lifecycle handlers).

```zig
// AVOID: Premature coupling through artificial base wrappers
// Keeping XML and JSON savers independent allows either to be deleted or 
// refactored with zero ripple effects across unrelated code.
```

---

## 2. Naming Conventions & Domain Structure

> *"There are only two hard things in computer science: cache invalidation and naming things. We can get 80% of the way by avoiding bad patterns."*

### 2.1 Never Abbreviate Names
We spend vastly more time reading code than writing code. Abbreviations force readers to guess context, decode mental mappings, and stumble over unfamiliar terms.
- **Strictly Prohibited**: `pos`, `idx`, `cnt`, `cur`, `len` (when not native), `btn`, `calc`, `mgr`, `dir`, `dmg`, `acc`, `vel`.
- **Mandatory**: `position`, `index`, `count`, `current`, `button`, `calculate`, `manager`, `direction`, `damage`, `acceleration`, `velocity`.
- Modern IDEs provide instant auto-completion, and modern displays have ample width. Abbreviations provide zero architectural value.

### 2.2 Ban Single-Letter Variable Names
- Single-letter variables (e.g., `i`, `n`, `p`, `x`) obscure what the data actually represents.
- **Allowed Exception**: Standard mathematical coordinate axes (e.g., `vector.x`, `vector.y`) when referencing standard 2D/3D vectors.
- In loops, always provide expressive, descriptive names:
  ```zig
  // BAD
  for (enemies) |e| { ... }
  for (items, 0..) |it, i| { ... }

  // GOOD
  for (enemies) |enemy| { ... }
  for (items, 0..) |item, item_index| { ... }
  ```

### 2.3 Do Not Put Types in Variable Names (No Hungarian Notation)
In statically typed languages like Zig, the compiler and type system already declare the data type. Putting the type into the variable name is redundant and noisy.
- **Bad**: `enemy_ptr`, `health_int`, `player_object`, `bullets_array`, `name_str`.
- **Good**: `target_enemy`, `current_health`, `player`, `active_bullets`, `player_name`.

### 2.4 Quantities with Units Must Encode the Unit
When a numerical variable represents a physical dimension, temporal duration, or rate, **always include the unit in the variable name** (unless represented by a strongly typed unit type):
- **Bad**: `delay`, `timeout`, `speed`, `radius`, `reload_time`.
- **Good**: `delay_seconds`, `timeout_ms`, `speed_pixels_per_second`, `radius_pixels`, `reload_cooldown_seconds`.
- When supported, prefer strong types that completely remove ambiguity (e.g., `std.time.Duration` or typed vectors).

### 2.5 Do Not Put Types in Type Names ("No Types in Your Types")
- **No Interface Prefixes**: Do **not** prefix interfaces or behaviors with `I` (e.g., avoid `IEnemy`, `IWeapon`, `IInteractable`). Callers care about capability and API contract, not internal language category.
- **No `Base` or `Abstract` Prefixes/Suffixes**: Do **not** name parent structs `BaseEnemy`, `AbstractController`, or `BaseRoom`.
  - If struggling to name the general parent, keep the clean, canonical noun for the parent (`Enemy`, `Room`, `Truck`).
  - *Over-specify the specialized child types instead* (e.g., `MeleeEnemy`, `BossRoom`, `TrailerTruck`).

### 2.6 Eliminate `Utils` and `Helper` Junk Drawers
A file or struct named `utils.zig` or `helpers.zig` is an anti-pattern indicating structural laziness. Standard libraries do not dump functions into grab-bag utility modules.
- **Refactoring Strategy**:
  1. **Move to Target Type**: If a helper function operates on a specific type, make it a method or function on that type.
  2. **Create Domain Collections**: If functions manipulate a group of objects, wrap them in a first-class collection struct (e.g., `EnemyGroup`, `RoomGrid`).
  3. **Extract Dedicated Modules**: If functionality is truly reusable, extract it into a focused, single-responsibility module with a precise name (e.g., `Paginator.zig`, `Easing.zig`, `CollisionQueries.zig`).

---

## 3. Anti-Nesting & Control Flow (The "Never-Nester" Rule)

> *"If you need more than 3 levels of indentation, you're screwed anyway and should fix your program." — Linux Kernel Coding Style*

### 3.1 Maximum Indentation Depth
- Nesting forces the developer's brain to hold multiple active conditions and scopes simultaneously.
- **Absolute Limit**: Functions must never exceed **3 levels of indentation**. 4 levels deep is strictly forbidden.

### 3.2 Technique 1: Inversion (Guard Clauses & Early Returns)
Do not wrap the primary "happy path" of logic in deep `if` branches. Instead, invert the conditions to handle the unhappy paths and error states first:
1. Check failure/exit conditions immediately.
2. Return, continue, or break out early.
3. Flatten the subsequent code to the root indentation level.
4. Establish a "validation gatekeeping" block at the start of the function, allowing the core business logic to execute linearly down the page.

```zig
// BAD: Deeply nested happy path
pub fn process_attack(self: *Self, target: ?*Enemy) void {
    if (target) |enemy| {
        if (enemy.is_alive()) {
            if (!self.is_on_cooldown) {
                if (self.mana >= 10) {
                    self.mana -= 10;
                    enemy.apply_damage(self.attack_damage);
                }
            }
        }
    }
}

// GOOD: Inversion with early returns (Gatekeeping pattern)
pub fn process_attack(self: *Self, maybe_target: ?*Enemy) void {
    const enemy = maybe_target orelse return;
    if (!enemy.is_alive()) return;
    if (self.is_on_cooldown) return;
    if (self.mana < 10) return;

    self.mana -= 10;
    enemy.apply_damage(self.attack_damage);
}
```

### 3.3 Technique 2: Extraction
When a function contains complex inner loops or multi-branch processing:
- Extract the inner loop body into a dedicated, descriptively named helper function.
- Break large orchestrator routines into small, sequential functions that each perform one single responsibility (e.g., `parse_incoming_requests()`, `process_active_items()`, `cleanup_finished()`).
- The top-level function should read like a clear table of contents.

---

## 4. Self-Documenting Code vs. Comments & Documentation

> *"Comments can lie, but code cannot. If your code needs a comment to explain what it is doing, make the code more human instead."*

### 4.1 The Flaw of Internal Comments
- Comments are ignored by compilers, linters, and automated test suites.
- As code evolves, internal comments inevitably rot, fall out of sync, and mislead maintainers.
- Write expressive, self-explanatory code rather than relying on natural-language apologies for confusing code.

### 4.2 How to Make Code Self-Documenting
1. **Replace Magic Numbers with Constants or Enums**:
   ```zig
   // BAD
   if (status == 3) { ... } // 3 means finished

   // GOOD
   const RoomState = enum { unvisited, active, finished };
   if (status == .finished) { ... }
   ```

2. **Decompose Complex Boolean Logic into Named Variables or Predicates**:
   ```zig
   // BAD
   if (distance <= radius and entity.team != self.team and !entity.is_invulnerable and entity.health > 0) { ... }

   // GOOD
   const is_within_range = distance <= radius;
   const is_hostile = entity.team != self.team;
   const is_valid_target = !entity.is_invulnerable and entity.health > 0;

   if (is_within_range and is_hostile and is_valid_target) { ... }
   ```

3. **Leverage the Type System**:
   - Use optional types (`?T`) instead of sentinel values (e.g., returning `-1` for not found).
   - Use explicit ownership patterns (e.g., passing `allocator`, `deinit()` calls) instead of comments about memory release responsibilities.

### 4.3 Documentation vs. Internal Comments
- **Code Documentation (Allowed & Encouraged)**:
  - Uses doc comments (`///` in Zig).
  - Describes the **public API contract**, architectural purpose, preconditions, error states, and how external consumers should interact with the module.
  - Sits at public boundaries and stays in sync via documentation generators.
- **Internal Comments (Discouraged)**:
  - Narrative comments inside function bodies explaining *what* line-by-line operations are doing.
  - Strictly avoid: replace with extracted helper functions, named constants, and clean control flow.

### 4.4 The Only Permissible Exceptions for Internal Comments
Internal comments inside function bodies are permitted **only** in the following three cases:
1. **Non-Obvious Performance Optimizations**: Explaining *why* an unusual or counter-intuitive implementation was required for memory layout, cache friendliness, or tight SIMD/profiling constraints.
2. **External Algorithmic & Mathematical Sources**: Citing an external research paper, mathematical theorem, or specific reference link when implementing specialized algorithms.
3. **External Platform/Engine Bug Workarounds**: Explaining a known driver, OS, or third-party framework defect that requires an otherwise illogical code workaround.
- *Universal Rule: Comments must explain **WHY**, never **WHAT**.*

---

## 5. Quick Implementation Checklist

Before completing any task or code review, verify:
- [ ] **No Abbreviations**: Are all variable, function, and struct names written out in full?
- [ ] **No Hungarian Notation**: Are variable names free of redundant type tags (`_ptr`, `_int`, `_array`)?
- [ ] **Units Included**: Do all durations, velocities, and dimensions declare their units (`_seconds`, `_pixels`, `_ms`)?
- [ ] **No `I`, `Base`, or `Abstract` Types**: Are interfaces and structs named cleanly after their domain identity?
- [ ] **No `utils.zig` Dumping Grounds**: Have helper routines been placed on their target types or dedicated domain modules?
- [ ] **Max 3 Levels Indentation**: Have deep conditionals been flattened using inversion, guard clauses, and early returns?
- [ ] **No Magic Values or Unexplained Booleans**: Have magic constants been replaced with enums/constants, and complex conditionals decomposed into descriptive boolean variables?
- [ ] **Self-Documenting Code**: Do internal functions avoid line-by-line narrative comments, reserving comments solely for *why* (performance, citations, platform workarounds)?
- [ ] **Balanced Abstraction**: Does the code avoid premature abstraction for trivial duplication, adhering to the Rule of Three?
