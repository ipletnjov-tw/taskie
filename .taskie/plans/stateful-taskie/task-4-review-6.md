# Task 4 Code Review 6

**Reviewer**: Claude Sonnet 4.5
**Date**: 2026-02-08
**Scope**: All changes to planning action files (new-plan.md, continue-plan.md, create-tasks.md)

## Executive Summary

**Verdict**: **FAIL** - 8 critical issues, 3 medium issues, 2 minor issues found

This review examines ALL code changes in Task 4 from commit a619021. While the basic structure is sound, there are critical issues with documentation accuracy, missing edge cases, crash recovery logic, and inconsistencies between specifications and implementation.

---

## Critical Issues

### C1: continue-plan.md heuristic logic conflicts with test expectations
**File**: `taskie/actions/continue-plan.md:229-244`
**Severity**: Critical

The auto-advance logic for code-review when no tasks remain has a serious issue. Lines 229-244 show:

```markdown
code-review)
    # Check if more tasks remain
    TASKS_REMAIN=$(grep '^|' "$RECENT_PLAN/tasks.md" 2>/dev/null | tail -n +3 | awk -F'|' -v cur="$CURRENT_TASK" '{gsub(/[[:space:]]/, "", $2); if ($2 != cur) print $3}' | grep -i 'pending' | wc -l)
    if [ "$TASKS_REMAIN" -gt 0 ]; then
        ...
    else
        # No tasks remain, go to all-code-review with fresh cycle
        ADVANCE_TARGET="all-code-review"
        # Reset for fresh review cycle
        PHASE_ITERATION=0
        REVIEW_MODEL="opus"
        CONSECUTIVE_CLEAN=0
    fi
```

This is **implementation code** (bash snippet) embedded in an **action file** (prompt file). Action files should contain INSTRUCTIONS for Claude, not executable shell code. The agent reading this file won't execute this bash code - it will try to IMPLEMENT similar logic. This creates ambiguity about whether Claude should copy this exact code or write its own implementation.

**Root cause**: Mixing implementation concerns into planning prompts.

**Recommendation**: Remove the bash code example and replace with clear English instructions: "When determining crash recovery for code-review, if all tasks in tasks.md have status 'done' and no 'pending' tasks remain, set ADVANCE_TARGET to 'all-code-review' and reset phase_iteration to 0, review_model to 'opus', and consecutive_clean to 0."

---

### C2: continue-plan.md subtask completion check is incorrect
**File**: `taskie/actions/continue-plan.md:42-43`
**Severity**: Critical

Lines 42-43 state:
```markdown
- Checks subtask completion for code-review/all-code-review (reads `task-{current_task}.md` from state.json and verifies all subtask status markers are complete)
```

This instruction is dangerously ambiguous. What does "all subtask status markers are complete" mean?
- Does it mean ALL subtasks must have status="completed"?
- Does it include postponed subtasks?
- What about subtasks with no status field?
- What if the task file has no subtasks section at all?

The action file doesn't specify the exact matching criteria. This will lead to inconsistent implementations across different Claude invocations.

**Recommendation**: Specify exact matching logic:
```markdown
- Checks subtask completion by counting lines matching "- **Status**: completed" and comparing against total lines matching "- **Status**:" (any value). If ratio >= 90%, task is considered complete enough for review.
```

---

### C3: continue-plan.md file existence check ordering bug
**File**: `taskie/actions/continue-plan.md:36-41`
**Severity**: Critical

