# Tasks Review 9

**Reviewer**: Fresh review — no prior reviews consulted.
**Scope**: tasks.md table + all 6 task files vs. plan.md

---

## Blocking Issues

### B1: Task 6 test 5 acceptance criteria contradicts plan — validation should NOT block during auto-review

**File**: task-6.md, Subtask 6.3 acceptance criteria, test 5
**Quote from task-6.md**: "Test 5: state.json exists with `next_phase: "plan-review"` but plan.md missing (crash before plan written) — validation blocks for missing plan.md (rule 1), not auto-review"
**Quote from plan.md (step 5 vs step 6)**: Step 5 (auto-review) runs BEFORE step 6 (validation). The plan's edge case test 6 (suite 6) explicitly states: *"Auto-review takes precedence over validation — hook runs review and blocks for post-review (validation is NOT reached)"*.

If `next_phase: "plan-review"` and `max_reviews > 0`, the hook will enter step 5 and invoke the `claude` CLI for plan-review. It will NOT fall through to validation. The plan's own edge case test 6 confirms this. Test 5 in the task's acceptance criteria contradicts this by saying "validation blocks" — but validation is in step 6 and is never reached when step 5 handles the review.

The plan's test suite 6 test 5 description says: *"Concurrent plan creation: state.json exists but plan.md doesn't (user just initialized) → validation blocks for missing plan.md (rule 1)"*. This appears to describe a scenario where `next_phase` is NOT a review phase (perhaps the user manually set up state.json with a non-review `next_phase`), but the task's acceptance criteria description says `next_phase: "plan-review"`, which IS a review phase and WOULD be handled by step 5.

**Impact**: The test as described in the task will either test the wrong behavior or fail. The state setup in the test must have `next_phase` set to a NON-review value (e.g. `null` or `"create-tasks"`) for validation to be reached, OR the plan's test 5 description needs to be reconciled with its own step 5/6 ordering.

**Fix**: Align the test state setup with the plan's step ordering. Either: (a) set `next_phase` to a non-review value like `"create-tasks"` so the hook falls through to validation, or (b) accept that when `next_phase: "plan-review"`, the CLI will be invoked and the review will happen even without plan.md (the CLI prompt will fail to read plan.md, the review will likely be a FAIL verdict, and the hook will block for post-review — which is the correct behavior per step 5).

### B2: Task 3 subtask 3.2 introduces recovery mechanism that belongs in task 4.2 but task 4.2 doesn't mention it

**File**: task-3.md, Subtask 3.2 acceptance criteria, last bullet about "KNOWN LIMITATION" and "RECOVERY MECHANISM"
**File**: task-4.md, Subtask 4.2 acceptance criteria

Subtask 3.2 states: *"RECOVERY MECHANISM: The crash recovery heuristic in Task 4.2 (continue-plan.md) automatically handles this timeout-induced inconsistency by checking artifact completeness (review file existence) when resuming with next_phase set to a review phase."*

However, task 4.2's acceptance criteria for the two-level crash recovery heuristic says:
- Check `phase` for post-review → just stop
- Check artifact completeness for code-review/all-code-review (reads task file, verifies all subtask status markers are complete)

The recovery described in 3.2 is about a **missing review file** when `next_phase` is a review phase (the hook timed out after incrementing `phase_iteration` but before writing the review file). Task 4.2's heuristic checks subtask completion status, NOT review file existence. The two are different — subtask completion tells you if implementation finished, but doesn't tell you if a review file was written.

**Impact**: The timeout recovery claim in 3.2 is unsubstantiated — task 4.2 doesn't actually implement review file existence checking. If the hook times out mid-review, `continue-plan` would see `next_phase: "code-review"`, check if `phase` is a post-review value (it's not — it was just incremented to something else), then check artifact completeness (subtask completion — irrelevant to the timeout scenario). The result is ambiguous.

**Fix**: Either (a) add review file existence checking to task 4.2's crash recovery heuristic (e.g. "when `next_phase` is a review phase and `phase_iteration > 0`, verify that review file `*-review-{phase_iteration}.md` exists; if missing, decrement `phase_iteration` and stop to let the hook retry"), or (b) remove the "RECOVERY MECHANISM" claim from 3.2 and acknowledge the timeout as a known limitation with no automatic recovery (user must manually fix state.json).

