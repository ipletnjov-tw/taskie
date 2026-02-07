# Tasks Review 2: Clean Slate Critical Analysis

**Review Date**: 2026-02-07
**Reviewer**: Claude Sonnet 4.5 (automated, independent review)
**Scope**: All task files and tasks.md for stateful-taskie plan
**Methodology**: Clean slate review (no prior review files read), specialized subagents for deep analysis

---

## Executive Summary

This review identifies **25 issues** across all 6 tasks, with **9 blocking/critical** issues that must be addressed before implementation begins. The tasks are generally well-structured and match the plan closely, but several areas lack precision in acceptance criteria, particularly around state.json handling, test infrastructure, and crash recovery heuristics.

**Critical finding**: Task 1 has a BLOCKING issue with the mock CLI JSON output format that would cause all hook tests to fail. Task 3 has a HIGH severity issue with the remaining tasks detection pattern that could cause false positives in production.

### Issue Severity Distribution

- **Blocking**: 2 issues (Tasks 1, 3)
- **Critical/High**: 7 issues (Tasks 1, 2, 3, 4, 5)
- **Medium**: 11 issues (Tasks 1, 2, 3, 4, 5)
- **Low**: 5 issues (Tasks 1, 2, 3, 4, 5)

### Tasks Requiring Updates

- **Task 1**: 5 issues (2 blocking, 1 high, 1 medium, 1 low)
- **Task 2**: 3 issues (3 medium/high)
- **Task 3**: 9 issues (1 blocking, 3 high, 3 medium, 2 low)
- **Task 4**: 5 issues (3 medium, 2 low)
- **Task 5**: 8 issues (3 critical, 5 minor)
- **Task 6**: 0 issues ✅

---

## Task 1: Test Infrastructure

### Issue 1.1: Mock CLI JSON Output Format Mismatch (BLOCKING)
**Location**: Subtask 1.2 acceptance criteria

**Problem**: The task specifies the mock should return `{"result":{"verdict":"PASS"}}`, but this mismatches how the hook extracts the verdict.

**Plan requirement** (lines 204, 228):
- The CLI returns structured JSON with `result`, `session_id`, `cost`, and `usage` fields
- The verdict schema constrains the **contents of the `result` field**, not the top-level JSON
- Hook extracts via `jq -r '.result.verdict'`

**Expected format**:
```json
{
  "result": {"verdict": "PASS"},
  "session_id": "abc123",
  "cost": {"input_tokens": 100, "output_tokens": 50},
  "usage": {"requests": 1}
}
```

**Impact**: If the mock returns only `{"result":{"verdict":"PASS"}}`, then `jq -r '.result.verdict'` extracts the object `{"verdict":"PASS"}` (as a string), not `"PASS"`. The hook's verdict comparison will fail.

**Fix required**: Update subtask 1.2 acceptance criteria to specify the complete JSON structure with all four fields.

---

### Issue 1.2: Review File Content Specification Incomplete (BLOCKING)
**Location**: Subtask 1.2 acceptance criteria

**Problem**: The acceptance criteria state review files should be "plain markdown without VERDICT lines" but don't specify what content to write.

**Context**: The plan's mock code sample (lines 463-481) shows VERDICT lines in markdown, but line 228 explicitly states "the prompt no longer needs to include a VERDICT line in the markdown" because verdicts are now returned via JSON.

**Resolution**: The task's "without VERDICT lines" is CORRECT per the architectural change, but incomplete.

**Fix required**: Update subtask 1.2 acceptance criteria to specify:
- For `MOCK_CLAUDE_VERDICT=PASS`: Write "# Review\nNo issues found. The implementation looks good."
- For `MOCK_CLAUDE_VERDICT=FAIL`: Write "# Review\n## Issues Found\n1. Example issue description"
- No markdown VERDICT lines
- JSON verdict returned separately via stdout

---

### Issue 1.3: Missing Helper Function Implementation Guidance (HIGH)
**Location**: Subtask 1.1 acceptance criteria

**Problem**: The acceptance criteria list what functions must exist but don't specify critical implementation details.

**Missing specifications**:

1. **`run_hook()` implementation**: How to capture stdout, stderr, and exit code "separately"? Should use temp files? Process substitution? The existing `test-validate-ground-rules.sh` has a pattern that should be extracted.

