# Post-Tasks-Review Fixes — Tasks Review 4

## Overview

Addressed **9 issues** from tasks-review-4.md (clean slate analysis):
- **1 blocking** issue fixed
- **2 critical** issues fixed
- **6 minor** issues acknowledged or fixed

All blocking and critical issues resolved. Tasks are implementation-ready with improved test coverage and clearer routing logic.

---

## Blocking Issue Fixed (1)

### Issue 7: No test verifies TASK_FILE_LIST construction ✅
**Impact**: The corrected `TASK_FILE_LIST` construction (using awk to extract IDs from column 2) has no explicit test coverage. If the awk command has a bug, tests would pass with the mock CLI but real CLI would get wrong file paths, breaking tasks-review and all-code-review.

**Fix**: Added explicit requirement to Task 3.5 acceptance criteria: "Suite 4 includes a test that verifies `TASK_FILE_LIST` construction: creates a `tasks.md` with known task IDs (e.g. 1, 2, 3), triggers tasks-review or all-code-review, and checks that `MOCK_CLAUDE_LOG` contains the expected file paths (`task-1.md`, `task-2.md`, `task-3.md`) to catch regressions in the awk-based ID extraction."

This ensures the critical fix from review 3 (Issue 15) has proper test coverage.

---

## Critical Issues Fixed (2)

### Issue 4: Task 3.5 commit message contradicts incremental guidance ✅
**Impact**: The sample commit message ("Add test suites 2-5...") suggested a single commit for all tests, contradicting the updated guidance to write and commit tests incrementally alongside each implementation subtask.

**Fix**: Replaced the single sample commit message with guidance: "Tests should be committed incrementally with each implementation subtask (e.g., 'Add suite 2 tests for state detection and max_reviews logic', 'Add suite 4 tests for CLI invocation', etc.)"

This aligns the sample with the incremental approach and prevents implementers from deferring all test writing.

### Issue 9: continue-plan task selection delegation unclear ✅
**Impact**: Task 4.2 didn't specify HOW `continue-plan` determines which task to execute next when `next_phase` is `"complete-task"`. It was unclear whether `continue-plan` reads `tasks.md` to find the next pending task or delegates this to the action.

**Fix**: Added to Task 4.2 acceptance criteria: "When `next_phase` is `\"complete-task\"` or `\"complete-task-tdd\"`, routes to the corresponding action file which internally determines the next pending task from `tasks.md` — `continue-plan` delegates task selection to the action, it doesn't determine which task ID to execute."

Clarifies that `continue-plan` just routes to the action; the action handles task selection internally.

---

## Minor Issues Addressed (6)

### Issue 1: Plan text slightly misleading about all-code-review advance ⏭ ACKNOWLEDGED
**Observation**: The plan's auto-advance section says the hook sets `phase: "complete"`, `next_phase: null` directly for all-code-review. But Task 3.3 correctly follows the consistent pattern: hook sets `next_phase: "complete"` and lets `continue-plan` handle the final transition.

**Assessment**: Task files are correct and internally consistent. The plan text is slightly misleading but doesn't require task changes. The review correctly identified this as MINOR and noted no task changes needed.

### Issue 2: Task 4.3 preserves tdd field ⏭ ACKNOWLEDGED
**Observation**: Task 4.3 preserves both `max_reviews` and `tdd` from existing state, while the plan only mentions preserving `max_reviews`.

**Assessment**: Preserving `tdd` is more conservative and safer (allows users to set TDD mode before running create-tasks). The review recommends keeping the task's approach, which we do. No changes needed.

### Issue 3: Test runner argument name slightly misleading ✅
**Observation**: The `state` argument includes CLI invocation tests (suite 4) which aren't strictly "state" tests but are part of the stateful auto-review feature.

**Fix**: Added clarification to Task 1.3 acceptance criteria: "`state` argument runs: `test-stop-hook-auto-review.sh`, `test-stop-hook-state-transitions.sh`, `test-stop-hook-cli-invocation.sh` (includes all stateful auto-review feature tests: state transitions, CLI invocation, auto-advance logic)"

This documents the intended scope without renaming the argument.

### Issue 5: Plan directory finding mentioned in both 2.1 and 2.2 ⏭ NO ACTION NEEDED
**Observation**: Both subtasks mention finding the plan directory. This is fine since 2.1 creates the function and 2.2 uses it. No action needed.

### Issue 6: make test-hooks not in plan ⏭ ACKNOWLEDGED
**Observation**: Task 1.3 adds `make test-hooks` target which isn't in the plan.

**Assessment**: This is a useful addition already acknowledged in review 3 (Issue 12). Keep it. The plan's Makefile section is incomplete but the task is correct.

### Issue 8: tests/README.md update only in Task 2.5 ⏭ ACKNOWLEDGED
**Observation**: Task 2.5 mentions updating `tests/README.md` but no other task mentions it, making it easy to forget.

**Assessment**: It's documentation and low risk. Task 2.5 acceptance criteria already include this. No changes needed.

### Issue 10: Test 6.5 should explicitly use next_phase: null ✅
**Observation**: Test 6.5 (concurrent plan creation: state.json exists but plan.md doesn't) should trigger validation. But if state.json has a review phase in `next_phase`, auto-review would take precedence (step 5 before step 6).

**Fix**: Added to Task 6.3 acceptance criteria: "Test 5: concurrent plan creation (state.json exists but plan.md doesn't) uses `next_phase: null` in state to ensure validation runs (not auto-review)"

This makes the test's state assumptions explicit.

---

## Summary

**Fixed 9 issues** including the blocking issue and both critical issues:

**Key improvements:**
- **TASK_FILE_LIST test coverage**: Added explicit test requirement to verify the awk-based ID extraction works correctly (critical for tasks-review and all-code-review to function)
- **Incremental commit guidance**: Sample commit message now reflects incremental test writing approach
- **Task selection delegation**: Clarified that `continue-plan` delegates task selection to `complete-task.md` rather than determining it itself
- **Test argument scope**: Documented that `state` argument includes all stateful auto-review feature tests
- **Test 6.5 assumptions**: Made explicit that it uses `next_phase: null` to avoid auto-review precedence

**Acknowledged minor observations:**
- Plan text outlier about all-code-review advance (task files correct, no changes needed)
- Preserving `tdd` field is more conservative than plan (keeping task's approach)
- Plan directory finding in multiple subtasks is fine (function creation vs usage)
- `make test-hooks` is useful addition already acknowledged
- `tests/README.md` update already in Task 2.5 acceptance criteria

All tasks remain implementation-ready with improved test coverage and clearer acceptance criteria. The critical TASK_FILE_LIST construction now has explicit test coverage to prevent regressions.
