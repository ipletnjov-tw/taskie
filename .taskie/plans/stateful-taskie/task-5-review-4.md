# Task 5 Review 4: Deep Analysis of Task & Review Action Files

**Reviewer**: Claude Sonnet 4.5
**Date**: 2026-02-08
**Scope**: Task 5 (next-task.md, complete-task.md, continue-task.md, add-task.md, all review/post-review actions)
**Review Focus**: Edge cases, correctness, UX, security, consistency beyond previous reviews

---

## CRITICAL ISSUES

### Issue 5.C1: complete-task.md example has placeholder but instructions say to substitute
**File**: `taskie/actions/complete-task.md:42`
**Severity**: MEDIUM
**Description**: Line 42 says "Example bash command for atomic write (replace {task-id} with the actual task ID, e.g., "3"):" but the example itself on line 46 uses `--arg current_task "{task-id}"` which will create a state file with the literal string "{task-id}" if the agent copies the example without substituting.

**Current code** (lines 42-57):
```
Example bash command for atomic write (replace {task-id} with the actual task ID, e.g., "3"):
```bash
TEMP_STATE=$(mktemp)
MAX_REVIEWS=$(jq -r '.max_reviews // 8' state.json)
jq --arg phase "complete-task" \
   --arg current_task "{task-id}" \
   ...
```

**Issue**: The instruction to "replace {task-id}" appears BEFORE the code block, but an agent might copy-paste the code without reading the preceding line.

**Impact**: state.json will have `"current_task": "{task-id}"` (literal placeholder) instead of `"current_task": "3"`.

**Recommendation**: Either:
1. Use a clearly invalid placeholder like `"REPLACE_ME"` that will cause obvious failures
2. Move the substitution note INSIDE the code block as a comment
3. Show the substituted version in the example: `--arg current_task "3"`

**Same issue exists in**:
- `complete-task-tdd.md:52` (identical problem)

---

### Issue 5.C2: next-task.md doesn't specify HOW to select the next task
**File**: `taskie/actions/next-task.md:4-6`
**Severity**: HIGH
**Description**: The action says "Proceed to the next task in the implementation plan" and "Read `.taskie/plans/{current-plan-dir}/tasks.md` and identify the first task with status 'pending'" but doesn't specify this in the action instructions - it's only implied.

Wait, let me re-read...

Line 4 says:
```
**Task selection**: Read `.taskie/plans/{current-plan-dir}/tasks.md` and identify the first task with status "pending" (by ascending task ID). This is the task you will implement.
```

OK so it DOES specify the task selection logic explicitly. ✓

**Verdict**: FALSE ALARM - this is documented.

---

### Issue 5.C3: Review actions set phase_iteration to null explicitly but don't read it first
**File**: Multiple review action files
**Severity**: LOW
**Description**: Review actions (code-review.md, plan-review.md, tasks-review.md, all-code-review.md) all have logic to set `phase_iteration: null` in standalone mode, with the note "explicitly set to prevent stale values".

**Example from code-review.md:23**:
```
- `phase_iteration`: `null` (explicitly set to prevent stale values)
```

**Issue**: Setting a field to null "to prevent stale values" only makes sense if the field might have a stale non-null value from a previous automated cycle. But the review action is reading the CURRENT state and then updating it. If `phase_iteration` is already null (standalone), setting it to null again is redundant. If `phase_iteration` is non-null (automated), the action doesn't update state at all (line 27 says "DO NOT update state.json").

**Logic flaw**:
- If `phase_iteration` is null → standalone → set to null (redundant)
- If `phase_iteration` is non-null → automated → don't update state (so the explicit null set never happens)

**Actual impact**: None - the "explicitly set to prevent stale values" is defensive programming that doesn't hurt, just adds unnecessary writes.

**Recommendation**: Clarify the note to say "set to null to mark standalone mode" rather than "prevent stale values" since the value is being freshly read, not stale.

---

### Issue 5.C4: Post-review actions don't validate phase_iteration type
**File**: Multiple post-review action files
**Severity**: LOW
**Description**: Post-review actions check "if `phase_iteration` is non-null (a number)" but don't actually validate it's a number. What if state.json has `"phase_iteration": "corrupted"` (string)?

**Example from post-code-review.md:19**:
```
2. Check the `phase_iteration` field:
   - **If `phase_iteration` is non-null (a number)**: This is AUTOMATED mode