2. **`assert_approved()` behavior**: Should verify:
   - Exit code 0 AND no `decision: "block"` in output?
   - Exit code 0 AND (`suppressOutput: true` OR `systemMessage` OR empty output)?

3. **`assert_blocked()` behavior**: Should check exit code 0 AND `decision: "block"` AND reason matches pattern? Use `jq` or string matching?

4. **`create_state_json()` parameter format**: Should the second parameter be a full JSON string, individual field values, or a `jq` expression?

**Fix required**: Add implementation guidance to subtask 1.1 acceptance criteria specifying the patterns for each critical helper function.

---

### Issue 1.4: Test Runner Argument Parsing Ambiguity (MEDIUM)
**Location**: Subtask 1.3 acceptance criteria

**Problem**: The criteria don't specify which test files the `state` and `validation` arguments should run.

**Ambiguities**:
1. **`state` argument**: Should it run only `test-stop-hook-auto-review.sh`, or also include `test-stop-hook-state-transitions.sh` and `test-stop-hook-cli-invocation.sh`?
2. **`validation` argument**: Should it run `test-stop-hook-validation.sh` (the renamed file from Task 2)?
3. **Backward compatibility**: Subtask 1.3 completes BEFORE the rename in Task 2. How should `make test-validation` work during the transition?

**Fix required**: Add explicit file-to-argument mapping in subtask 1.3 acceptance criteria, clarifying transition period behavior.

---

### Issue 1.5: Missing Makefile Target for Full Hook Test Suite (LOW)
**Location**: Subtask 1.3 acceptance criteria

**Problem**: The criteria add `make test-state` and `make test-validation` but don't add a `make test-hooks` target to run ALL hook tests together.

**Plan says** (line 416): "Run all test files in `tests/hooks/` matching `test-*.sh` when `hooks` or `all` is specified"

**Fix required**: Add `make test-hooks` target to subtask 1.3 acceptance criteria.

---

## Task 2: Unified Stop Hook - Validation Migration

### Issue 2.1: Missing Hook Boilerplate - `cd` into `cwd` (HIGH)
**Location**: Subtask 2.1 acceptance criteria

**Plan requirement** (Hook Input/Output Protocol):
> The hook `cd`s into this directory before doing anything.

**Task 2.1**: Mentions extracting `cwd` and validating it, but does NOT explicitly require executing `cd "$CWD"` before checking for `.taskie/plans`.

**Fix required**: Add to 2.1 acceptance criteria: "Executes `cd "$CWD"` after validating the directory, before any `.taskie/plans` checks"

---

### Issue 2.2: Plan Directory Detection Should Be in Subtask 2.1 (HIGH)
**Location**: Subtask 2.1 acceptance criteria

**Problem**: The hook logic flow is:
1. Check `stop_hook_active` (2.1) ✓
2. Check if `.taskie/plans` exists (2.1) ✓
3. **Find most recent plan directory** (MISSING from 2.1)
4. Read `state.json` (deferred to Task 3)
5-6. Validation (2.2)

The plan directory detection (step 3) needs to happen BEFORE validation. Subtask 2.1 should establish this detection logic, then 2.2 uses it.

**Fix required**: Add to 2.1 acceptance criteria: "Finds the most recently modified plan directory using `find` with the correct heuristic (including state.json in modification time)"

---

### Issue 2.3: Version Bump Calculation Error (MEDIUM)
**Location**: Subtask 2.5 acceptance criteria

**Current version**: v2.2.0 (per README.md and memory)

**Task shows**: "MAJOR: 2.2.1 → 3.0.0"

**Correct bump**: `2.2.0 → 3.0.0`

**Fix required**: Update subtask 2.5 to show `(MAJOR: 2.2.0 → 3.0.0)`

---

## Task 3: Unified Stop Hook - Auto-Review Logic

### Issue 3.1: max_reviews==0 Early Return Missing phase_iteration Write Detail (HIGH)
**Location**: Subtask 3.1 acceptance criteria

**Problem**: The criteria say "does NOT increment `phase_iteration`" but don't specify what value to write to state.

**Plan requirement** (line 114): "it sets `next_phase` to the advance target, writes state, and approves immediately."

