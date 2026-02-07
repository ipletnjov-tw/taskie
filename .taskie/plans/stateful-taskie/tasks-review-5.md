# Tasks Review 5 — Clean Slate Analysis

Examining `tasks.md` and all 6 task files against `plan.md`. No prior reviews consulted.

---

## Severity Key

- **BLOCKING**: Will cause incorrect behavior if shipped. Must fix.
- **CRITICAL**: High risk of confusion or rework. Strongly recommended.
- **MINOR**: Cosmetic or clarity. Fix if convenient.

---

## Issue 1: BLOCKING — Plan's `TASK_FILE_LIST` construction (line 231-232) still uses the OLD broken grep pattern, but Task 3.2 has the CORRECT awk-based approach

**Plan** (CLI Invocation section, line 231-232):
```bash
TASK_FILE_LIST=$(grep '^|' ".taskie/plans/${PLAN_ID}/tasks.md" | grep -oE 'task-[0-9]+\.md' | sort -u | sed "s|^|.taskie/plans/${PLAN_ID}/|" | tr '\n' ' ')
```

**Task 3.2** acceptance criteria:
```bash
grep '^|' tasks.md | tail -n +3 | awk -F'|' '{gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9]+$/) printf ".taskie/plans/'${PLAN_ID}'/task-%s.md ", $2}'
```

The plan still contains the broken pattern that greps for literal `task-N.md` strings in the table (which don't exist — the table has numeric IDs in the Id column, not filenames). Task 3.2 correctly fixed this to extract IDs from column 2. **The plan text is stale and contradicts the task.** During implementation, the implementer might follow the plan's code instead of the task's acceptance criteria.

**Recommendation**: Update the plan's CLI Invocation section to match Task 3.2's corrected approach. The plan is the source of truth for design decisions, and having stale code samples creates confusion.

---

## Issue 2: BLOCKING — No test verifies the `TASK_FILE_LIST` construction produces correct file paths from numeric task IDs

**Plan test suites**: Test suite 4, test 7 says "Tasks review prompt contains tasks reference — prompt contains `tasks.md` and `tasks-review-`". This only checks that the prompt mentions `tasks.md`, NOT that individual task file paths (`task-1.md`, `task-2.md`, etc.) are correctly extracted from the Id column and included in the prompt.

**Task 3.2** and **Task 3.5**: Neither specifies a test that creates a `tasks.md` with known IDs (e.g. 1, 2, 3) and then verifies the mock CLI log contains `task-1.md task-2.md task-3.md` in the prompt.

**Problem**: The corrected `TASK_FILE_LIST` awk command is complex (field extraction, whitespace stripping, numeric validation, path construction). If it has a bug, all existing tests would still pass because the mock CLI accepts any prompt. The actual file paths in the prompt would be wrong, and real reviews would get no task context.

**Recommendation**: Add a test to suite 4 (or suite 6) that: (1) creates a `tasks.md` with IDs 1, 2, 3 in the table; (2) triggers a tasks-review; (3) checks `MOCK_CLAUDE_LOG` contains all three constructed file paths. This is the only way to catch regressions in the awk pipeline.

---

## Issue 3: MINOR — Task 3.5 sample git commit message still suggests a single commit

**Task 3.5** sample commit message: "Add test suites 2-5 for auto-review, state transitions, CLI invocation, block messages"

**Task 3.5** updated guidance: "Write tests alongside implementation: as you complete each implementation subtask (3.1-3.4), immediately write and commit the corresponding tests."

The sample message contradicts the incremental approach. An implementer following the sample message would batch all tests into one commit.

**Recommendation**: Either remove the sample commit message from 3.5 (since tests are committed with each implementation subtask) or replace it with a note like "Tests should be committed alongside their corresponding implementation subtask — no single test commit is expected."

---

## Issue 4: MINOR — Task 4.2 doesn't explicitly state that `continue-plan` delegates next-task selection to `complete-task.md`

**Plan** (Modified Actions, item 1): "`next_phase` = `"complete-task"` / `"complete-task-tdd"` → execute the next task with the automation entry point"

**Task 4.2** acceptance criteria: "Routes correctly for both `complete-task` and `complete-task-tdd` variants when either is the `next_phase` value"

When `continue-plan` sees `next_phase: "complete-task"`, it needs to execute the `complete-task.md` action. That action internally determines which task to implement next by reading `tasks.md`. But the acceptance criteria don't clarify this delegation — an implementer might think `continue-plan` needs to determine the next task ID itself and pass it to `complete-task`.

**Recommendation**: Add a note to Task 4.2's acceptance criteria: "When routing to `complete-task` or `complete-task-tdd`, simply execute the action file — the action itself determines the next pending task from `tasks.md`."

---

## Issue 5: MINOR — Edge case test 6.5 should specify `next_phase: null` to avoid auto-review taking precedence

**Test 6.5**: "Concurrent plan creation — state.json exists but plan.md doesn't — validation blocks for missing plan.md (rule 1)"

**Test 6.6**: "Auto-review takes precedence over validation — `next_phase: "code-review"` but plan dir has nested files — hook runs review and blocks for post-review"

If test 6.5's state.json has `next_phase: "code-review"`, auto-review would fire before validation, making the test fail for the wrong reason. The test needs `next_phase: null` (or a non-review phase) so validation actually runs.

**Recommendation**: Add explicit note in test 6.5's description or Task 6.3's acceptance criteria that the state.json for this test uses `next_phase: null`.

---

## Overall Assessment

The tasks are in good shape after 4 rounds of review. The two remaining blocking issues (#1 and #2) are closely related — both concern the `TASK_FILE_LIST` construction. Issue #1 is a stale plan (the task has the fix, but the plan contradicts it). Issue #2 is a missing test to validate the fix actually works.

The minor issues (#3, #4, #5) are all clarity/documentation concerns that reduce implementation risk but aren't correctness issues.

---

## Summary

| # | Severity | Summary |
|---|----------|---------|
| 1 | BLOCKING | Plan's `TASK_FILE_LIST` code sample is stale — contradicts Task 3.2's corrected awk approach |
| 2 | BLOCKING | No test verifies `TASK_FILE_LIST` produces correct paths from numeric task IDs |
| 3 | MINOR | Task 3.5 sample commit message suggests single commit, contradicting incremental guidance |
| 4 | MINOR | Task 4.2 doesn't clarify that next-task selection is delegated to `complete-task.md` |
| 5 | MINOR | Edge case test 6.5 should explicitly specify `next_phase: null` in state.json |

**Blocking (2)**: #1, #2
**Minor (3)**: #3, #4, #5
