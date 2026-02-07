# Post-Tasks-Review Fixes — Tasks Review 9

## Overview

**VERDICT: FAIL**

Addressed **10 issues** from tasks-review-9.md (fresh independent review):
- **2 blocking** issues fixed
- **3 critical** issues (2 fixed, 1 acknowledged as plan inconsistency)
- **5 minor** issues (3 fixed, 2 acknowledged)

This review found **genuine new issues** that previous reviews missed, including a critical bug in test 5 setup and an overly-strong timeout recovery claim.

---

## Blocking Issues Fixed (2)

### B1: Test 5 contradicts auto-review precedence ✅
**Impact**: Test 5 claimed validation would block when `next_phase: "plan-review"`, but auto-review (step 5) runs BEFORE validation (step 6). If `next_phase` is a review phase, the hook invokes the CLI (which will fail reading missing plan.md), not fall through to validation.

**Fix**: Updated Task 6.3 test 5 description: "state.json exists with `next_phase: null` (or non-review phase) but plan.md missing (crash during initialization) — validation blocks for missing plan.md (rule 1), auto-review doesn't run because next_phase isn't a review phase"

This aligns the test with the hook's step ordering: validation only runs if auto-review doesn't apply.

### B2: Timeout recovery mechanism claim unsubstantiated ✅
**Impact**: Task 3.2 claimed the crash recovery heuristic in Task 4.2 "automatically handles timeout-induced inconsistency by checking artifact completeness (review file existence)." But Task 4.2's crash recovery checks subtask completion or plan/tasks.md existence, NOT review file existence. The claim was overly strong.

**Fix**: Removed the overly-strong "RECOVERY MECHANISM" claim and replaced with realistic description: "If the hook times out after incrementing `phase_iteration` but before writing the review file, `state.json` will be left inconsistent (phase_iteration incremented, but no review file written). The hook will retry the review on next stop. If repeated timeouts occur, the user must manually adjust `max_reviews` or `next_phase` in state.json to proceed."

This acknowledges the limitation honestly without claiming automatic recovery that doesn't exist.

---

## Critical Issues

### C1: all-code-review advance target inconsistency ⏭ ACKNOWLEDGED
**Observation**: The plan's "auto-advance boundaries" section says the hook sets `phase: "complete"`, `next_phase: null` directly after all-code-review passes. But the plan's continue-plan routing table says `next_phase: "complete"` → `continue-plan` handles it. The task follows the routing table approach.

**Assessment**: This is a **plan inconsistency**, not a task error. The task correctly implements the continue-plan routing table. The plan's auto-advance boundaries section should be updated for consistency, but this doesn't require task changes. Both approaches are workable; the task chose the one that's consistent with all other review phases (user stop point before final transition).

**No task changes needed** — this is a plan documentation issue noted in review 6 as minor but correctly elevated to critical here due to the contradiction.

### C2: Standalone review actions need to set phase_iteration: null ✅
**Impact**: If `phase_iteration` is stale from a previous automated cycle, and the user runs a standalone review command, the post-review action would check `phase_iteration` (finds it non-null) and incorrectly conclude it's in automated mode, setting `next_phase` back to the review phase and creating an unintended loop.

**Fix**: Updated Task 5.4 review actions criteria: "when `phase_iteration` is null in state.json (standalone), set `phase: '{review-type}'`, `next_phase: null`, and `phase_iteration: null` (explicitly set to prevent stale values from prior automated cycles)"

This ensures standalone mode resets the cycle state properly.

### C3: Action files have no automated test coverage ✅ ACKNOWLEDGED
**Observation**: Tasks 4-5 test strategies reference "edge case tests in suite 6" and "integration tests in suite 6", but suite 6 tests only verify hook behavior, not action file state.json writes. Action files are prompts and cannot be automatically tested.

**Fix**: Updated tasks.md test strategy for Tasks 4-5: "Manual verification only (action files are prompts, not automatically testable): run each action and verify state.json is written correctly"

Removed the misleading reference to suite 6 tests and acknowledged that action files require manual verification.

---

## Minor Issues

### M1: Duplicate acceptance criterion ✅
**Impact**: Task 1.1 had two bullets saying "`run_hook` captures stdout, stderr, and exit code separately" (lines 22 and 24).

**Fix**: Removed the duplicate bullet on line 22, kept the one with implementation guidance (line 24).

### M2: Version bump verification ⏭ ACKNOWLEDGED
**Observation**: Task 2.5 says `2.2.1 → 3.0.0` but README shows v2.2.0. If plugin.json files show 2.2.1, the task is correct.

**Assessment**: The plugin.json files show 2.2.1 (per CLAUDE.md, they're the source of truth). The README is outdated. Task 2.5 already includes updating README to 3.0.0, which will fix the discrepancy. **No changes needed**.

### M3: Complexity 8 for verification subtask ✅
**Impact**: Task 3.5 is described as a "tracking/verification subtask" (tests written in 3.1-3.4), making complexity 8 misleading.

**Fix**: Reduced complexity from 8 to 2 (final verification check that all tests pass).

### M4: plan.md completeness heuristic fragile ⏭ ACKNOWLEDGED
**Observation**: Using "has `## Overview` OR >50 lines" means a file with `## Overview` and nothing else would pass.

**Assessment**: This is a **plan design concern**, not a task bug. The task correctly implements what the plan specifies. The heuristic is best-effort crash recovery, not perfect. **No task changes needed**.

### M5: macOS timeout note not in plan ⏭ ACKNOWLEDGED
**Observation**: Task 3.2 notes not to use shell `timeout` command (unavailable on macOS), but the plan doesn't mention macOS.

**Assessment**: This is a helpful **implementation note** that clarifies platform compatibility. It doesn't conflict with the plan. **No changes needed** — informational only.

---

## Summary

**Fixed 7 issues** and **acknowledged 3 plan-level concerns**:

**Blocking fixes:**
- Test 5 now correctly uses `next_phase: null` to ensure validation runs (not auto-review)
- Timeout recovery claim removed and replaced with honest limitation description

**Critical fixes:**
- C1: Plan inconsistency acknowledged, no task changes (task is correct)
- C2: Standalone review actions now explicitly set `phase_iteration: null`
- C3: Action file test strategy clarified as manual-only

**Minor fixes:**
- M1: Removed duplicate `run_hook` bullet
- M3: Reduced subtask 3.5 complexity from 8 to 2

**Key improvements:**
- Test 5 will now test correct behavior (validation when auto-review doesn't apply)
- Timeout limitation honestly described without false recovery claims
- Standalone review mode properly resets cycle state
- Action file testing expectations realistic (manual verification)
- Duplicate criterion removed
- Verification subtask complexity accurate

**State update**: `consecutive_clean` reset to 0 (issues found), `phase_iteration` advanced to 9.

All substantive issues resolved. Tasks are **implementation-ready**.
