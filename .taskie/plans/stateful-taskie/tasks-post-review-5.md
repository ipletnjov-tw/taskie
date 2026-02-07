# Post-Tasks-Review Fixes — Tasks Review 5

## Overview

Addressed **5 issues** from tasks-review-5.md:
- **2 blocking** issues (1 new fix, 1 already fixed in review 4)
- **3 minor** issues (all already fixed in review 4)

Only 1 new issue required fixing: the stale plan.md code sample. All other issues were already addressed in review 4 but the reviewer didn't notice the updates (clean slate analysis with no prior review consultation).

---

## Blocking Issues

### Issue 1: Plan's TASK_FILE_LIST code sample is stale ✅ NEW FIX
**Impact**: The plan.md still contained the OLD broken grep pattern that searches for literal `task-N.md` strings in the table (which don't exist). Task 3.2 has the CORRECT awk-based approach that extracts numeric IDs from column 2. During implementation, an implementer might follow the plan's stale code instead of the task's acceptance criteria.

**Fix**: Updated plan.md lines 230-235 to match Task 3.2's corrected approach:
```bash
TASK_FILE_LIST=$(grep '^|' ".taskie/plans/${PLAN_ID}/tasks.md" | tail -n +3 | awk -F'|' '{gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9]+$/) printf ".taskie/plans/'${PLAN_ID}'/task-%s.md ", $2}')
```

Updated the explanation to clarify: "extracts numeric task IDs from the Id column (column 2) of the table" and "This approach works with the current `tasks.md` format where task IDs are numeric values in the Id column, not literal filename strings."

The plan now matches the task files and won't mislead implementers.

### Issue 2: No test verifies TASK_FILE_LIST construction ✅ ALREADY FIXED IN REVIEW 4
**Reviewer claim**: "No test verifies `TASK_FILE_LIST` produces correct paths from numeric task IDs."

**Reality**: This was **Issue 7 (BLOCKING) in review 4** and was already fixed. Task 3.5 acceptance criteria line 105 explicitly states: "Suite 4 includes a test that verifies `TASK_FILE_LIST` construction: creates a `tasks.md` with known task IDs (e.g. 1, 2, 3), triggers tasks-review or all-code-review, and checks that `MOCK_CLAUDE_LOG` contains the expected file paths (`task-1.md`, `task-2.md`, `task-3.md`) to catch regressions in the awk-based ID extraction."

**No action needed** — already fixed.

---

## Minor Issues

### Issue 3: Task 3.5 sample commit message suggests single commit ✅ ALREADY FIXED IN REVIEW 4
**Reviewer claim**: "Task 3.5 sample commit message still suggests a single commit."

**Reality**: This was **Issue 4 (CRITICAL) in review 4** and was already fixed. Task 3.5 line 95 now states: "Tests should be committed incrementally with each implementation subtask (e.g., 'Add suite 2 tests for state detection and max_reviews logic', 'Add suite 4 tests for CLI invocation', etc.)"

**No action needed** — already fixed.

### Issue 4: Task 4.2 doesn't clarify task selection delegation ✅ ALREADY FIXED IN REVIEW 4
**Reviewer claim**: "Task 4.2 doesn't explicitly state that `continue-plan` delegates next-task selection to `complete-task.md`."

**Reality**: This was **Issue 9 (CRITICAL) in review 4** and was already fixed. Task 4.2 line 37 explicitly states: "When `next_phase` is `\"complete-task\"` or `\"complete-task-tdd\"`, routes to the corresponding action file which internally determines the next pending task from `tasks.md` — `continue-plan` delegates task selection to the action, it doesn't determine which task ID to execute."

**No action needed** — already fixed.

### Issue 5: Test 6.5 should specify next_phase: null ✅ ALREADY FIXED IN REVIEW 4
**Reviewer claim**: "Edge case test 6.5 should specify `next_phase: null` to avoid auto-review taking precedence."

**Reality**: This was **Issue 10 (MINOR) in review 4** and was already fixed. Task 6.3 line 52 explicitly states: "Test 5: concurrent plan creation (state.json exists but plan.md doesn't) uses `next_phase: null` in state to ensure validation runs (not auto-review)."

**No action needed** — already fixed.

---

## Summary

**Fixed 1 new issue** (the stale plan.md code sample):
- Updated plan.md to use the correct awk-based `TASK_FILE_LIST` construction that extracts IDs from column 2, matching Task 3.2's acceptance criteria

**4 issues already fixed in review 4**:
- Issue 2: TASK_FILE_LIST test coverage (review 4, issue 7)
- Issue 3: Incremental commit message (review 4, issue 4)
- Issue 4: Task selection delegation (review 4, issue 9)
- Issue 5: Test 6.5 state assumptions (review 4, issue 10)

**Key insight**: The reviewer performed a "clean slate analysis" without consulting prior reviews, which led to re-flagging 4 issues that were already resolved. This is actually positive validation — it confirms that the fixes from review 4 were correct and complete.

All tasks remain implementation-ready. The plan.md is now in sync with the task files.