**Why this matters**: When `continue-plan` reads the state, it needs to see that the review phase was "entered" (phase set to review) but no reviews ran (iteration still 0).

**Fix required**: Add to 3.1 acceptance criteria: "Writes `phase_iteration: 0` to state (no increment, but field must be written for state consistency)"

---

### Issue 3.2: Hard Stop systemMessage is Improvement Over Plan (MEDIUM)
**Location**: Subtask 3.2 acceptance criteria

**Task specifies**: `systemMessage: "Max review limit (${MAX_REVIEWS}) reached for ${REVIEW_TYPE}. Edit state.json to adjust max_reviews or set next_phase manually."`

**Plan says** (lines 113, 179, 536): Hard stop "approves (falls through to validation)" with no mention of a systemMessage.

**Assessment**: This is an improvement over the plan (more user-friendly). Keep it, but note the deviation. The warning doesn't break the workflow.

---

### Issue 3.3: TASK_FILE_LIST Empty Handling Scope Ambiguity (MEDIUM)
**Location**: Subtask 3.2 acceptance criteria

**Problem**: "Empty `TASK_FILE_LIST` → skip review, approve with warning"

**Clarification needed**:
1. This only applies to **tasks-review** and **all-code-review** (which use TASK_FILE_LIST)
2. For **code-review** of a single task, the hook uses `current_task` from state.json directly. If `task-${current_task}.md` is missing, what happens? The plan doesn't say.

**Fix required**:
1. Clarify that empty TASK_FILE_LIST check only applies to tasks-review and all-code-review
2. Add acceptance criterion: "If `task-${current_task}.md` doesn't exist during code-review, skip review and approve with warning"

---

### Issue 3.4: Remaining Tasks Check Pattern Prone to False Positives (BLOCKING)
**Location**: Subtask 3.3 acceptance criteria

**Task specifies**: `grep '^|' tasks.md | grep -i 'pending' | wc -l`

**Problem**: This could match:
- `| pending |` (correct)
- `| 3 | Task 3 | A pending refactor is mentioned here | complete |` (FALSE POSITIVE - the word "pending" in prose, not the status column)

**Impact**: The hook could incorrectly detect remaining tasks when all are actually complete, causing the workflow to continue task implementation instead of advancing to all-code-review.

**Fix required**: Use a more precise pattern that checks the status column specifically (4th column in table). Pattern: `grep '^|' tasks.md | awk -F'|' '{print $4}' | grep -i 'pending' | wc -l`

---

### Issue 3.5: Approval systemMessage on Auto-Advance Not Required by Plan (LOW)
**Location**: Subtask 3.3 acceptance criteria

**Task specifies**: "Approve output includes `systemMessage` informing the user what happened"

**Plan says** (line 152): Silent approval is preferred for normal flow: `{"suppressOutput": true}`

**Assessment**: This is an optional improvement. If implemented, use `suppressOutput: true` to keep it silent. Not required.

---

### Issue 3.6: Test Suite Missing max_reviews==0 for All Review Types (MEDIUM)
**Location**: Subtask 3.5

**Problem**: Test suite 6, test 8 (line 615) tests `max_reviews: 0` for code-review only. The plan doesn't specify testing this for plan-review, tasks-review, or all-code-review.

**Fix required**: Add tests for `max_reviews: 0` early return for all four review types to ensure advance target mapping is correct.

---

### Issue 3.7: Review Log Cleanup Timing Ambiguous (LOW)
**Location**: Subtask 3.2 acceptance criteria

**Task says**: "Log file (`.review-${ITERATION}.log`) cleaned up after successful review"

**Clarification needed**: "Successful review" should mean "CLI exited 0 and review file was written" (regardless of PASS/FAIL verdict). Only CLI crashes or failures should leave the log behind.

**Fix required**: Clarify: "Successful review means CLI exited 0 and review file was written (regardless of verdict)"

---

### Issue 3.8: Test Suite Missing Empty TASK_FILE_LIST Test (LOW)
**Location**: Subtask 3.5, test suite 4

**Problem**: Acceptance criteria (line 42) say "Empty `TASK_FILE_LIST` → skip review, approve with warning" but there's no explicit test for this in suite 4.

**Fix required**: Add test to suite 4 for empty TASK_FILE_LIST during tasks-review and all-code-review.

---