The plan-review crash recovery (lines 36-37) checks:
```markdown
2. Check if `plan.md` exists AND (has `## Overview` heading OR ≥50 lines) → Likely complete, execute plan-review
```

The file existence check is done with a simple boolean AND, but the heading/line-count checks are in parentheses suggesting OR logic. This can fail if:
1. plan.md doesn't exist (check passes as false AND)
2. OR clause never evaluates
3. Falls through to next heuristic

The critical bug: **"exists AND" should gate the entire check**. If plan.md doesn't exist, attempting to check for heading or count lines will fail.

**Correct logic**:
```markdown
2. If `plan.md` exists: check if (has `## Overview` heading OR ≥50 lines). If either condition is true, execute plan-review. Otherwise, execute new-plan.
```

Note: The current text says "Likely complete" but then routes to plan-review, which suggests the plan is NOT complete (otherwise why review it?). This is semantically confusing.

**Recommendation**: Restructure to explicit if-else blocks with file existence as prerequisite.

---

### C4: new-plan.md contradicts its own requirements
**File**: `taskie/actions/new-plan.md:30`
**Severity**: Critical

Line 30 states:
```markdown
**Important**: This is the ONLY action that constructs `state.json` from scratch. All other actions read and modify the existing state. Use atomic writes (write to temp file, then `mv`) to prevent corruption.
```

But lines 15-28 show a JSON literal being written, with NO atomic write pattern shown. The action tells Claude to "use atomic writes" but doesn't demonstrate HOW. This creates two problems:

1. **Inconsistent examples**: create-tasks.md (lines 46-58) shows a full bash atomic write example with `mktemp`, `jq`, and `mv`. new-plan.md shows nothing.

2. **Dangerous default**: Without an example, Claude may use `echo '...' > state.json` directly, which is NOT atomic and can corrupt state if interrupted.

**Recommendation**: Add atomic write example to new-plan.md matching the pattern from create-tasks.md:
```bash
TEMP_STATE=$(mktemp)
cat > "$TEMP_STATE" << 'EOF'
{
  "max_reviews": 8,
  ...
}
EOF
mv "$TEMP_STATE" .taskie/plans/{current-plan-dir}/state.json
```

---

### C5: create-tasks.md example uses wrong directory structure
**File**: `taskie/actions/create-tasks.md:46-58`
**Severity**: Critical

The example bash command (lines 46-58) shows:
```bash
TEMP_STATE=$(mktemp)
jq --arg phase "create-tasks" \
   ...
   state.json > "$TEMP_STATE"
mv "$TEMP_STATE" state.json
```

This assumes the working directory is `.taskie/plans/{current-plan-dir}/`, but the action never explicitly tells Claude to cd into that directory. If Claude runs this from the project root, it will create state.json in the wrong location.

**Cross-reference**: new-plan.md (line 14) explicitly says "Ensure `.taskie/plans/{current-plan-dir}/` directory exists before writing files. Create it if necessary using `mkdir -p`." But it doesn't say to CD into it. create-tasks.md has no such directory setup instructions at all.

**Recommendation**: Add explicit instruction: "Change to `.taskie/plans/{current-plan-dir}/` directory before updating state.json, or use absolute paths in the jq command."

---

### C6: continue-plan.md crash recovery for code-review uses wrong percentage threshold
**File**: `taskie/actions/continue-plan.md:48-51`
**Severity**: Critical

Lines 48-51 state:
```markdown
4. Route based on completion percentage:
   - If completion_pct ≥ 90% → Assume task is done, execute code-review
   - If 50% < completion_pct < 90% → Assume task in progress, execute continue-task
   - If completion_pct ≤ 50% OR calculation is ambiguous (e.g., 0 total subtasks) → INFORM USER of the ambiguity and ASK whether to continue implementation or start review
