# Post-Review Fixes — Plan Review 5

## Issues Addressed

### Issue 1: `max_reviews: 0` auto-advance path doesn't update state correctly

- Added explicit early-return in step 5a: when `max_reviews == 0`, the hook sets `next_phase` to the advance target (same mapping as step 5g), sets `phase` to the review phase, writes state atomically, and approves immediately
- No `phase_iteration` increment, no `claude` invocation — genuine "skip all reviews"
- Updated step 6a: removed the `max_reviews == 0` special case since it's now handled in step 5a (never reaches step 6)
- Updated review exit conditions section to describe `max_reviews: 0` as a distinct third exit condition
- Updated edge case test 8 to verify state is updated (`next_phase` set to advance target, `phase_iteration` unchanged, mock not invoked)

### Issue 2: Step 5f `phase` value after auto-advance — DISMISSED (cosmetic)

The review correctly identifies this as cosmetic. `phase: "code-review"` after auto-advance is acceptable because `continue-plan` routes on `next_phase`, not `phase`. No change needed.

### Issue 3: `continue-plan` crash recovery heuristic undefined

- Updated the `continue-plan` routing for review phases with a concrete heuristic: check if `phase` is a post-review value (`"post-code-review"`, `"post-plan-review"`, `"post-tasks-review"`, `"post-all-code-review"`)
- If `phase` IS a post-review value: the post-review was completed, agent should simply stop to trigger the hook
- If `phase` is NOT a post-review value (e.g. `"next-task"`, `"continue-task"`): agent was mid-implementation, execute `continue-task.md`
- This replaces the vague "verify whether the current task/phase has outstanding work" with an unambiguous check

### Issue 4: `all-code-review` CLI prompt doesn't read source code — DISMISSED (acceptable)

The review correctly identifies this as acceptable. The action file instructs the reviewer what to do, and the subprocess has full tool access via `--dangerously-skip-permissions` to read whatever source files it needs. No change to CLI prompts needed.

### Issue 5: `max_reviews` as `new-plan` argument — DEFERRED

Nice UX improvement but not a blocker for v1. The user can edit `state.json` after `new-plan` runs. Can be added in a future version.

### Issue 6: Step 5f auto-advance incomplete write (only `phase` and `next_phase`)

- Updated step 5g (formerly 5f) to explicitly list ALL modified fields in the atomic write: `phase`, `next_phase`, `phase_iteration` (incremented), `review_model` (toggled), `consecutive_clean` (incremented)
- This ensures the auto-advance path doesn't leave stale values on disk
- Added test 15 to Suite 3 verifying all fields are updated after auto-advance

### Issue 7: Block message field lists inconsistent

- Added explicit field enumeration `(max_reviews, current_task, phase_iteration, review_model, consecutive_clean)` to plan review and tasks review block message templates
- All four templates now consistently enumerate the preserved fields

### Issue 8: Missing auto-advance tests per review type

- Added tests 12-14 to Suite 3 covering auto-advance for each review type:
  - Test 12: plan review → `"create-tasks"`
  - Test 13: tasks review → `"next-task"`
  - Test 14: all-code-review → `"complete"`
- Added test 15: verifies auto-advance writes ALL modified fields (not just `phase` and `next_phase`)
- Suite 3 count: 12 → 16, total: 76 → 80

## Additional Changes

### Step renumbering

Steps 5b-5g were renumbered to 5b-5h to accommodate the new step 5a early-return for `max_reviews == 0`. The logic is unchanged; only the letter labels shifted.

## Notes

- Three issues dismissed or deferred (#2 cosmetic, #4 acceptable, #5 deferred to future version)
- Five issues addressed with concrete plan edits (#1, #3, #6, #7, #8)
- Total test count: 80 (up from 76)
- The `max_reviews: 0` path is now a clean early-return that genuinely advances state, eliminating the infinite stop-restart cycle identified in the review
