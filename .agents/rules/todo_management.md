---
trigger: always_on
---

# TODO & Kanban Workflow Rule

Artegame manages project tasks using a Markdown Kanban board in [TODO.md](TODO.md) based on the `markdown-kanban` format.

## Board Structure

- **Board Heading:** Level 1 `# Artegame Tasks`
- **Status Columns:** Level 2 headings:
  - `## Backlog`: Tasks planned for future work.
  - `## Work in Progress`: Tasks currently being designed, implemented, or awaiting user verification.
  - `## Done`: Finished tasks confirmed by the user.

## Task Format

Each task is represented as an atomic level-3 heading block with metadata and checklist steps:

```markdown
### [<id>#<MODULE>] <Task Title>

  - tags: [<tag1>, <tag2>]
  - priority: low | medium | high
  - workload: Easy | Normal | Hard | Extreme
  - steps:
      - [ ] <Step 1>
      - [ ] <Step 2>
      - [ ] User confirmation that <feature/fix> works as expected
```

- **`<id>`:** Incremental integer ID across the entire board (inspect existing tasks and use `max_id + 1`).
- **`<MODULE>`:** 3-letter uppercase module/domain category:
  - `OPS`: CI/CD, release automation, packaging, scripts
  - `UIB`: UI Buttons, scaling, widgets
  - `UIM`: Menus (main menu, pause menu, options)
  - `UIS`: UI Screens (game over, HUD)
  - `SYS`: Save system, state persistence, core engine
  - `ARC`: Architecture, refactoring
  - `SPW`: Spawner, wave logic
  - `ENE`: Enemies, AI, boss mechanics
  - `AUD`: Audio, SFX, music
  - `VIS`: Visual effects, animations, particles
  - `INP`: Input handling, controller, keybindings
  - `FIX`: Bug fixes
  - `DOC`: Documentation, README, specifications
  - `AST`: Asset pipeline, textures, audio assets
  - `WFX`: Windows-specific platform fixes
- **Properties:**
  - `tags`: Bracketed, comma-separated lowercase tags.
  - `priority`: `low`, `medium`, or `high`.
  - `workload`: `Easy`, `Normal`, `Hard`, or `Extreme`.
  - `steps`: Indented checklist steps under `- steps:`. The final step must always be user confirmation: `- [ ] User confirmation that <feature/fix> works as expected`.
  - *(Optional)* Indented 4-space code block description for additional context.

## Workflow Rules

1. **Starting a Task from Backlog:**
   - Move the **entire atomic task block** (heading, metadata, steps, and description) from `## Backlog` into `## Work in Progress`.

2. **Adding a New Task:**
   - When given a task not yet present in [TODO.md](TODO.md), determine the next sequential ID (`max_id + 1`) and pick the relevant 3-letter module tag.
   - If starting immediately, add the complete task block under `## Work in Progress`.
   - If queued for later, add it under `## Backlog`.

3. **In-Progress Tracking:**
   - Check off steps (`- [x] <step>`) as they are completed during implementation.

4. **User Confirmation & Completion:**
   - **Do NOT mark tasks as Done prematurely.** Keep the task under `## Work in Progress` until the user has tested and explicitly confirmed that the feature or fix works as expected.
   - Once confirmed by the user, check off the final user confirmation step (`- [x] User confirmation that ...`) and move the entire atomic task block from `## Work in Progress` to the top of `## Done`.
