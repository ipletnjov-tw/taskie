# Post-Review Fixes — Plan Review 7 (Clean Slate)

## Issues Addressed

### Issue 1: `complete-task` delegation anti-pattern (HIGH)

- Adopted recommendation (c): `complete-task.md` now explicitly instructs the LLM: "Implement the task as described in `next-task.md`, but do NOT update `state.json` during implementation — `complete-task` handles the state update in the next step."
- Added a reciprocal note in `next-task.md`: "Skip this state update if you were invoked from `complete-task` or `complete-task-tdd`."
- Documented the fragility risk: the LLM might still follow `next-task.md`'s state-writing instructions if they are emphatic enough. Both prompts now contain explicit overrides to mitigate.

### Issue 2: `continue-plan` crash recovery ambiguity (HIGH)

- Upgraded the crash recovery heuristic from a single-level (`phase` check only) to a two-level check:
  1. Check `phase`: if it's a post-review value, the post-review completed — just stop.
  2. Check task file status: read `task-{current_task}.md` and check if all subtasks are marked complete. If yes, implementation finished normally — stop. If subtasks remain incomplete, the agent crashed mid-implementation — run `continue-task.md`.
- For plan-review/tasks-review (no task file), always stop since plan/tasks creation is atomic.

### Issue 3: All-code-review token bomb (MEDIUM)

- Replaced `task-*.md` glob with `${TASK_FILE_LIST}` in both tasks-review and all-code-review CLI prompts
- `TASK_FILE_LIST` is constructed by the hook from `tasks.md` by extracting task IDs from table rows and expanding to `task-{N}.md` paths
- Documented the extraction command: `grep -oP 'task-\d+\.md' tasks.md | sort -u | sed ...`
- This prevents review/post-review files (e.g. `task-1-review-2.md`) from being included in the CLI context

### Issue 4: Find heuristic ignores state.json (MEDIUM)

- Updated step 3 to use `\( -name "*.md" -o -name "state.json" \)` in the find pattern
- Explained the rationale: writes to state.json during automated review cycles wouldn't update the "most recent plan" heuristic without this

### Issue 5: `max_reviews` default cost implications (MEDIUM)

- Added Risk Assessment item #9 documenting worst-case review counts: 24 + 8N for N tasks
- Included concrete example: 104 invocations for a 10-task plan, ~17 hours at ceiling
- Noted that typical counts are much lower (2-4 iterations per cycle due to consecutive-clean exit)
- Suggested lowering to 4 for tighter control

### Issue 6: No mechanism to skip all-code-review only (LOW)

- Documented the manual escape hatch after the auto-advance boundaries section
- User can set `phase: "complete"`, `next_phase: null` in state.json after last task's code review
- Explained why this is left as a manual choice rather than automatic

### Issue 7: Block message timing (MEDIUM)

- Added "AFTER completing all post-review work and writing the post-review file," to all four block message templates
- This makes the ordering explicit: work first, then state update
- Also added the escape hatch note to each block message: "(To stop the review loop, set next_phase to null in state.json.)"

### Issue 8: `continue-plan` catch-all for unmatched states (LOW)

- Added catch-all routing rule for `next_phase: null` with any unmatched `phase` value
- Falls back to git history analysis (pre-stateful behavior)
- Updated the git history fallback note to mention both triggers: missing state.json OR catch-all

### Issue 9: Stdout/stderr suppression (LOW)

- Changed `> /dev/null 2>&1` to `> /dev/null 2>"$REVIEW_LOG"` in the CLI invocation example
- `REVIEW_LOG` is `.taskie/plans/${PLAN_ID}/.review-${ITERATION}.log` (dotfile)
- Log is cleaned up after successful reviews, persists on failure for debugging
- Documented the cleanup behavior

### Issue 10: `stop_hook_active` origin undocumented (HIGH)

- Documented `stop_hook_active` as a Claude Code hook event field, noting the existing `validate-ground-rules.sh` relies on it
- Explained when it's set: when the stop is triggered by the agent resuming from a hook block
- Added fallback loop detection: `.hook-lock` timestamp file written at review start, checked at hook entry
- If `.hook-lock` exists with timestamp < 30 seconds old, hook approves immediately (defense-in-depth)
- Updated step 1 of hook logic to reference the fallback

## Notes

- All 10 issues addressed — no dismissals
- 3 HIGH severity issues fixed: delegation anti-pattern, crash recovery, stop_hook_active
- 4 MEDIUM severity issues fixed: token bomb, find heuristic, cost docs, block timing
- 3 LOW severity issues fixed: skip all-code-review, catch-all routing, stderr logging
- Issue 11 (test count mismatch) was self-corrected by the reviewer — count is actually 80 ✓
