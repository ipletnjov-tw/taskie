# Post-Review Fixes — Plan Review 4

## Issues Addressed

### Issue 1: Replace naive keyword heuristic with structured VERDICT: PASS/FAIL

- Replaced the keyword-based clean review detection ("issue", "problem", "bug", etc.) with a structured `VERDICT: PASS/FAIL` line
- Updated step 5e: hook now checks `grep -q "^VERDICT: PASS$"` on the review file — simple, unambiguous, no false positives from phrases like "No issues found"
- Updated the "How the hook detects clean review" section to describe the verdict approach
- Updated ALL CLI prompts (code review, plan review, tasks review, all-code-review) to include: "At the very end of your review, write exactly one of these lines: VERDICT: PASS (if no issues found) or VERDICT: FAIL (if issues found)."
- Updated mock claude script to use `MOCK_CLAUDE_VERDICT` env var (defaults to "FAIL"), writing the appropriate verdict line in mock review files
- Updated test descriptions (suites 2, 3, 6) to reference `MOCK_CLAUDE_VERDICT` instead of "mock writes clean/dirty review"
- Added CLI invocation test 14: verifies prompt contains VERDICT instruction

### Issue 2: Move "remaining tasks" check from hook to action prompts

- Updated step 5f: hook now always sets `next_phase: "next-task"` for code review auto-advance — it does NOT check remaining tasks
- The `continue-plan`/`next-task` action reads `tasks.md`, discovers no remaining tasks, and sets `next_phase: "all-code-review"` itself
- This keeps the hook simple: it only reads/writes `state.json` and invokes `claude`

### Issue 3: Clarify continue-task mode detection

- Updated action item #10: `continue-task` now reads `next_phase` from current `state.json` before updating
- If `next_phase` is already set (e.g. `"code-review"`), it was set by a prior automation command — preserved unchanged
- If `next_phase` is null, it's standalone mode — kept null
- `continue-task` is now a transparent pass-through for `next_phase`

### Issue 4: Add missing all-code-review block message template

- Added a fourth block message template for all-code-review, following the same pattern as the other three
- Includes atomic state update instructions, field preservation list, and temp-file-then-mv instruction

### Issue 5: Clarify max_reviews: 0 semantics

- `max_reviews: 0` now means "skip all reviews" — the hook allows the stop without blocking and without a hard stop
- Updated step 6a: hard stop condition is now `phase_iteration > max_reviews AND max_reviews > 0`
- Updated the review exit conditions section to document this special case
- Updated edge case test 8 to reflect "skip reviews, no hard stop — workflow proceeds normally"

### Issue 6: Add concrete tasks review CLI prompt

- Added explicit tasks review prompt (was hand-waved as "similarly adapted")
- The prompt reads ground rules, `tasks.md`, and all `task-*.md` files, invokes `tasks-review.md` action, writes to `tasks-review-${ITERATION}.md`
- Also added explicit all-code-review CLI prompt (was implicitly missing)

### Issue 7: Document model reset per-cycle

- Added explicit note: "Model always resets to `opus` at the start of each new review cycle (strongest model first). Each action that enters a review cycle (`new-plan`, `create-tasks`, `complete-task`, `complete-task-tdd`) initializes `review_model: "opus"`."

### Issue 8: Update Overview language

- Changed "until either all reviews pass or the max review limit is reached" to "until two consecutive reviews find no issues, or the max review limit is reached (in which case the agent waits for user input)"

## Additional Changes

### All-code-review CLI prompt added

The all-code-review prompt was implicitly missing from the CLI invocation section (only code review, plan review, and tasks review had concrete prompts). Added it explicitly — reads plan, tasks, and all task files.

### CLI invocation test for all-code-review

Added test 8 to Suite 4 verifying the all-code-review prompt. Renumbered subsequent tests. Also added test 14 verifying the VERDICT instruction appears in prompts.

### Updated test counts

CLI invocation: 12 → 14 (added all-code-review prompt test and VERDICT instruction test). Total: 74 → 76.

## Notes

- The `VERDICT: PASS/FAIL` approach is the primary mechanism for clean review detection. No keyword matching remains.
- The `MOCK_CLAUDE_VERDICT` env var defaults to `"FAIL"`, so existing tests that don't set it will produce review files with issues (matching the default behavior of the old mock).
- Hook complexity is reduced: no remaining-tasks check in the hook, no keyword matching heuristic. The hook reads state, runs claude, greps for VERDICT, updates state.
