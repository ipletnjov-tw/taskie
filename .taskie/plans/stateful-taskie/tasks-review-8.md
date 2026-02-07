# Tasks Review 8

## Overview

Performed a clean slate review of the task list (`tasks.md`) and all task files (`task-1.md` through `task-6.md`) against the plan (`plan.md`). This review is independent of all prior reviews and focuses on ensuring tasks EXACTLY match the plan requirements.

---

## Blocking Issues (Must Fix Before Implementation)

### B1: Task 3.2 TASK_FILE_LIST construction breaks on tasks with non-numeric IDs

**Location**: `task-3.md` line 41

**Issue**: The acceptance criteria specify constructing `TASK_FILE_LIST` using:
```bash
grep '^|' tasks.md | tail -n +3 | awk -F'|' '{gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9]+$/) printf ".taskie/plans/'${PLAN_ID}'/task-%s.md ", $2}'
```

This regex `$2 ~ /^[0-9]+$/` only matches purely numeric task IDs. But looking at the current `tasks.md`:

```
| Id | Status | Priority | Prerequisites | Description | Test strategy |
|----|--------|----------|---------------|-------------|---------------|
| 1  | pending| high     | None          | ...         | ...           |
```

The IDs in this plan ARE numeric (1-6), so this works. However, the plan itself doesn't mandate numeric-only task IDs. The acceptance criteria artificially restricts task IDs to numeric values when the broader system doesn't require this.

**Actually, this is intentional** - the plan (line 235) explicitly shows this numeric validation:
> "The `awk` command splits on `|`, extracts column 2 (the Id column), strips whitespace, validates it's numeric, and constructs the full file path."

So this is by design. Tasks MUST have numeric IDs for the stateful hook system to work.

**No fix required** - This is a design constraint, not a bug.

---

### B2: Task 5.2 missing critical detail about which task ID to implement

**Location**: `task-5.md` line 38

**Issue**: The acceptance criteria don't specify how `complete-task` and `complete-task-tdd` determine which task to implement. These actions need to:
1. Read `tasks.md` to find the next pending task
2. Set `current_task` in state.json to that task ID
3. Implement that specific task

The current acceptance criteria say "Implementation instructions are inlined" but don't clarify the task selection logic.

**Fix required**: Add to acceptance criteria:
```
- Action determines which task to implement by reading tasks.md and selecting the first task with status "pending"
- Sets current_task in state.json to the selected task ID before beginning implementation
- If no pending tasks exist, inform the user that all tasks are complete (don't proceed to implementation)
```

---

### B3: Task 4.2 git history fallback behavior unspecified

**Location**: `task-4.md` line 44

**Issue**: The acceptance criteria state:
> "Falls back to git history ONLY when `state.json` doesn't exist"

But it doesn't specify WHAT the fallback should do. The current `continue-plan.md` has complex git history analysis logic that:
- Checks for most recent plan directory
- Examines commit history
- Inspects task file completion status
- Routes based on what it finds

Should this logic be preserved unchanged, or rewritten?

**Fix required**: Add to acceptance criteria:
```
- Git history fallback preserves existing continue-plan.md logic unchanged (backwards compatibility with pre-stateful plans)
- Fallback only activates when state.json doesn't exist in the most recent plan directory
```

---

## Critical Issues (Must Fix)

### C1: Task 1.3 missing required make target

**Location**: `task-1.md` line 76

**Issue**: The acceptance criteria list `make test-state` and `make test-validation` targets but the plan explicitly requires `make test-hooks` as well.

Plan line 422 shows:
```
- `make test-hooks` runs all hook tests (all `test-*.sh` files in `tests/hooks/`)
```

This target is needed to run all hook tests together.

**Fix required**: Add to acceptance criteria:
```
- `make test-hooks` runs all test files in `tests/hooks/` (all `test-*.sh` files)
```

---

### C2: Task 3.2 timeout recovery mechanism not documented

**Location**: `task-3.md` lines 46-47

**Issue**: The acceptance criteria describe a timeout limitation:
> "If the hook times out after incrementing `phase_iteration` but before writing the review file, `state.json` will be left inconsistent."

This describes the problem but doesn't connect it to the solution. Task 4.2 implements crash recovery heuristics specifically to handle this case:
- Checks if `phase` is a post-review phase → just stop (post-review completed)
- Checks artifact completeness → determines if work was interrupted

