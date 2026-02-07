# Post-Review Fixes — Plan Review 2

## Issues Addressed

### Issue 1: Planning flow says "triggered by complete-task" — but complete-task doesn't create plans

- Updated the automation boundary rule to split commands into two tiers:
  - **Always auto-trigger reviews**: `new-plan` (sets `next_phase: "plan-review"`), `create-tasks` (sets `next_phase: "tasks-review"`), `complete-task`/`complete-task-tdd` (set `next_phase: "code-review"`)
  - **Standalone (no automation)**: `next-task`, `code-review`, `post-code-review`, etc. (set `next_phase: null`)
- Updated both state transition flow diagrams to accurately reflect that the planning flow is triggered by `new-plan`, not `complete-task`
- Clarified that planning review cycle (`new-plan → plan-review → post-plan-review → ...`) runs continuously without user intervention, same as the implementation cycle

### Issue 2: `phase_iteration` starts at 0 but is documented as "1-based"

- Updated field definition to explicitly state 0-based semantics
- Documented the increment-then-compare order: hook reads current value, increments to get the next iteration number, then compares `incremented >= max_reviews` to decide whether to stop
- This means with `max_reviews: 8`, iterations run 0→1, 1→2, ..., 7→8, then 8>=8 stops — giving exactly `max_reviews` reviews

### Issue 3: How does the hook know `PLUGIN_ROOT`?

- Added `PLUGIN_ROOT` resolution at the top of the hook design section using `BASH_SOURCE`:
  ```bash
  PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ```
- This works because the hook lives at `hooks/stop-hook.sh` and needs to reference `actions/*.md` and `ground-rules.md` one directory up

### Issue 4: Edge case test #6 logic is wrong

- Fixed test expectation: auto-review and validation are mutually exclusive paths in a single hook execution
- Updated to: hook runs the review (blocking), nested file validation only triggers on the next stop attempt when `next_phase` is no longer a review phase
- New expected behavior: review block takes priority; validation catches nested files in a subsequent hook execution

### Issue 6: `all-code-review` has no clear trigger in the automation flow

- Added explicit transition in the implementation flow: after the last task's code review passes, the post-code-review action detects there are no remaining tasks and sets `next_phase: "all-code-review"` instead of completing
- After `all-code-review` passes, then set `phase: "complete"`
- Updated the state transition diagram to include this final review step

### Issue 7: `--allowedTools` flag format may be wrong

- Removed `--allowedTools` entirely per user instruction: "All tools should be allowed, dangerously skip permissions should be enabled on each review invocation"
- Removed test case 5 from test suite 4 (CLI invocation tests) that verified `--allowedTools` flag
- Renumbered remaining test cases in suite 4 (now 12 tests, down from 13)

### Issue 8: `continue-plan` routing based on wrong field

- Updated `continue-plan` routing logic to check `next_phase` first:
  - If `next_phase` is non-null, route to the action corresponding to `next_phase` (that's the pending action the agent should do next)
  - If `next_phase` is null, fall back to routing based on `phase` (the last completed phase)
- This prevents re-running completed reviews when resuming after a crash

### Issue 9: No mechanism for the user to opt out of auto-review mid-workflow

- Added "Escape Hatch" section documenting how to break the automation loop
- User can edit `state.json` and set `next_phase: null` to stop the review cycle
- Added a note in the block message template informing the agent (and indirectly the user) about this option

## Notes

- Issue #5 (atomicity) was assessed as acceptable in the review — no changes needed
- Test suite 4 now has 12 tests (removed the `--allowedTools` test)
- The planning flow and implementation flow are now clearly separated in the automation boundary rule
