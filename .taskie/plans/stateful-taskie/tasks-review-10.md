# Tasks Review 10

**Reviewer**: Fresh review — no prior reviews consulted.
**Scope**: tasks.md table + all 6 task files vs. plan.md

---

## Blocking Issues

### B1: Task 6 test 5 contradicts the hook's step ordering — auto-review (step 5) runs BEFORE validation (step 6)

**File**: task-6.md, Subtask 6.3, acceptance criterion for test 5
**Task says**: "Test 5: state.json exists with `next_phase: "plan-review"` but plan.md missing (crash before plan written) — validation blocks for missing plan.md (rule 1), not auto-review"

**Plan says** (Hook Logic, step 5 vs step 6): Step 5 handles all cases where `next_phase` is a review phase (`plan-review`, `tasks-review`, `code-review`, `all-code-review`). Step 6 (validation) only runs when step 5 does NOT apply — i.e. when `next_phase` is NOT a review phase, or when `next_phase` is null, or `state.json` is missing/malformed.

**Plan also says** (Test Suite 6, test 6): "Auto-review takes precedence over validation ... hook runs review and blocks for post-review (validation is NOT reached — it only runs when the hook falls through to step 6)."

If `next_phase` is `"plan-review"` (a review phase) and `max_reviews > 0`, the hook enters step 5, increments `phase_iteration`, and invokes the `claude` CLI for plan-review. Validation (step 6) is never reached. The CLI will attempt to read `plan.md` (which doesn't exist), perform a review (likely FAIL verdict since there's nothing to review), write a review file, and the hook will block for post-review.

The test as described expects validation to block — but validation won't run because auto-review handles it first. The plan's own test 6 explicitly confirms auto-review takes precedence.

**Fix**: Change the test setup so `next_phase` is NOT a review phase (e.g. `next_phase: null` or `next_phase: "create-tasks"`) to ensure the hook falls through to step 6 where validation runs. Alternatively, remove `next_phase: "plan-review"` from the scenario and describe the test as: "state.json exists with `next_phase: null` (or no next_phase set), plan.md missing → validation blocks for missing plan.md."

### B2: Task 3 subtask 3.2 claims a "RECOVERY MECHANISM" in Task 4.2 that doesn't exist in Task 4.2

**File**: task-3.md, Subtask 3.2, last acceptance criterion
**File**: task-4.md, Subtask 4.2

Task 3.2 says: "RECOVERY MECHANISM: The crash recovery heuristic in Task 4.2 (`continue-plan.md`) automatically handles this timeout-induced inconsistency by checking artifact completeness (review file existence) when resuming with `next_phase` set to a review phase."

But Task 4.2's crash recovery heuristic checks:
1. `phase` for post-review values → just stop
2. Subtask completion in task files (for code-review/all-code-review)
3. `plan.md` existence and completeness (for plan-review)
4. `tasks.md` table rows existence (for tasks-review)

