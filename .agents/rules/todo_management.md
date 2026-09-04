---
trigger: always_on
---

# TODO & Kanban Workflow Rule

- **When starting a task from `TODO.md`:** Move the task item from `## Backlog` to `## Work in Progress` as `- [ ] <task>`.
- **When given a task not yet present in `TODO.md`:** Automatically add it under `## Work in Progress` as `- [ ] <task>`.
- **When a task is finished and confirmed by the user as working:** Move the task item from `## Work in Progress` to `## Done` as `- [x] <task>`.
- **Do not mark tasks as Done prematurely:** Keep tasks in `## Work in Progress` until the user confirms that the feature or fix works as expected.