---

## Critical Issues

### C1: Task 3 subtask 3.3 — `all-code-review` advance target is `"complete"` but plan says the agent should set `phase: "complete"`, `next_phase: null`

**File**: task-3.md, Subtask 3.3 acceptance criteria
**Quote from task**: `all-code-review → "complete" (letting continue-plan handle final phase transition to phase: "complete", next_phase: null)`
**Quote from plan, auto-advance boundaries**: *"After all-code-review passes (2 clean) → set phase: 'complete', next_phase: null, agent stops."*

The plan says the hook itself should set `phase: "complete"` and `next_phase: null` when all-code-review passes with 2 clean reviews. But the task says set `next_phase: "complete"` and let `continue-plan` handle it. These are different — if the hook sets `next_phase: "complete"`, the agent will stop, and when the user runs `continue-plan`, it will see `next_phase: "complete"` and then set `phase: "complete"`, `next_phase: null`. This adds an unnecessary extra step (user must run `continue-plan` again after all reviews pass) vs the plan's intent which is that the hook sets the final state directly.

However, looking more carefully at the plan's `continue-plan` routing table: *"`next_phase` = 'complete' → set phase: 'complete', next_phase: null, inform user all tasks are done"*. This confirms the task's approach IS documented in the plan — `continue-plan` handles the `"complete"` next_phase. But this contradicts the "auto-advance boundaries" section which says the hook does it directly.

**Impact**: Inconsistency within the plan itself. The task chose one interpretation (delegate to `continue-plan`), which is workable but adds an extra user step. Both the plan's auto-advance boundaries section AND the task should be consistent.

**Fix**: Choose one approach and ensure plan + task agree. The task's approach (delegate to `continue-plan`) is arguably better because it's consistent with how plan-review, tasks-review, and code-review auto-advance all use "user stop" points. Just ensure the plan's auto-advance boundaries section is updated to say `next_phase: "complete"` instead of `phase: "complete"`, `next_phase: null`.

### C2: Task 5 subtask 5.4 — review actions "don't update state.json when hook-invoked" but plan says standalone review actions DO update state.json

**File**: task-5.md, Subtask 5.4 acceptance criteria
**Quote**: "When `phase_iteration` is non-null (hook-invoked), don't update state.json (hook manages it)"

This is correct for hook-invoked reviews. But the plan section 6 (`code-review.md`) says: *"When invoked standalone, writes review and sets next_phase: null."*

The acceptance criteria correctly distinguishes these two modes. However, the acceptance criteria says "When `phase_iteration` is null in state.json (standalone), set `phase: '{review-type}'` and `next_phase: null`." But standalone review actions also need to set `phase_iteration: null` explicitly in case it was previously non-null (e.g. user ran `complete-task`, then the review loop was interrupted, and now the user manually runs `/taskie:code-review`). If `phase_iteration` is still set from the previous automated cycle, the post-review action would incorrectly detect it as "automated mode" and set `next_phase` back to the review phase.

**Impact**: Stale `phase_iteration` from a prior automated cycle could cause standalone review commands to behave as if they're in automated mode, creating an unintended review loop.

**Fix**: Add to acceptance criteria: "Standalone review actions must set `phase_iteration: null` to prevent stale values from triggering automated behavior in subsequent post-review actions."

### C3: tasks.md table is missing a "Test strategy" column value for Tasks 4 and 5

**File**: tasks.md, rows for tasks 4 and 5
**Quote**: Task 4: "Manual verification: run each action and verify state.json is written correctly; edge case tests in suite 6"
**Quote**: Task 5: "Manual verification: run each action and verify state.json transitions; integration tests in suite 6"

These ARE present in the table. However, the test strategies reference "edge case tests in suite 6" and "integration tests in suite 6" — but the actual test suite 6 (in task-6.md subtask 6.3) tests are focused on the **hook's** edge cases (multiple plan dirs, max_reviews=0, model alternation, etc.), not on **action file** behavior.

