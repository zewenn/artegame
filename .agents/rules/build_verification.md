---
trigger: always_on
---

# Build Verification Rule

- **Always run `zig build` when a you modify the code.**
- Verify that compilation succeeds with exit code 0 before concluding your response or reporting back to the user.
- If `zig build` produces any compile errors, fix them immediately.
- If no `.zig` files have been touched, you do not need to run `zig build`.