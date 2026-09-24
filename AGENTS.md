# Agent Guidelines

## Build Verification Rule
- **Always run `zig build` when a task or code modification is finished.**
- Verify that compilation succeeds with exit code 0 before concluding your response or reporting back to the user.
- If `zig build` produces any compile errors, fix them immediately.

## Code Style & Software Design Rule
- Adhere strictly to the design and code style principles outlined in [.agents/rules/code_style.md](.agents/rules/code_style.md).
- **Key Tenets**:
  - **Abstraction vs. Coupling**: Resist the repetition trap; prefer slight duplication over premature or wrong abstractions. Abstraction is justified only by the Rule of Three or when separating decision from execution.
  - **Naming Conventions**: Never abbreviate names (e.g., use `position`, `index`, `count`, not `pos`, `idx`, `cnt`). Ban single-letter variables except standard 2D/3D coordinate axes. Do not put types in variable or type names. Always suffix quantities with their units (e.g., `delay_seconds`, `speed_pixels_per_second`). Eliminate utility/helper grab bags.
  - **Anti-Nesting ("Never-Nester")**: Functions must never exceed 3 levels of indentation (4 levels is strictly prohibited). Use early returns, guard clauses (validation gatekeeping), and function extraction.
  - **Self-Documenting Code**: Code must be clear and expressive without narrative inline comments. Use doc comments (`///`) for public contracts. Internal comments are restricted to non-obvious optimizations, external algorithm citations, or engine/platform bug workarounds.

## TODO & Kanban Workflow Rule
- [TODO.md](TODO.md) uses the structured Markdown Kanban format (`### [<id>#<MODULE>] <Title>` with `tags`, `priority`, `workload`, and `steps`).
- **When starting a task from [TODO.md](TODO.md):** Move the entire atomic task block (heading, properties, steps, description) from `## Backlog` to `## Work in Progress`.
- **When given a task not yet present in [TODO.md](TODO.md):** Add it as a fully structured task block under `## Work in Progress` using the next sequential ID (`max_id + 1`) and appropriate 3-letter module code. Only create a ticket for complex tasks; do not create new tickets for trivial changes, or simple user queries.
- **Track progress in steps:** Check off checklist steps (`- [x] <step>`) as they are completed during implementation.
- **Do not mark tasks as Done prematurely:** Keep tasks in `## Work in Progress` until the user confirms that the feature or fix works as expected.
- **When a task is finished and confirmed by the user:** Check off the user confirmation step and move the entire task block from `## Work in Progress` to the top of `## Done`.


