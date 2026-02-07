# Post-Review Fixes — Plan Review 8 (Clean Slate)

## Issues Addressed

### Issue 1: `complete-task` delegation fragility (HIGH)

- Eliminated the delegation + override pattern entirely
- `complete-task.md` / `complete-task-tdd.md` now contain their OWN implementation instructions (inlining the relevant parts of `next-task.md`) rather than delegating
- Removed the fragile "skip this state update if invoked from `complete-task`" conditional from `next-task.md`
- `next-task.md` is now purely standalone — always writes `next_phase: null`, no conditional logic
- The ~10 lines of implementation instruction duplication is a worthwhile trade for eliminating the cross-prompt conditional

### Issue 2: Crash recovery blind spot for half-written plans/tasks (MEDIUM)

- Added artifact completeness checks to the `continue-plan` crash recovery heuristic:
  - **plan-review**: verify `plan.md` exists and appears complete (contains `## Overview` heading or is > 50 lines). If incomplete, execute `new-plan.md` to continue.
  - **tasks-review**: verify `tasks.md` exists and contains actual table rows. If incomplete, execute `create-tasks.md` to finish.
  - **code-review/all-code-review**: unchanged (check task file subtask completion)
- This prevents the hook from reviewing half-written artifacts that would always VERDICT: FAIL

### Issue 3: `TASK_FILE_LIST` regex portability (MEDIUM)

- Replaced `grep -oP 'task-\d+\.md'` (Perl regex, not available on macOS) with POSIX-compatible pipeline
- First `grep '^|'` restricts to table rows only, avoiding false positives from prose
- Second `grep -oE 'task-[0-9]+\.md'` uses POSIX Extended Regex

### Issue 4: `.hook-lock` complexity (MEDIUM)

- Removed the `.hook-lock` mechanism entirely
- Replaced with a note explaining that `stop_hook_active` + `max_reviews` provide sufficient loop detection
- The lock file added complexity (race conditions, cleanup on crash, arbitrary timeouts) without meaningful additional safety

### Issue 5: Auto-advance detection moved to hook (MEDIUM)

- Moved the remaining-tasks check from `next-task.md` to hook step 5g
- For code review auto-advance, the hook now checks `tasks.md` for remaining pending tasks:
  - If tasks remain: `next_phase: "next-task"`
  - If no tasks remain: `next_phase: "all-code-review"` with fresh review cycle fields
- `next-task.md` is now simple: always standalone, always `next_phase: null`
- The hook is the right place for this logic since it's programmatic shell code where `grep`/`awk` reliably determines remaining tasks

### Issue 6: `continue-plan` catch-all semantics (MEDIUM)

- Changed the catch-all for null `next_phase` + review/post-review `phase` from "fall back to git history" to "inform user and ask"
- Git history fallback would produce confusing results when a state file exists but automation intent is ambiguous
- Git history fallback is now reserved ONLY for when `state.json` doesn't exist (true backwards compatibility)

### Issue 7: Empty `TASK_FILE_LIST` handling (LOW-MEDIUM)

- Added empty-list guard: if `TASK_FILE_LIST` is empty, hook logs warning and skips review (approves)
- For code-review of a single task, hook uses `current_task` from `state.json` directly — no need to parse `tasks.md`
- `TASK_FILE_LIST` is only needed for tasks-review and all-code-review prompts

### Issue 8: `max_reviews` naming ambiguity (LOW-MEDIUM)

- Expanded field description to explicitly state per-cycle semantics
- Added concrete example: "`max_reviews: 4` allows up to 4 plan reviews AND 4 tasks reviews AND 4 code reviews per task AND 4 all-code-reviews"
- Kept the field name as `max_reviews` (renaming would break any existing state files)

### Issue 9: Schema versioning / forward-compatibility (LOW)

- Added "Forward-compatibility" note in Validation Hook Updates section
- Hook uses `jq` default operators (`(.field // default)`) when reading all `state.json` fields
- New fields can be added in future versions without breaking existing state files
- No formal schema version number needed at this stage

### Issue 10: Test distribution strategy (LOW)

- Added "Test distribution strategy" note in Test Execution section
- Tests should be written alongside their corresponding feature implementation
- Test infrastructure (shared helpers, mock claude, test runner) should be its own task since other tasks depend on it

### Issue 11: stderr-only capture (LOW)

- Changed `> /dev/null 2>"$REVIEW_LOG"` to `>"$REVIEW_LOG" 2>&1`
- Both stdout and stderr captured to the log file
- Review content is written to disk via Write tool (not stdout), so capturing stdout doesn't lose anything
- All diagnostic output now available for debugging failures

## Notes

- All 11 issues addressed — no dismissals
- 1 HIGH severity: delegation pattern eliminated entirely (inlining, no conditional)
- 5 MEDIUM severity: crash recovery, grep portability, hook-lock removal, auto-advance moved to hook, catch-all semantics
- 5 LOW/LOW-MEDIUM severity: empty list guard, naming clarification, forward-compat, test strategy, log capture
- Issue 5 (auto-advance in hook) and Issue 1 (delegation) are related — both simplify `next-task.md` by removing conditional logic