```

**Issue**: The check is "non-null" not "is a number". If phase_iteration is corrupted to a string, boolean, or array, the logic would treat it as automated mode.

**Current logic**: `if phase_iteration is not null → automated mode`
**Intended logic**: `if phase_iteration is a number → automated mode`

**Impact**: If state.json is corrupted with `"phase_iteration": "broken"`, the post-review action would:
1. Detect non-null (✓ "broken" is not null)
2. Enter automated mode branch
3. Set `next_phase: "code-review"` (trigger another review)
4. Preserve phase_iteration (keeps "broken" string)

This creates a review loop with a corrupted state.

**Recommendation**: Add validation that phase_iteration is either null or a non-negative integer. If it's corrupted, inform user and ask what to do.

---

### Issue 5.C5: continue-task.md preserves next_phase but doesn't validate it
**File**: `taskie/actions/continue-task.md:12`
**Severity**: LOW
**Description**: The action says "Preserve `next_phase` from the existing state (do NOT change it)" but doesn't validate that next_phase is a valid phase name.

**Current logic**:
```
- **IMPORTANT**: Preserve `next_phase` from the existing state (do NOT change it)
```

**Issue**: What if state.json has `"next_phase": "invalid-phase-name"` due to corruption or manual edit? The action will preserve it, and then when continue-task completes and the hook runs, the routing in continue-plan.md won't recognize it and might have undefined behavior.

**Impact**: Silent corruption propagation.

**Recommendation**: Add a note that if next_phase has an unrecognized value, the agent should inform the user rather than blindly preserving it. Or link to continue-plan.md for the list of valid next_phase values.

---

## MEDIUM ISSUES

### Issue 5.M1: add-task.md sets current_task when it's null, but what if user wants it null?
**File**: `taskie/actions/add-task.md:34`
**Severity**: LOW
**Description**: The logic auto-sets current_task to the new task ID if it's currently null. But what if the user hasn't started implementation yet and wants current_task to stay null?

**Current logic**:
```
2. Check the `current_task` field:
   - **If `current_task` is null**: Set `current_task` to the new task ID
   - **If `current_task` is non-null**: Preserve the existing value