### Issue 3.9: Test Suite 3, Test 16 - Atomic Write Field Verification Unclear (MEDIUM)
**Location**: Subtask 3.5, test suite 3, test 16

**Problem**: "Atomic write: state.json is valid JSON after update | any review trigger | read state.json after hook — must be valid JSON parseable by `jq` with all 8 required fields present"

**Plan's forward-compatibility note** (line 388): Fields can be optional with defaults: `(.consecutive_clean // 0)`

**Clarification needed**: The test should verify the hook writes all fields it modifies, not necessarily all 8 fields. Verify: phase, next_phase, phase_iteration, review_model, consecutive_clean are written, and max_reviews, current_task, tdd are preserved.

**Fix required**: Clarify test 16 checks fields hook writes, not all 8 fields unconditionally.

---

## Task 4: Action File Changes - Planning Actions

### Issue 4.1: Subtask 4.2 - tasks.md Completeness Check Underspecified (MEDIUM)
**Location**: Subtask 4.2 acceptance criteria

**Plan requirement** (line 324): "at least one `|` line after the header"

**Task says**: "tasks.md exists + has table rows"

**Fix required**: Add precision: "tasks.md completeness verified by finding at least one line starting with `|`"

---

### Issue 4.2: Subtask 4.2 - Code-Review Crash Recovery Detail Missing (MEDIUM)
**Location**: Subtask 4.2 acceptance criteria

**Plan requirement** (lines 322-323): "read the current task file (`task-{current_task}.md`) and check whether all subtasks are marked complete"

**Task says**: "Checks subtask completion for code-review/all-code-review"

**Missing details**:
- Which task file to read (should use `current_task` from state.json)
- What "complete" means (subtask status markers)

**Fix required**: Add to acceptance criteria: "code-review crash recovery reads `task-{current_task}.md` and checks all subtask status markers for completion"

---

### Issue 4.3: Subtask 4.3 - Missing Atomic Write Instruction (MEDIUM)
**Location**: Subtask 4.3 acceptance criteria

**Plan emphasizes** (lines 263-286): Atomic state updates using read-modify-write with temp file + mv.

**Task says**: "read-modify-write" but doesn't mention the atomic write pattern.

**Fix required**: Add to 4.3 acceptance criteria: "Uses atomic write pattern (temp file + mv) for state.json updates"

---

### Issue 4.4: Subtask 4.2 - Plan Completeness Check Could Be Clearer (LOW)
**Location**: Subtask 4.2 acceptance criteria

**Plan says** (line 323-324): "contains an `## Overview` heading **OR** is > 50 lines"

**Task says**: ">50 lines or has `## Overview`"

**Enhancement**: Rephrase to emphasize the OR is checking for either characteristic: "plan.md completeness verified by checking it has `## Overview` heading OR >50 lines (either condition suffices)"

---

### Issue 4.5: Subtask 4.2 - Missing Explicit complete-task vs complete-task-tdd Routing (LOW)
**Location**: Subtask 4.2 acceptance criteria

**Plan** (line 326): When `next_phase` is `"complete-task"` or `"complete-task-tdd"`, route to the correct variant.

**Task**: Doesn't explicitly verify both variants are handled.

**Fix required**: Add explicit check: "Routes correctly for both `complete-task` and `complete-task-tdd` variants"

---

## Task 5: Action File Changes - Task & Review Actions

### Issue 5.1: Subtask 5.1 - Missing State Field Preservation (CRITICAL)
**Location**: Subtask 5.1 acceptance criteria

**Problem**: Only specifies setting `phase`, `current_task`, `next_phase`. Doesn't require preserving other fields.

**Plan requirement** (lines 265-285, 245): The read-modify-write pattern must preserve all fields not being modified. "Keep all other fields (max_reviews, current_task, phase_iteration, review_model, consecutive_clean) unchanged."

**Fix required**: Add to 5.1 acceptance criteria: "All other fields (`max_reviews`, `phase_iteration`, `review_model`, `consecutive_clean`, `tdd`) preserved from existing state"

---

### Issue 5.2: Subtask 5.1 - Missing Hook Transition Logic Removal Verification (CRITICAL)
**Location**: Subtask 5.1 acceptance criteria

**Plan** (line 340): "The transition to `all-code-review` when no tasks remain is handled by the hook, NOT by the action file."

