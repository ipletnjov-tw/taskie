# Tasks Review 7

## Overview

Performed a clean slate review of the task list (`tasks.md`) and all task files (`task-1.md` through `task-6.md`) against the plan (`plan.md`). The review focuses on ensuring tasks EXACTLY match the plan requirements, identifying mistakes, inconsistencies, misunderstandings, misconceptions, scope creep, over-engineering, and other issues.

---

## Critical Issues (Must Fix)

### C1: Task 1.3 missing test-hooks target requirement

**Location**: `task-1.md` line 76

**Issue**: The acceptance criteria list `make test-state`, `make test-validation`, and `make test` targets, but the plan explicitly requires a `make test-hooks` target.

Plan line 422: `make test-hooks` runs all hook tests

**Fix required**: Add to acceptance criteria:
- `make test-hooks` runs all test files in `tests/hooks/` (all `test-*.sh` files)

---

### C2: Task 3.2 CLI subprocess timeout handling is fundamentally wrong

**Location**: `task-3.md` lines 46-47

**Issue**: The acceptance criteria state:
> "CLI subprocess timeout is handled by Claude Code's 600s hook timeout — do NOT use the shell `timeout` command (not available on macOS). If the hook is killed by the system timeout, the stop is allowed through by default. **KNOWN LIMITATION**: If the hook times out after incrementing `phase_iteration` but before writing the review file, `state.json` will be left inconsistent."

This describes the **problem** but fails to specify the **recovery mechanism**. The plan explicitly addresses this:

Plan line 322 (task 4.2 description):
> "Two-level crash recovery heuristic for review phases... Checks artifact completeness for code-review/all-code-review (reads `task-{current_task}.md` from state.json and verifies all subtask status markers are complete)"

Plan lines 44-46:
> "The hook uses this to auto-advance to `"complete-task-tdd"` or `"complete-task"` after code review passes — ensuring the same workflow variant is used for all tasks in the plan."

The crash recovery in `continue-plan.md` (task 4.2) is the **solution** to this timeout limitation, not just an unrelated feature. The task should acknowledge this connection.

**Fix required**: Add note in 3.2 acceptance criteria:
- "The crash recovery heuristic in task 4.2 (`continue-plan.md`) handles timeout-induced inconsistency by checking artifact completeness when resuming"

---

### C3: Task 4.2 artifact completeness check for plan.md uses OR logic — should be AND

**Location**: `task-4.md` line 40

**Issue**: The acceptance criteria state:
> "Checks artifact completeness for plan-review (plan.md exists and has `## Overview` heading OR >50 lines — either condition suffices)"

The plan (line 323) says:
> "**For plan-review**: verify `plan.md` exists and appears complete (contains an `## Overview` heading or is > 50 lines)."

Using OR logic here is dangerous: a completely empty `plan.md` with 51 lines of whitespace would pass the ">50 lines" check, even though it's clearly incomplete.

**Fix required**: Change to AND logic:
- "plan.md exists AND (has `## Overview` heading OR >50 lines)"

This ensures the file exists before checking line count.

---

## Blocking Issues (Must Address Before Implementation)

### B1: Task 5.2 missing instruction about task selection

**Location**: `task-5.md` line 38

**Issue**: The acceptance criteria don't specify how `complete-task` and `complete-task-tdd` determine WHICH task to implement. The plan doesn't explicitly state this either, but the current behavior is that these actions read `tasks.md` and find the first pending task.

**Context**: Looking at the plan's state transitions (lines 84-91), `complete-task` is shown advancing to the next task repeatedly. Line 121 says "If no tasks remain, the hook sets `next_phase: "all-code-review"` instead."

The hook checks for remaining tasks (task 3.3), but the **action file** needs to select which task to implement.

**Fix required**: Add to acceptance criteria:
- "Action reads `tasks.md` and selects the first task with status 'pending' (same logic as current implementation)"
- "Sets `current_task` in state.json to the selected task ID"

---

### B2: Task 4.2 missing explicit instruction for "no state.json" fallback

**Location**: `task-4.md` line 44

**Issue**: The acceptance criteria say "Falls back to git history ONLY when `state.json` doesn't exist" but don't specify WHAT the git history fallback should do.

The current `continue-plan.md` action has complex git history analysis logic. Should this be preserved unchanged, or updated?

**Fix required**: Add to acceptance criteria:
- "Git history fallback uses existing logic from current `continue-plan.md` (preserved unchanged for backwards compatibility)"

---

## Minor Issues (Should Fix)

### M1: Task 1.1 acceptance criteria missing function signature details

**Location**: `task-1.md` lines 18-27

**Issue**: The acceptance criteria list the 8 required functions but don't specify their expected signatures (parameters, return values). This could lead to inconsistent implementations.

**Recommendation**: Add brief signature documentation:
- `pass(message)` — logs success, increments pass counter
- `fail(message)` — logs failure, increments fail counter
- `create_test_plan(dir)` — creates plan.md + tasks.md in directory
- `create_state_json(dir, json_string)` — writes json_string to dir/state.json
- `run_hook(json_input)` — pipes JSON to hook, returns stdout+stderr+exit code
- `assert_approved(result)` — verifies hook approved (exit 0, no block)
- `assert_blocked(result, pattern)` — verifies hook blocked with reason matching pattern
- `print_results()` — prints summary, exits 1 if failures exist

---

### M2: Task 2.5 version bump is MAJOR but reasoning could be clearer

**Location**: `task-2.md` line 90

**Issue**: The acceptance criteria specify a MAJOR version bump (2.2.1 → 3.0.0), which is correct, but the reasoning is brief: "MAJOR: 2.2.1 → 3.0.0"