```

The ≥90% threshold for "task is done" conflicts with standard definitions:
- **90% complete ≠ done**. A task with 9/10 subtasks done is NOT complete.
- The correct threshold for "done" should be 100%, or the action should use task status from tasks.md, not subtask completion percentage.

This creates a situation where code-review runs on incomplete tasks, which wastes review cycles and creates confusing feedback loops.

**Recommendation**: Change threshold to 100% for "done", or add explicit note that 90% is a pragmatic heuristic for crash recovery that may include incomplete work.

---

### C7: continue-plan.md all-code-review heuristic counts wrong tasks
**File**: `taskie/actions/continue-plan.md:55-58`
**Severity**: Critical

Lines 55-58 show:
```markdown
2. Count tasks in `tasks.md`: done_count = tasks with status exactly "done"; active_count = tasks with status "pending" or "done" (exclude "cancelled", "postponed"). Calculate done_pct = (done_count / active_count) * 100.
```

The definition of `active_count` is wrong. It includes BOTH "pending" AND "done" tasks, then calculates what percentage are done. But this formula will never show whether work is actually complete:

- If 5 tasks are "pending" and 5 are "done": `active_count = 10`, `done_count = 5`, `done_pct = 50%`
- If 0 tasks are "pending" and 5 are "done": `active_count = 5`, `done_count = 5`, `done_pct = 100%` ← correct
- If 1 task is "pending" and 9 are "done": `active_count = 10`, `done_count = 9`, `done_pct = 90%` ← routes to "ask user" instead of continuing implementation

The heuristic should check if ANY pending tasks exist, not calculate a percentage. Percentage makes sense for progress tracking, but for routing decisions, we need a boolean: "are there pending tasks remaining?"

**Recommendation**: Change to: `pending_count = tasks with status "pending". If pending_count == 0, execute all-code-review. Otherwise, inform user that X tasks remain pending and ask whether to continue or review anyway.`

---

### C8: continue-plan.md contradicts design for tasks-review line count
**File**: `taskie/actions/continue-plan.md:41-42`
**Severity**: Critical

Lines 41-42 state:
```markdown
2. Check if `tasks.md` exists and has at least 3 lines starting with `|` → Tasks likely complete (header + separator + at least one task), execute tasks-review
```

This heuristic is TOO LOOSE. It checks for "at least 3 lines starting with |", which matches:
- Header row: `| Id | Status | ... |`
- Separator row: `|----|--------|`
- One task row: `| 1 | pending | ... |`

But this means crash recovery will route to tasks-review even if only ONE task exists and tasks.md was JUST created. This is almost certainly NOT what the user wants - they probably want to finish creating all tasks first.

**Better heuristic**: Check if tasks.md has ≥5 lines with `|` (header + separator + at least 3 tasks), OR check if create-tasks.md timestamp is >5 minutes old, OR just ask the user.

**Recommendation**: Increase minimum to 5 lines OR add explicit user confirmation in ambiguous cases.

---

## Medium Issues

### M1: create-tasks.md missing corrupted state.json handling
**File**: `taskie/actions/create-tasks.md:32-44`
**Severity**: Medium

Lines 32-44 instruct reading existing state.json to preserve max_reviews and tdd, but there's no error handling if state.json is corrupted or invalid JSON. The jq command will fail, and the action provides no guidance on what Claude should do.

**Cross-reference**: continue-plan.md (line 12) explicitly handles corrupted state.json: "If it exists but is CORRUPTED or invalid JSON: Restore from git history... or manually recreate with sane defaults."

**Recommendation**: Add similar error handling instructions to create-tasks.md: "If state.json contains invalid JSON, restore from git history or prompt user for max_reviews and tdd values before proceeding."

---

### M2: new-plan.md missing note about phase vs next_phase semantics
**File**: `taskie/actions/new-plan.md:21-22`
**Severity**: Medium

Lines 21-22 show:
```json
"phase": "new-plan",
"next_phase": "plan-review",
```

But nowhere does new-plan.md explain WHY phase is set to the current action and next_phase to the next action. This semantic is crucial for understanding the state machine, yet it's completely implicit.

**Recommendation**: Add explanatory note after the JSON: "Note: `phase` records the action that LAST modified state.json (i.e., this action). `next_phase` specifies which action the hook should trigger next (i.e., plan-review will run automatically when you stop)."

---

### M3: continue-plan.md recovery heuristic priority is ambiguous
**File**: `taskie/actions/continue-plan.md:29-59`
**Severity**: Medium

The crash recovery section (lines 29-59) describes multiple checks for each review phase:
1. Check if phase field indicates post-review
2. Check artifact completeness
3. Route based on result

But the text uses numbered sub-steps (1., 2., 3.) that make it unclear whether these are sequential checks (if #1 fails, try #2) or alternatives (try either #1 or #2). The word "heuristic" suggests trial-and-error, but the implementation should be deterministic.

**Recommendation**: Add explicit control flow: "For each review phase, execute checks in order. Stop at the first matching condition and execute its action. If no conditions match, proceed to the catch-all case."

---

## Minor Issues

### I1: create-tasks.md comment in bash example is misleading
**File**: `taskie/actions/create-tasks.md:46`
**Severity**: Minor

Line 46 states:
```bash
# Example bash command for atomic write (note: max_reviews and tdd are preserved automatically by jq since they're not listed in the pipeline):
```

The parenthetical comment is technically correct but pedagogically confusing. It's not that jq "automatically preserves" fields - it's that the jq filter explicitly preserves all fields by reading from state.json as input and only overwriting specific fields with `| .field = $value`.

**Recommendation**: Reword to: "Example bash command for atomic write. The jq pipeline reads existing state.json and only overwrites specified fields, leaving max_reviews and tdd unchanged:"

---

### I2: continue-plan.md uses inconsistent quotation for task status values
**File**: `taskie/actions/continue-plan.md:55`
**Severity**: Minor

Line 55 shows:
```markdown
active_count = tasks with status "pending" or "done" (exclude "cancelled", "postponed")
```

The quotation marks are inconsistent - sometimes double quotes around status values, sometimes not. While this doesn't affect functionality, it reduces readability.

**Recommendation**: Use consistent formatting: `status is "pending"`, `status is "done"`, `status is "cancelled"`, `status is "postponed"`.

---

## Positive Observations

1. **Atomic write pattern is well-documented** in create-tasks.md (lines 46-58). The example is complete and correct.

2. **Crash recovery design is comprehensive**. The two-level heuristic approach (check phase, then check artifacts) is a solid engineering decision that handles most edge cases.

3. **Clear delineation between stateful and stateless paths**. The continue-plan.md file cleanly separates state-based routing (Step 2) from git-based fallback (Step 3), making it easy to understand the dual-mode behavior.

4. **Ground-rules reference added** to create-tasks.md (line 3) as specified in subtask 4.3 acceptance criteria. This ensures consistency across actions.

5. **Escape hatch documented** in new-plan.md (line 32). The note about setting `next_phase: null` gives users a way to break out of automation if needed.

---

## Test Coverage Gaps

1. **No tests for action file instructions**. The task 4 acceptance criteria state "Manual verification only", but there should be at least integration tests that verify state.json is written with correct field values after running each action.

2. **Crash recovery heuristics are untested**. The complex logic in continue-plan.md lines 29-59 has no corresponding test cases. These are HIGH-RISK code paths that will only trigger in error scenarios.

3. **Atomic write pattern is not verified**. While create-tasks.md shows the pattern, there's no test that verifies the temp file approach prevents corruption if Claude crashes mid-write.

---

## Recommendations Summary

1. **Critical**: Remove all bash code examples from action files and replace with English instructions (C1)
2. **Critical**: Specify exact subtask completion matching logic (C2)
3. **Critical**: Fix file existence check ordering in crash recovery (C3)
4. **Critical**: Add atomic write example to new-plan.md (C4)
5. **Critical**: Fix directory context in create-tasks.md bash example (C5)
6. **Critical**: Correct completion percentage threshold to 100% or document 90% as heuristic (C6)
7. **Critical**: Change all-code-review heuristic from percentage to pending count (C7)
8. **Critical**: Increase tasks-review line count threshold (C8)
9. **Medium**: Add corrupted state.json handling to create-tasks.md (M1)
10. **Medium**: Document phase/next_phase semantics in new-plan.md (M2)
11. **Medium**: Clarify crash recovery control flow (M3)
12. **Minor**: Improve bash comment clarity (I1)
13. **Minor**: Use consistent quotation style (I2)

---

## Conclusion

Task 4 introduces a sophisticated state-based routing system with crash recovery heuristics. However, **the implementation mixes concerns** (prompt instructions vs executable code), **uses ambiguous thresholds** (90% completion, 3-line minimum), and **lacks critical error handling** (corrupted state, missing files).

The issues are fixable, but they represent fundamental design flaws that could cause production failures. The task should not be considered complete until these critical issues are resolved and proper test coverage is added.

**Estimated rework**: 4-6 hours to address all critical issues and add basic test coverage.
