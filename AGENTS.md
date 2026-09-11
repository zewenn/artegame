# Agent Guidelines

## Build Verification Rule
- **Always run `zig build` when a task or code modification is finished.**
- Verify that compilation succeeds with exit code 0 before concluding your response or reporting back to the user.
- If `zig build` produces any compile errors, fix them immediately.

## TODO & Kanban Workflow Rule
- [TODO.md](TODO.md) uses the structured Markdown Kanban format (`### [<id>#<MODULE>] <Title>` with `tags`, `priority`, `workload`, and `steps`).
- **When starting a task from [TODO.md](TODO.md):** Move the entire atomic task block (heading, properties, steps, description) from `## Backlog` to `## Work in Progress`.
- **When given a task not yet present in [TODO.md](TODO.md):** Add it as a fully structured task block under `## Work in Progress` using the next sequential ID (`max_id + 1`) and appropriate 3-letter module code.
- **Track progress in steps:** Check off checklist steps (`- [x] <step>`) as they are completed during implementation.
- **Do not mark tasks as Done prematurely:** Keep tasks in `## Work in Progress` until the user confirms that the feature or fix works as expected.
- **When a task is finished and confirmed by the user:** Check off the user confirmation step and move the entire task block from `## Work in Progress` to the top of `## Done`.