**Recommendation**: Expand reasoning to match CLAUDE.md requirements:
- "MAJOR bump (2.2.1 → 3.0.0) — breaking change: replaces `validate-ground-rules.sh` hook with `stop-hook.sh`, changes hook behavior (adds auto-review), increases timeout from 5s to 600s"

---

### M3: Task 3.5 test count doesn't match plan

**Location**: `task-3.md` line 102

**Issue**: Acceptance criteria say:
> "`tests/hooks/test-stop-hook-auto-review.sh` contains 15 tests (suite 2) + 6 tests (suite 5) = 21 tests"

But the plan shows:
- Suite 2: 15 tests (lines 529-546)
- Suite 5: 6 tests (lines 593-603)

Total: 21 tests ✓ (This is actually correct!)

Wait, let me re-count the plan:

Suite 2 (test-stop-hook-auto-review.sh):
- Lines 532-546: tests 1-15 = 15 tests ✓

Suite 5 (block message templates):
- Lines 596-603: tests 1-6 = 6 tests ✓

Total: 21 tests in test-stop-hook-auto-review.sh ✓

**No fix required** — the count is correct.

---

### M4: Task 5.1 missing preservation of phase_iteration field

**Location**: `task-5.md` line 26

**Issue**: The acceptance criteria state:
> "All other fields (`max_reviews`, `phase_iteration`, `review_model`, `consecutive_clean`, `tdd`) preserved from existing state via read-modify-write"

But this is for `next-task` and `next-task-tdd`, which are standalone commands that exit the review loop. When entering standalone mode, `phase_iteration` should be set to `null` (not preserved), because we're no longer in a review cycle.

Looking at the plan schema (line 49):
> "`phase_iteration` | number\|null | ... Null during non-review phases."

**Fix required**: Change acceptance criteria to:
- "All other fields preserved EXCEPT `phase_iteration` which is set to `null` (standalone, not in review cycle)"

---

### M5: Task 6.3 test 5 description unclear

**Location**: `task-6.md` line 52

**Issue**: The acceptance criteria for test 5 state:
> "Test 5: concurrent plan creation (state.json exists but plan.md doesn't) uses `next_phase: null` in state to ensure validation runs (not auto-review)"

This is confusing. If `state.json` exists with `next_phase: null`, the hook will skip auto-review (step 5) and fall through to validation (step 6). But the test description suggests this is about "concurrent plan creation" — what does that mean?

Looking at the plan (line 615):
> "Concurrent plan creation | state.json exists but plan.md doesn't (user just initialized) | validation blocks for missing plan.md (rule 1)"

So the scenario is: user runs `new-plan`, which creates `state.json`, but the agent crashes before writing `plan.md`. When the user resumes, the hook should validate and block because `plan.md` is missing (rule 1).

**Recommendation**: Clarify test description:
- "Test 5: state.json exists with `next_phase: "plan-review"` but plan.md missing (crash before plan written) — validation blocks for missing plan.md (rule 1)"

---

## Non-Issues (Verification Passed)

### N1: TASK_FILE_LIST construction is correctly specified

The plan (lines 230-236) specifies the exact `grep | awk` pipeline for constructing `TASK_FILE_LIST`. Task 3.2 (line 41) correctly references this approach and includes a test to verify it (task 3.5, line 105).

✓ No issues found.

---

### N2: Block message templates are complete

All four review types (code, plan, tasks, all-code) have distinct block message templates specified in the plan (lines 243-261). Task 3.4 (line 90) confirms four distinct templates are required.

✓ No issues found.

---

### N3: Atomic state write pattern is consistently specified

The plan (lines 264-285) specifies the temp-file-then-mv pattern for atomic writes. This is referenced in multiple tasks:
- Task 3.1 (line 25): "write state atomically"
- Task 3.4 (line 82): "State written atomically (temp file + `mv`)"
- Task 4.3 (line 63): "Uses atomic write pattern (temp file + mv)"

✓ No issues found.

---

### N4: Test distribution strategy is followed

The plan (line 637) says:
> "Tests should be written alongside their corresponding feature implementation, not deferred to a separate test-only task."

Task 3.5 (lines 93-95) implements this as a verification subtask with incremental test commits:
> "Implementation approach: As you complete each implementation subtask, immediately write and commit the corresponding tests."

✓ No issues found.

---

## Summary

| Category | Count | Severity |
|----------|-------|----------|
| Critical | 3 | Must fix before implementation |
| Blocking | 2 | Must clarify/address before proceeding |
| Minor | 5 | Should fix for clarity |
| Non-Issues | 4 | Verified correct |

**Overall Assessment**: The task breakdown is generally sound and matches the plan structure well, but there are **3 critical issues** that must be fixed before implementation begins:

1. **C1**: Missing `make test-hooks` target requirement
2. **C2**: Timeout recovery mechanism not connected to crash recovery heuristic
3. **C3**: Plan.md completeness check uses unsafe OR logic

Additionally, **2 blocking issues** need clarification to avoid implementation ambiguity.

The **5 minor issues** are mostly documentation/clarity improvements and can be addressed during implementation, but should not be ignored.

---

## Recommendation

**Do NOT proceed with implementation** until the 3 critical issues and 2 blocking issues are addressed.

**Next steps**:
1. Fix critical issues C1, C2, C3
2. Clarify blocking issues B1, B2
3. Update task files with corrections
4. Run `/taskie:tasks-review` again to verify fixes
5. Only then proceed to `/taskie:next-task`