**Fix required**: Add to acceptance criteria:
```
- Note: The crash recovery heuristic in task 4.2 (continue-plan.md) handles timeout-induced inconsistency by checking artifact completeness when resuming after a timeout
```

---

### C3: Task 4.2 plan.md completeness check uses unsafe logic

**Location**: `task-4.md` line 40

**Issue**: The acceptance criteria state:
> "Checks artifact completeness for plan-review (plan.md exists and has `## Overview` heading OR >50 lines — either condition suffices)"

This OR logic is dangerous. A file with 51 blank lines would pass the ">50 lines" check even though it's clearly incomplete. The check should verify the file exists FIRST, then check content.

**Fix required**: Change to:
```
- Checks artifact completeness for plan-review: plan.md must exist AND (contains `## Overview` heading OR has >50 lines)
```

---

## Minor Issues (Should Fix)

### M1: Task 1.1 function signatures not specified

**Location**: `task-1.md` lines 18-27

**Issue**: The acceptance criteria list 8 required functions but don't specify their signatures (parameters, return values). This could lead to inconsistent implementations across different developers.

**Recommendation**: Add brief signature documentation for each function with expected parameters and behavior.

---

### M2: Task 2.5 version bump reasoning too brief

**Location**: `task-2.md` line 90

**Issue**: States "MAJOR: 2.2.1 → 3.0.0" without explaining why it's a MAJOR bump.

**Recommendation**: Expand to:
```
- MAJOR bump (2.2.1 → 3.0.0) because: replaces validate-ground-rules.sh hook with stop-hook.sh, changes hook behavior (adds auto-review blocking), increases timeout from 5s to 600s, and introduces breaking workflow changes
```

---

### M3: Task 5.1 phase_iteration should be null in standalone mode

**Location**: `task-5.md` line 26

**Issue**: The acceptance criteria state:
> "All other fields (`max_reviews`, `phase_iteration`, `review_model`, `consecutive_clean`, `tdd`) preserved from existing state via read-modify-write"

But `next-task` and `next-task-tdd` are standalone commands that exit the review loop. Per the plan schema (line 49):
> "`phase_iteration` | number\|null | ... Null during non-review phases."

When entering standalone mode (setting `next_phase: null`), we're exiting the review cycle, so `phase_iteration` should be set to `null`, not preserved.

**Fix required**: Change to:
```
- All other fields preserved EXCEPT phase_iteration which is set to null (standalone mode, not in review cycle)
```

---

### M4: Task 6.3 test 5 description confusing

**Location**: `task-6.md` line 52

**Issue**: Test 5 description states:
> "concurrent plan creation (state.json exists but plan.md doesn't) uses `next_phase: null` in state to ensure validation runs (not auto-review)"

This is confusing. Looking at plan line 615:
> "Concurrent plan creation | state.json exists but plan.md doesn't (user just initialized) | validation blocks for missing plan.md (rule 1)"

The scenario is: agent runs `new-plan`, creates `state.json` with `next_phase: "plan-review"`, then crashes before writing `plan.md`. When resuming, the hook should fall through to validation and block.

But the test description says "uses `next_phase: null`" which contradicts the scenario.

**Fix required**: Clarify test description:
```
- Test 5: state.json exists with next_phase: "plan-review" but plan.md missing (crash during new-plan) — hook attempts review, finds no plan.md to review, falls through to validation which blocks for missing plan.md (rule 1)
```

---

### M5: Task 3.5 is a verification subtask but could be misread as deferred testing

**Location**: `task-3.md` lines 93-100

**Issue**: The subtask description says "This is a tracking/verification subtask" and states "Tests should be written and committed alongside each implementation subtask". However, the phrasing could be misread as "write all tests in this subtask after implementation is done."

The acceptance criteria clarify the intent, but the description could be clearer.

**Recommendation**: Rephrase the short description to:
```
- Short description: Verification checkpoint — ensures all tests for suites 2-5 have been written incrementally during subtasks 3.1-3.4 and all pass. This is NOT a separate test-writing phase; tests must be committed with their corresponding implementation subtasks.
```

---

## Non-Issues (Verified Correct)

### N1: Mock claude output format is correctly specified

Task 1.2 acceptance criteria (lines 45-54) correctly specify:
- Returns structured JSON on stdout with `result`, `session_id`, `cost`, `usage` fields
- Verdict in `result.verdict` as `"PASS"` or `"FAIL"`
- Review markdown files do NOT contain VERDICT lines
- Hook extracts via `jq -r '.result.verdict'`

This matches the plan's specification (lines 227-228) for `--output-format json` with `--json-schema`.

✓ No issues found.

---

### N2: Two consecutive clean reviews requirement is correctly implemented

The plan (line 112) states:
> "**Two consecutive clean reviews**: The last two review iterations must BOTH pass (find no issues) before the agent advances to the next phase."

Task 3.3 (line 62) correctly implements this:
> "`consecutive_clean >= 2` → auto-advance with correct advance target"

And task 3.4 tracks the counter correctly, resetting to 0 on any review with issues.

✓ No issues found.

---

### N3: Remaining tasks check correctly handles numeric comparison

Task 3.3 (line 70) shows:
```bash
grep '^|' tasks.md | tail -n +3 | awk -F'|' -v cur="${CURRENT_TASK}" '{gsub(/[[:space:]]/, "", $2); if ($2 != cur) print $3}' | grep -i 'pending' | wc -l
```

The comment explains this "avoids partial matches that would incorrectly exclude task 10/11/12 when current is task 1".

Using `$2 != cur` (string inequality after stripping whitespace) correctly performs exact matching:
- "1" != "10" → true (include task 10)
- "1" != "1" → false (exclude current task 1)
- "10" != "1" → true (include task 1 when current is 10)

✓ No issues found.

---

### N4: Atomic state write pattern consistently specified

Multiple tasks reference the atomic write pattern:
- Task 3.1 (line 25): "write state atomically"
- Task 3.4 (line 82): "State written atomically (temp file + `mv`)"
- Task 4.3 (line 63): "Uses atomic write pattern (temp file + mv)"
- Task 5.2 (line 44): "Read entire `state.json` before modifying (read-modify-write pattern)"

This matches the plan's specification (lines 264-285) for preventing corruption via temp-file-then-mv.

✓ No issues found.

---

### N5: All-code-review advance target is correctly specified

Task 3.3 (line 67) states:
> "all-code-review → `complete` (letting `continue-plan` handle final phase transition to `phase: "complete"`, `next_phase: null`)"

This is correct. The hook sets `next_phase: "complete"` when two clean all-code-reviews pass, then `continue-plan` (task 4.2, line 37) handles this by setting `phase: "complete"`, `next_phase: null`.

Plan line 327 confirms:
> "`next_phase` = `"complete"` → set `phase: "complete"`, `next_phase: null`, inform user all tasks are done"

✓ No issues found.

---

## Summary

| Category | Count | Severity |
|----------|-------|----------|
| Blocking | 3 | Must clarify before implementation |
| Critical | 3 | Must fix before implementation |
| Minor | 5 | Should fix for clarity |
| Non-Issues | 5 | Verified correct |

**Overall Assessment**: The task breakdown is solid and matches the plan well. However, there are **3 blocking issues** and **3 critical issues** that need to be addressed before implementation can begin.

The blocking issues (B2, B3) involve missing specifications that could lead to implementation ambiguity. The critical issues are documentation gaps that would cause confusion during implementation.

The 5 minor issues are mostly documentation improvements and can be addressed during implementation without blocking progress.

---

## Recommendation

**Address the 3 blocking and 3 critical issues before proceeding to implementation:**

**Blocking (need clarification):**
- B2: Specify how complete-task selects which task to implement
- B3: Specify git history fallback behavior

**Critical (must fix):**
- C1: Add missing `make test-hooks` target
- C2: Connect timeout limitation to crash recovery solution
- C3: Fix unsafe plan.md completeness check logic

After fixing these 6 issues, the minor issues can be addressed during implementation as improvements.

**Verdict**: FAIL

**Next steps:**
1. Fix issues B2, B3, C1, C2, C3
2. Consider addressing minor issues M1-M5 for improved clarity
3. Run `/taskie:tasks-review` again to verify all fixes
4. Proceed to `/taskie:next-task` once review passes