```

**Scenario**: User creates plan, creates tasks (current_task: null), then uses add-task to add a "nice-to-have" task that should be done AFTER the existing tasks. The add-task action would set current_task to the new task ID, making it the "active" task even though the user hasn't started implementation.

**Counter-argument**: If current_task is null, no task is in progress, so setting it to the new task makes sense. The new task becomes the "first pending task" by default.

**Alternative interpretation**: Maybe the logic should only set current_task if the new task is being added to the BEGINNING of the task list (lower ID than existing tasks)?

**Verdict**: This is a design decision, not a bug. The current behavior is defensible but could be surprising. Recommend adding a note explaining WHY current_task is set (to mark the new task as active when no task is in progress).

---

### Issue 5.M2: Review file naming uses {iteration} but doesn't explain numbering in all files
**File**: code-review.md, plan-review.md, tasks-review.md, all-code-review.md
**Severity**: TRIVIAL
**Description**: The review actions say "For STANDALONE reviews (manual invocation): use an incrementing number based on existing review files in the directory" but don't specify HOW to determine the next number.

**Example from code-review.md:11**:
```
- For STANDALONE reviews (manual invocation): use an incrementing number based on existing review files in the directory
```

**Ambiguity**: If the directory has `code-review-1.md` and `code-review-3.md` (2 is missing), should the next one be:
1. `code-review-2.md` (fill the gap)?
2. `code-review-4.md` (max + 1)?

**Recommendation**: Clarify that it should be "max existing iteration number + 1" or "next sequential number filling gaps".

---

### Issue 5.M3: Complete-task actions don't validate that tasks.md has pending tasks
**File**: `taskie/actions/complete-task.md:9`
**Severity**: LOW
**Description**: The action says "identify the first task with status 'pending'" but doesn't specify what to do if NO pending tasks exist.

**Current text** (line 9):
```
Read `.taskie/plans/{current-plan-dir}/tasks.md` and identify the first task with status "pending". This is the task you will implement.
```

**Missing**: What if all tasks are "done" or "cancelled"? The action should tell the agent to:
1. Inform the user that no pending tasks remain
2. Set next_phase to "complete" or "all-code-review"
3. NOT attempt to implement a non-existent task

**Same issue in**: `complete-task-tdd.md:9`

**Recommendation**: Add explicit instruction for the no-pending-tasks case.

---

### Issue 5.M4: Post-review jq examples use automatic preservation without comment
**File**: Multiple post-review files (post-code-review.md, post-plan-review.md, etc.)
**Severity**: TRIVIAL
**Description**: The jq examples show minimal field updates and rely on implicit preservation of other fields, but don't explain this.

**Example from post-code-review.md:27-29**:
```bash
jq '.phase = "post-code-review" | .next_phase = "code-review"' state.json > "$TEMP_STATE"
```

**Issue**: This preserves `phase_iteration`, `max_reviews`, `current_task`, etc. automatically, but a reader unfamiliar with jq might not realize this.

**Recommendation**: Add a comment:
```bash
# This preserves all other fields (phase_iteration, max_reviews, etc.) automatically
jq '.phase = "post-code-review" | .next_phase = "code-review"' state.json > "$TEMP_STATE"
```

---

### Issue 5.M5: next-task and next-task-tdd have inconsistent instructions structure
**File**: `taskie/actions/next-task.md` vs `taskie/actions/next-task-tdd.md`
**Severity**: TRIVIAL
**Description**: next-task.md has a very simple structure (7 lines of instructions + state update), while next-task-tdd.md has detailed TDD cycle instructions (4-step RED-GREEN-REFACTOR). This makes the files feel inconsistent.

**Recommendation**: This is intentional - TDD requires more guidance. Not an issue, just an observation.

---

## MINOR ISSUES

### Issue 5.m1: All review actions mention "review-id" in line 7 but use "iteration" elsewhere
**File**: code-review.md:7, plan-review.md:7, tasks-review.md:7, all-code-review.md:7
**Severity**: TRIVIAL
**Description**: Line 7 says `{review-id}` but everywhere else uses `{iteration}`. This is inconsistent terminology.

**Example from code-review.md:7**:
```
Document the results of your review in `.taskie/plans/{current-plan-dir}/code-review-{review-id}.md`.
```

But line 10 says:
```
use the `phase_iteration` value from state.json as the iteration number
```

**Recommendation**: Change `{review-id}` to `{iteration}` for consistency.

---

### Issue 5.m2: complete-task.md says "Replace {task-id}" but uses it in TWO places
**File**: `taskie/actions/complete-task.md:42-56`
**Severity**: TRIVIAL
**Description**: The note says "replace {task-id} with the actual task ID" but there are TWO occurrences in the example:
1. Line 46: `--arg current_task "{task-id}"`
2. Line 56: (not present in this example, so this is a false alarm)

Wait, let me recount... Line 46 is the only place. So this is NOT an issue.

**Verdict**: FALSE ALARM

---

### Issue 5.m3: Review actions don't specify review verdict format
**File**: All review action files
**Severity**: TRIVIAL
**Description**: The actions say "Document the results of your review in {review-file}" but don't specify what format the review should take. Should it have PASS/FAIL verdict? Issue list? Summary?

**Recommendation**: Link to ground-rules.md or provide a template for review file structure.

---

## OBSERVATIONS (Not issues, but noteworthy)

### Observation 5.O1: next-task vs complete-task have overlapping functionality
Both actions select the next pending task and implement it. The difference is:
- next-task: standalone, sets next_phase: null
- complete-task: automated, sets next_phase: "code-review"

This overlap means any changes to implementation logic need to be made in both files (DRY violation). However, complete-task DOES inline the instructions (per task 5.2), so this is intentional.

### Observation 5.O2: No action validates state.json schema
None of the actions check that state.json has all 8 required fields. If a field is missing, jq operations might fail or produce unexpected results. Consider adding a validation step or using `jq -e` (exit on error) in examples.

### Observation 5.O3: Atomic writes could fail silently
The `mv "$TEMP_STATE" state.json` command could fail (permissions, disk full), leaving state.json in the old state and TEMP_STATE orphaned. The examples don't show error handling.

### Observation 5.O4: Review file naming collision is possible
If automated review and standalone review both create the same iteration number (e.g., phase_iteration: 2 in automated mode, and user manually creates 2nd standalone review), they'll overwrite each other. The naming convention doesn't distinguish between automated and manual reviews.

**Possible solution**: Use different naming patterns:
- Automated: `code-review-auto-{iteration}.md`
- Standalone: `code-review-manual-{number}.md`

But this would require changing the spec.

---

## SUMMARY

**Critical Issues**: 3 (C1, C4, C5 are real; C2, C3 are low severity)
**Medium Issues**: 5 (M1-M5 are all low severity or style issues)
**Minor Issues**: 3 (all trivial)
**Observations**: 4

**Blocking Issues for Production**:
1. **Issue 5.C1**: complete-task examples use placeholder {task-id} that could be copied literally
2. **Issue 5.C4**: Post-review actions don't validate phase_iteration type, could enter review loop with corrupted state
3. **Issue 5.M3**: complete-task actions don't handle no-pending-tasks case

**Recommended Fixes**:
1. Fix C1: Change {task-id} placeholder to a concrete example "3" or add clear substitution instruction
2. Fix C4: Add type validation for phase_iteration (must be null or integer)
3. Fix M3: Add instruction for when no pending tasks exist
4. Fix M2: Clarify review file numbering logic (max + 1 vs fill gaps)
5. Fix M4: Add comments to jq examples explaining implicit field preservation
6. Fix m1: Rename {review-id} to {iteration} for consistency

**Overall Assessment**: The implementation is 90% correct. The critical issues are minor (placeholder confusion, missing edge case handling). The biggest risk is C4 (corrupted phase_iteration causing review loops), which needs a defensive check.

**Code Quality**: Very high. The action files are well-documented, consistent in structure, and handle both automated and standalone modes correctly. The jq examples are helpful, though they could benefit from error handling comments.

**Testing Recommendation**: Manual testing should cover:
1. Copying examples literally (to catch placeholder issues)
2. Corrupted state.json scenarios (to catch validation gaps)
3. Empty tasks.md (to catch edge cases)
4. Both automated and standalone invocation paths