None of the 12 tests in suite 6 actually verify that action files write correct state.json values. The tests only verify hook behavior. Action file changes (Tasks 4-5) have zero automated test coverage.

**Impact**: There is no automated verification that action files instruct agents to write correct state.json. If an action file has a typo in its state.json instructions (e.g. wrong field name, missing field), it will never be caught by tests.

**Fix**: Either (a) acknowledge this explicitly in the task files ("action file changes are prompt-only and cannot be automatically tested — rely on manual verification"), or (b) add integration tests that simulate the full workflow (action writes state → hook reads state → correct behavior). Option (b) is likely too complex for this scope.

---

## Minor Issues

### M1: Task 1 subtask 1.1 — duplicate acceptance criterion

**File**: task-1.md, Subtask 1.1 acceptance criteria
Two bullets say essentially the same thing:
- "`run_hook` pipes JSON to the hook, captures stdout, stderr, and exit code separately"
- "`run_hook` captures stdout, stderr, and exit code separately (use temp files or capture variables)"

**Fix**: Remove the duplicate bullet.

### M2: Task 2 subtask 2.5 — version bump is listed as 2.2.1 → 3.0.0 but this should be confirmed against current version

**File**: task-2.md, Subtask 2.5 acceptance criteria
The task says the version is currently `2.2.1` and should bump to `3.0.0`. The README says "Latest version: **v2.2.0**". If the current version in the JSON files is actually `2.2.1` (post-README update), then the bump to `3.0.0` is correct per SemVer (breaking change). But if the README is authoritative and the version is `2.2.0`, the bump target is the same (still `3.0.0`), just the "from" version is wrong in the task description.

**Fix**: Verify current version in both JSON files and ensure the task's "from" version matches reality. The target `3.0.0` is correct regardless.

### M3: Task 3 subtask 3.5 — complexity rating of 8 is misleading for a "tracking/verification" subtask

**File**: task-3.md, Subtask 3.5
The description says this is a "tracking/verification subtask" and tests should be written "alongside each implementation subtask (3.1-3.4)". If tests are actually written in 3.1-3.4, then 3.5 is just a final `make test` run — complexity 1-2, not 8.

**Fix**: Reduce complexity to 2 (final verification check) or clarify that 3.5 actually does write some tests not covered by 3.1-3.4.

### M4: Task 4 subtask 4.2 — plan.md completeness check uses ">50 lines" as a heuristic, but plan says `## Overview` heading OR >50 lines

**File**: task-4.md, Subtask 4.2 acceptance criteria
The acceptance criteria correctly states: "has `## Overview` heading OR >50 lines". This is fine — but the heuristic is fragile. A plan.md could have `## Overview` on line 1 with nothing else and be considered "complete".

This is a plan design concern, not a task bug, so flagging as minor. No fix needed in the task — the task correctly implements what the plan specifies.

### M5: Task 3 subtask 3.2 — "do NOT use the shell `timeout` command (not available on macOS)" but the plan doesn't mention macOS

**File**: task-3.md, Subtask 3.2 acceptance criteria
The plan discusses timeout handling in the "Hook Timeout" section and says the hook timeout is set to 600 seconds. The task adds a note about not using the shell `timeout` command because it's unavailable on macOS. While this is a good practical note, it's not in the plan, and the plan already handles this by relying on Claude Code's 600s hook timeout mechanism. The task note is informational only and doesn't conflict with the plan.

No fix needed — this is a helpful implementation note.

---

## Summary

| Severity | Count | IDs |
|----------|-------|-----|
| Blocking | 2 | B1, B2 |
| Critical | 3 | C1, C2, C3 |
| Minor | 5 | M1, M2, M3, M4, M5 |

**Verdict**: FAIL

The blocking issues must be resolved before implementation can proceed safely. B1 describes a test that will test the wrong behavior due to a contradiction between the hook's step ordering and the test's expected outcome. B2 describes a claimed recovery mechanism that isn't actually implemented by the referenced task. The critical issues (C1, C2, C3) represent inconsistencies and gaps that could lead to incorrect behavior in edge cases.