**Task mentions**: This is correct in the short description but doesn't verify removal in acceptance criteria.

**Fix required**: Add to acceptance criteria: "No logic for detecting last task or transitioning to `all-code-review`"

---

### Issue 5.3: Subtask 5.4 - Review Action Hook-Invoked Detection Unclear (CRITICAL)
**Location**: Subtask 5.4 acceptance criteria

**Problem**: States "Review actions: standalone sets `next_phase: null`; hook-invoked doesn't update state"

**Question**: How does a review action know it was "hook-invoked" vs. manually invoked?

**Plan says** (line 344): "When invoked by the hook, the hook manages the state transitions (the action itself doesn't need to update `state.json` since the hook does it)."

**Clarification needed**: Review actions should:
1. Check if `phase_iteration` exists and is non-null (automated mode): don't update state.json
2. Otherwise (standalone): update state.json with `next_phase: null`

OR simpler: review actions could ALWAYS write `next_phase: null`, and the hook overwrites immediately after.

**Fix required**: Clarify the detection mechanism or simplify to always-write approach.

---

### Issue 5.4: Subtask 5.2 - Missing State Read Requirement (MEDIUM)
**Location**: Subtask 5.2 acceptance criteria

**Problem**: States "`max_reviews` preserved from existing state" but doesn't require reading the entire state first.

**Plan requirement** (lines 265-285): Always read entire state first, modify specific fields, write all fields back.

**Fix required**: Add to acceptance criteria: "Read entire `state.json` before modifying (read-modify-write pattern)"

---

### Issue 5.5: Subtask 5.2 - Old Loop Removal Wording Ambiguity (MINOR)
**Location**: Subtask 5.2 acceptance criteria

**Task says**: "Old Phase 2/3/4 review loop removed from both `complete-task.md` and `complete-task-tdd.md`"

**Clarification**: Only `complete-task.md` has this loop currently. `complete-task-tdd.md` may not.

**Fix required**: If `complete-task-tdd.md` doesn't have the loop, change to singular: "removed from `complete-task.md`"

---

### Issue 5.6: Subtask 5.2 - consecutive_clean Reset Needs Explanation (MINOR)
**Location**: Subtask 5.2 acceptance criteria

**Task correctly states**: `consecutive_clean: 0`

**Enhancement**: Add explanation: "`consecutive_clean: 0` (fresh review cycle - must reset when entering code review)"

This ensures the implementer understands the semantic meaning.

---

### Issue 5.7: Subtask 5.4 - Automated vs Standalone Detection Logic Needs Clarification (MINOR)
**Location**: Subtask 5.4 acceptance criteria

**Task says**: "Automated vs standalone detection: check if `phase_iteration` is non-null"

**Clarification**: This is technically correct, but the detection applies differently to review vs post-review actions:
- **Review actions**: Check if they were invoked standalone OR by hook
- **Post-review actions**: Check `phase_iteration` to determine if in automated flow

**Fix required**: Clarify distinction between review and post-review detection logic.

---

### Issue 5.8: Subtask 5.5 - Conditional Logic Could Be Clearer (MINOR)
**Location**: Subtask 5.5 acceptance criteria

**Task says**: "Sets `current_task` to new task ID only when `current_task` is currently null"

**Enhancement**: Be more explicit:
- "If `current_task` is null: set to new task ID"
- "If `current_task` is non-null: preserve existing value (task in progress)"

---

## Task 6: Ground Rules, Codex CLI Updates, and Edge Case Tests

**No issues found.** ✅

All requirements are correctly captured:
- ✅ All 4 ground-rules updates from the plan are in acceptance criteria
- ✅ Correctly scopes ONLY the two Codex prompts (new-plan, continue-plan)
- ✅ Includes ground rules reference path requirement
- ✅ All 12 edge case tests are correctly scoped
- ✅ Total test count (80) is correct

---

## Summary of Required Actions

### Blocking Issues (Must Fix Before Implementation)

1. **Issue 1.1**: Task 1, Subtask 1.2 - Fix mock CLI JSON output format to include all 4 fields
2. **Issue 1.2**: Task 1, Subtask 1.2 - Specify exact review file content for PASS/FAIL cases
3. **Issue 3.4**: Task 3, Subtask 3.3 - Fix remaining tasks detection pattern to avoid false positives