None of these check **review file existence**. The timeout scenario in 3.2 is: hook times out after incrementing `phase_iteration` but before writing the review file. State would show e.g. `phase_iteration: 3`, `next_phase: "code-review"`. When `continue-plan` resumes, it would see `next_phase: "code-review"`, check if `phase` is a post-review value (it won't be — it was set to something like `"code-review"` by the hook before timeout), then check subtask completion. Subtask completion is irrelevant to whether a review file was written.

**Fix**: Either (a) add review file existence checking to Task 4.2's crash recovery heuristic for the case where `next_phase` is a review phase and `phase_iteration > 0` — check if `*-review-{phase_iteration}.md` exists, and if not, decrement `phase_iteration` in state.json before stopping to let the hook retry; or (b) remove the "RECOVERY MECHANISM" claim from Task 3.2 and document this as a known limitation where the user must manually fix `state.json` (e.g. decrement `phase_iteration`).

---

## Critical Issues

### C1: Plan's "auto-advance boundaries" for all-code-review contradicts both the task and the plan's own continue-plan routing table

**File**: task-3.md, Subtask 3.3
**File**: plan.md, "Auto-advance boundaries" section vs "continue-plan" routing table

Plan's auto-advance boundaries section says: "After all-code-review passes (2 clean) → set `phase: "complete"`, `next_phase: null`, agent stops."

Plan's continue-plan routing table says: "`next_phase` = `"complete"` → set `phase: "complete"`, `next_phase: null`, inform user all tasks are done"

Task 3.3 says: `all-code-review → "complete" (letting continue-plan handle final phase transition to phase: "complete", next_phase: null)`

The auto-advance boundaries section says the **hook** sets `phase: "complete"`, `next_phase: null` directly. But the continue-plan routing table documents a `next_phase: "complete"` route, and the task implements it as setting `next_phase: "complete"` (delegating to `continue-plan`).

These are two different behaviors. The task chose the delegation approach, which is consistent with how all other auto-advance boundaries work (plan-review → user stop with `next_phase: "create-tasks"`, code-review → user stop with `next_phase: "complete-task"`). But the plan's auto-advance boundaries section explicitly says the hook does it directly.

**Impact**: The plan is internally inconsistent. The task's approach (delegate to `continue-plan`) is more consistent with the overall pattern and is functional, but it contradicts one section of the plan.

**Fix**: Update the plan's "auto-advance boundaries" section to say: "After all-code-review passes (2 clean) → **user stop**. The hook sets `next_phase: "complete"` and approves the stop. The user runs `continue-plan`, which sets `phase: "complete"`, `next_phase: null` and informs the user all tasks are done." This aligns with the task and the continue-plan routing table.

### C2: Standalone review actions in Task 5.4 don't reset `phase_iteration` to null — risks stale automated mode detection

**File**: task-5.md, Subtask 5.4
**Plan**: Section 7 (`post-code-review.md`): "The determination of standalone vs. automated is based on whether `phase_iteration` is non-null in `state.json`."

The acceptance criteria say: "Review actions (4 files): when `phase_iteration` is null in state.json (standalone), set `phase: "{review-type}"` and `next_phase: null`. When `phase_iteration` is non-null (hook-invoked), don't update state.json (hook manages it)"

But what if `phase_iteration` is non-null because it was set by a PREVIOUS automated cycle, and the user now invokes a standalone review command? For example:
1. User runs `/taskie:complete-task` → sets `phase_iteration: 0`
2. Hook runs review → sets `phase_iteration: 1`
3. User breaks out by setting `next_phase: null` in state.json
4. User manually runs `/taskie:code-review` (standalone)
5. The action sees `phase_iteration: 1` (non-null) → thinks it's hook-invoked → doesn't update state
6. Later, `/taskie:post-code-review` sees `phase_iteration: 1` (non-null) → thinks it's automated → sets `next_phase: "code-review"` → creates an unintended review loop

The standalone review action must explicitly set `phase_iteration: null` to prevent stale values from prior automated cycles from causing the post-review action to incorrectly detect automated mode.

**Fix**: Add to Subtask 5.4 acceptance criteria: "Standalone review actions (when invoked directly by user, detected by checking if `next_phase` is null) must set `phase_iteration: null` to clear any stale values from prior automated cycles."

---

## Minor Issues

### M1: Task 1 subtask 1.1 has a duplicate acceptance criterion for `run_hook`

**File**: task-1.md, Subtask 1.1
Two bullets say the same thing:
- "`run_hook` pipes JSON to the hook, captures stdout, stderr, and exit code separately"
- "`run_hook` captures stdout, stderr, and exit code separately (use temp files or capture variables)"

**Fix**: Remove the second duplicate bullet.

### M2: Task 3 subtask 3.5 has complexity 8 but is a "tracking/verification subtask"

**File**: task-3.md, Subtask 3.5
The description says: "This is a tracking/verification subtask to ensure all tests for suites 2-5 are present and passing after subtasks 3.1-3.4 complete" and "Tests should be written and committed alongside each implementation subtask (3.1-3.4), NOT deferred to a separate phase."

If all 51 tests are written in subtasks 3.1-3.4, then 3.5 is just a final `make test` run — complexity 1 or 2, not 8.

**Fix**: Reduce complexity to 2 or clarify that 3.5 writes tests not already covered by 3.1-3.4.

### M3: Task 2 subtask 2.5 references version "2.2.1 → 3.0.0" but README says "v2.2.0"

**File**: task-2.md, Subtask 2.5
The task says: "MAJOR: 2.2.1 → 3.0.0". README.md says: "Latest version: **v2.2.0**".

The "from" version may be stale. The target (3.0.0) is correct regardless since this is a breaking change.

**Fix**: Verify current version in both JSON files at implementation time and ensure the "from" version in the task matches.

### M4: Task 4.2 plan.md completeness heuristic is fragile

**File**: task-4.md, Subtask 4.2
The acceptance criteria say: "Check artifact completeness for plan-review (plan.md exists AND (has `## Overview` heading OR >50 lines))"

A plan.md with just `## Overview` on line 1 would pass as "complete". This is a plan design issue (the plan specifies this heuristic), not a task deviation — the task correctly implements what the plan says.

No task fix needed — flagging for awareness only.

---

## Verification Checklist: Plan Coverage

Verifying that every requirement in plan.md is covered by at least one task:

| Plan section | Covered by task(s) | Status |
|---|---|---|
| State file schema (8 fields) | Task 4.1 (init), Task 4.3 (create-tasks), Task 5.1-5.5 (all others) | OK |
| Hook input/output protocol | Task 2.1 | OK |
| Hook logic steps 1-4 | Task 2.1, 2.2 | OK |
| Hook logic step 5 (auto-review) | Task 3.1-3.4 | OK |
| Hook logic step 6 (validation) | Task 2.2 | OK |
| Claude CLI invocation | Task 3.2 | OK |
| Block message templates | Task 3.4 | OK |
| Atomic state updates | Task 3.4 (hook), Tasks 4-5 (actions mention read-modify-write) | OK |
| Hook timeout (600s) | Task 2.5 | OK |
| Automation boundary rule | Task 5.1 (standalone), Task 5.2 (auto-trigger) | OK |
| Action: continue-plan.md | Task 4.2 | OK |
| Action: new-plan.md | Task 4.1 | OK |
| Action: create-tasks.md | Task 4.3 | OK |
| Action: next-task.md / next-task-tdd.md | Task 5.1 | OK |
| Action: complete-task.md / complete-task-tdd.md | Task 5.2 | OK |
| Action: continue-task.md | Task 5.3 | OK |
| Action: review/post-review actions (8 files) | Task 5.4 | OK |
| Action: add-task.md | Task 5.5 | OK |
| Ground rules changes | Task 6.1 | OK |
| Codex CLI updates | Task 6.2 | OK |
| Validation hook updates | Task 2.2, 2.4 | OK |
| Test suites 1-5 | Task 2.3-2.4, Task 3.5 | OK |
| Test suite 6 | Task 6.3 | OK |
| Test infrastructure | Task 1 | OK |

All plan sections are covered.

---

## Summary

| Severity | Count | IDs |
|----------|-------|-----|
| Blocking | 2 | B1, B2 |
| Critical | 2 | C1, C2 |
| Minor | 4 | M1, M2, M3, M4 |

**Verdict**: FAIL

Two blocking issues must be resolved: B1 (test 5 in suite 6 will test wrong behavior due to auto-review taking precedence over validation), B2 (claimed recovery mechanism in Task 3.2 is not implemented in Task 4.2). Two critical issues need attention: C1 (plan internal inconsistency on all-code-review completion — task is functional but plan section needs alignment), C2 (standalone review actions need to reset `phase_iteration` to null to prevent stale automated mode detection).