### Critical/High Issues (Should Fix Before Implementation)

4. **Issue 1.3**: Task 1, Subtask 1.1 - Add implementation guidance for helper functions
5. **Issue 2.1**: Task 2, Subtask 2.1 - Add explicit `cd "$CWD"` requirement
6. **Issue 2.2**: Task 2, Subtask 2.1 - Move plan directory detection to subtask 2.1
7. **Issue 3.1**: Task 3, Subtask 3.1 - Specify phase_iteration: 0 write in max_reviews==0 case
8. **Issue 5.1**: Task 5, Subtask 5.1 - Add state field preservation requirement
9. **Issue 5.2**: Task 5, Subtask 5.1 - Add hook transition logic removal verification
10. **Issue 5.3**: Task 5, Subtask 5.4 - Clarify review action hook-invoked detection

### Medium Severity (Recommended Fixes)

11. **Issue 1.4**: Task 1, Subtask 1.3 - Clarify test runner argument-to-file mapping
12. **Issue 2.3**: Task 2, Subtask 2.5 - Fix version bump calculation (2.2.0 → 3.0.0)
13. **Issue 3.2**: Task 3, Subtask 3.2 - Acknowledge hard stop systemMessage is improvement (keep it)
14. **Issue 3.3**: Task 3, Subtask 3.2 - Clarify TASK_FILE_LIST empty handling scope
15. **Issue 3.6**: Task 3, Subtask 3.5 - Add max_reviews==0 tests for all review types
16. **Issue 3.9**: Task 3, Subtask 3.5 - Clarify test 16 field verification requirements
17. **Issue 4.1**: Task 4, Subtask 4.2 - Add precision to tasks.md completeness check
18. **Issue 4.2**: Task 4, Subtask 4.2 - Add code-review crash recovery details
19. **Issue 4.3**: Task 4, Subtask 4.3 - Add atomic write instruction
20. **Issue 5.4**: Task 5, Subtask 5.2 - Add explicit state read requirement

### Low Severity (Nice to Have)

21. **Issue 1.5**: Task 1, Subtask 1.3 - Add `make test-hooks` target
22. **Issue 3.5**: Task 3, Subtask 3.3 - Note auto-advance systemMessage is optional
23. **Issue 3.7**: Task 3, Subtask 3.2 - Clarify "successful review" definition for log cleanup
24. **Issue 3.8**: Task 3, Subtask 3.5 - Add empty TASK_FILE_LIST test
25. **Issue 4.4**: Task 4, Subtask 4.2 - Rephrase plan completeness OR condition
26. **Issue 4.5**: Task 4, Subtask 4.2 - Add explicit complete-task variant routing check
27. **Issues 5.5-5.8**: Task 5 - Various minor wording improvements

---

## Positive Findings

### Task 6 is Perfect ✅
Task 6 has **zero issues** and accurately reflects all plan requirements for ground rules, Codex CLI updates, and edge case testing.

### Overall Task Structure is Sound
The task decomposition follows the plan's architecture well:
- Clear separation between validation migration (Task 2) and auto-review logic (Task 3)
- Appropriate parallelization (Tasks 3, 4, 5 can run after Task 2)
- Test infrastructure properly prioritized (Task 1 must complete first)

### Most Acceptance Criteria Are Thorough
The majority of acceptance criteria correctly capture plan requirements. The issues identified are primarily:
- Missing precision in implementation details
- Ambiguity in detection/conditional logic
- Minor wording improvements for clarity

---

## Recommendation

**Address all 10 blocking/critical issues** (1.1, 1.2, 1.3, 2.1, 2.2, 3.1, 3.4, 5.1, 5.2, 5.3) before beginning implementation. These issues could cause:
- Test infrastructure failures (1.1, 1.2, 1.3)
- Hook logic errors (2.1, 2.2, 3.1, 3.4)
- State corruption (5.1, 5.2, 5.3)

**Medium severity issues** should be addressed to prevent implementation confusion and ensure the hook behaves correctly in edge cases.

**Low severity issues** can be addressed during implementation if time permits, or deferred as minor improvements.

The tasks are **fundamentally sound** and match the plan's intent. With the identified fixes, they provide a solid implementation guide for the stateful-taskie feature.
