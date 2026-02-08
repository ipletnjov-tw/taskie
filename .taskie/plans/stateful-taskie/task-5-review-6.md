# Task 5 Code Review 6

**Reviewer**: Claude Sonnet 4.5
**Date**: 2026-02-08
**Scope**: All changes to task & review action files

## Executive Summary

**Verdict**: **FAIL** - 6 critical issues, 4 medium issues, 3 minor issues found

This review examines ALL code changes in Task 5 from commit a619021, covering 13 action files: next-task.md, next-task-tdd.md, complete-task.md, complete-task-tdd.md, continue-task.md, add-task.md, and all 8 review/post-review actions. While the overall architecture is sound, there are critical inconsistencies between the 4 TDD/non-TDD variants, dangerous edge cases in the review actions, and missing validation logic that could lead to state corruption.

---

## Critical Issues

### C1: complete-task.md and complete-task-tdd.md have NO implementation instructions
**Files**: `taskie/actions/complete-task.md:17-27`, `complete-task-tdd.md:17-36`
**Severity**: Critical

Subtask 5.2 acceptance criteria (task-5.md lines 38-39) state:
```markdown
- Both files contain their OWN implementation instructions (no delegation to `next-task`)
- Implementation instructions are inlined (~10 lines of task implementation steps)
```

But the actual files show:

**complete-task.md** (lines 17-27):
```markdown
## Step 2: Implement the task

Implement the selected task, including ALL of its subtasks...

1. Read the task file...
2. Implement each subtask according to its acceptance criteria
3. Run all must-run commands specified in each subtask
4. Document your progress with a short summary in the task file
5. Update the status and git commit hash of each subtask
6. Update the task status in `tasks.md` to "done"
7. Commit your changes with an appropriate commit message
8. Push to remote
```

This is GENERIC guidance, not "inlined implementation instructions." Compare with next-task.md (lines 3-9) which has almost identical wording. The acceptance criteria expected approximately 10 lines of SPECIFIC implementation steps like:
- "For each subtask in task-{id}.md..."
- "Write code to satisfy acceptance criteria..."
- "Run must-run commands and verify output..."

Instead, what we got is high-level process description that could apply to ANY task implementation action.

**complete-task-tdd.md** does better (lines 17-36) by including the RED-GREEN-REFACTOR cycle, but it's still not "inlined implementation instructions" - it's a methodology description.

**Root cause**: Misunderstanding of "inline" in the context of prompt engineering. The task specification meant "copy the implementation steps from next-task into complete-task so Claude doesn't need to delegate," not "write a summary of the process."

**Recommendation**: Add explicit task implementation workflow:
```markdown
1. cd to .taskie/plans/{current-plan-dir}
2. Read tasks.md and identify first task with status="pending"
3. Read task-{id}.md to understand requirements
4. For each subtask:
   - Identify files that need changes
   - Make necessary code changes
   - Run must-run commands
   - Verify acceptance criteria are met
   - Update subtask status to "completed"
   - Record git commit hash
5. Update task status in tasks.md to "done"
6. git add, commit, and push changes
```

---

### C2: Review actions detect standalone vs automated using wrong logic
**Files**: All 4 review actions (code-review.md:18-28, plan-review.md:16-26, tasks-review.md:16-26, all-code-review.md:17-27)
**Severity**: Critical

The pattern used in all review actions (example from code-review.md lines 18-28):

```markdown
1. Read `.taskie/plans/{current-plan-dir}/state.json`
2. Check the `phase_iteration` field:
   - **If `phase_iteration` is null or doesn't exist**: This is a STANDALONE review
     - Update `state.json` with:
       - `phase`: `"code-review"`
       - `next_phase`: `null`
       - `phase_iteration`: `null` (marks standalone mode)
   - **If `phase_iteration` is non-null (a number)**: This is an AUTOMATED review
     - DO NOT update `state.json` - the hook manages the state for automated reviews
```

This logic has a **fatal flaw**: It assumes phase_iteration distinguishes between standalone and automated modes, but this is NOT guaranteed:

**Counter-example**:
1. User runs `/taskie:complete-task`, which sets `phase_iteration: 0` and `next_phase: "code-review"`
2. Hook triggers code-review, increments phase_iteration to 1, runs review
3. Review calls the action file code-review.md
4. Action sees `phase_iteration: 1` (non-null), assumes it's automated
5. Action does NOT update state.json
6. Hook is expecting the action to update state, but it doesn't!

The issue: **The action can't reliably detect if it was invoked by the hook or manually**. phase_iteration being non-null could mean:
- Hook invoked it (automated)
- User invoked it after complete-task set phase_iteration to 0 (manual on automated state)
- User invoked it mid-cycle (edge case)

**Correct detection method**: The action should check BOTH `phase_iteration` AND `phase`:
- If `phase == "{review-type}"` AND `phase_iteration` is non-null → Automated (hook already updated state before invoking action)
- Otherwise → Standalone (action needs to update state)

But wait - the hook doesn't update phase BEFORE invoking the action. Looking at stop-hook.sh lines 251-267, the hook only updates state AFTER determining auto-advance or blocking. So the action's state update is NEVER used in automated mode.

**Actually, the current logic is correct for the CURRENT hook implementation**, but it's fragile because it relies on implicit ordering: hook increments phase_iteration → hook invokes action → action sees non-null iteration → action skips state update → hook updates state after getting verdict.

The critical issue is **lack of explicit documentation** explaining this calling convention. If someone changes the hook to update state before invoking the action, all review actions will break.

**Recommendation**: Add comment in each review action explaining the calling convention: "The hook increments phase_iteration before invoking this action. We detect automated mode by checking if phase_iteration is non-null. In automated mode, we skip state updates because the hook will update state after parsing our verdict. In standalone mode, we update state ourselves."

---

### C3: Post-review actions have inconsistent state update patterns
**Files**: All 4 post-review actions
**Severity**: Critical

The bash examples in post-review actions show TWO different update patterns:

**Pattern 1** (post-code-review.md lines 25-29):
```bash
TEMP_STATE=$(mktemp)
jq '.phase = "post-code-review" | .next_phase = "code-review"' state.json > "$TEMP_STATE"
mv "$TEMP_STATE" state.json
```

**Pattern 2** (post-code-review.md lines 37-41):
```bash
TEMP_STATE=$(mktemp)
jq --argjson next_phase null '.phase = "post-code-review" | .next_phase = $next_phase' state.json > "$TEMP_STATE"
mv "$TEMP_STATE" state.json
```

Pattern 1 uses a string literal `"code-review"`. Pattern 2 uses `--argjson` with a variable. The ONLY difference is that Pattern 2 needs to pass a JSON null value, which requires --argjson.

But why use different patterns at all? This creates cognitive load for readers who have to understand TWO ways to do the same thing.

**More critically**: Neither pattern explicitly preserves other state fields. Both rely on jq's default behavior of passing through unmodified fields, which is correct but implicit. If someone adds a new field to state.json in the future, these patterns will automatically preserve it, which is GOOD. But if someone mistakes jq's behavior for "create new object with only these fields," they could write broken updates.

**Recommendation**: Standardize on ONE pattern for all state updates, add comment explaining field preservation:
```bash
# Update state.json while preserving all other fields
TEMP_STATE=$(mktemp)
jq '.phase = "post-code-review" | .next_phase = "code-review"' state.json > "$TEMP_STATE"
mv "$TEMP_STATE" state.json
```

For null values, use:
```bash
jq '.phase = "post-code-review" | .next_phase = null' state.json > "$TEMP_STATE"
```

No need for `--argjson` unless the value comes from a shell variable.

---

### C4: complete-task.md doesn't handle "no pending tasks" edge case correctly
**File**: `taskie/actions/complete-task.md:11`
**Severity**: Critical

Line 11 states:
```markdown
**If no pending tasks exist**: Inform the user that all tasks are complete. Set `phase: "complete"` and `next_phase: null` in state.json, then stop. Do not attempt to implement a non-existent task.
```

This is correct behavior, but it's incomplete. The action should ALSO check:
1. What if tasks.md doesn't exist at all?
2. What if tasks.md exists but is malformed (no pipe separators)?
3. What if multiple tasks have status "pending" but the user wants to implement a specific one, not the first?

The "select next task" logic (line 9) says "identify the first task with status 'pending'", which is deterministic but inflexible. In a real workflow, a user might want to implement tasks out of order (e.g., task 3 before task 2 if task 2 is blocked).

**Recommendation**: Add error handling for malformed tasks.md, and add optional task ID parameter: "If user specifies a task ID (e.g., `/taskie:complete-task 3`), implement that specific task. Otherwise, implement the first pending task by ID."

---

### C5: continue-task.md transparency claim is misleading
**File**: `taskie/actions/continue-task.md:16`
**Severity**: Critical

Line 16 claims:
```markdown
This action is transparent - it preserves the workflow state. Whether you're in an automated review cycle (`next_phase` is a review phase) or standalone mode (`next_phase` is null), the state remains unchanged except for marking that you continued the task.
```

But "transparent" is misleading because the action DOES modify state - it sets `phase: "continue-task"`. While it preserves next_phase (which is the key claim), it's not "unchanged except for marking" - it actively OVERWRITES the phase field.

This matters because if `phase: "post-code-review"` before continue-task, and continue-task sets `phase: "continue-task"`, we've lost information about what the user was doing before. If they crash and run `/taskie:continue-plan`, the crash recovery logic won't know they were in the middle of post-review fixes.

**Recommendation**: Either:
1. Change wording to "This action preserves next_phase but updates phase to 'continue-task' for tracking purposes"
2. OR preserve phase as well and only update a last_action field (requires schema change)

---

### C6: next-task.md and next-task-tdd.md set phase_iteration to null instead of preserving it
**File**: `taskie/actions/next-task.md:18`, `next-task-tdd.md:30`
**Severity**: Critical

Both files state:
```markdown
- `phase_iteration`: `null` (not in a review cycle)
- Preserve all other fields: `max_reviews`, `review_model`, `consecutive_clean`, `tdd`
```

This is correct for the documented behavior (standalone mode), but it DESTROYS information if the user runs next-task while in an automated cycle. For example:

1. User is in automated code-review cycle (phase_iteration: 3)
2. User manually runs `/taskie:next-task` to skip to the next task
3. next-task.md sets phase_iteration: null
4. User runs `/taskie:continue-plan`
5. continue-plan sees next_phase: null and phase_iteration: null → routes to standalone mode
6. Lost tracking of the review cycle iteration count

While this might be intended behavior (escaping automation), it should be EXPLICIT. The action should say: "Setting phase_iteration to null will exit any active automated review cycle. If you want to stay in automation, use complete-task instead."

**Recommendation**: Add warning note about escaping automation when setting phase_iteration to null.

---

## Medium Issues

### M1: complete-task.md example bash command has wrong variable name
**File**: `taskie/actions/complete-task.md:44-60`
**Severity**: Medium

Line 46 shows:
```bash
TASK_ID="3"  # Replace with actual task ID from Step 1
```

But the action never tells Claude to SET this variable. The example assumes Claude will know to extract the task ID from Step 1 and assign it to TASK_ID before running the jq command. This is probably obvious to experienced developers, but it's an implicit step that could be missed.

**Recommendation**: Add explicit step in the action: "After selecting the task in Step 1, set TASK_ID shell variable to the selected task ID before running the state.json update command."

---

### M2: Review file naming logic is duplicated across 4 files
**Files**: All 4 review actions (lines 9-11 in each)
**Severity**: Medium

The review file naming instructions are identical in all 4 review actions:
```markdown
**Review file naming**:
- For AUTOMATED reviews (invoked by hook): use the `phase_iteration` value from state.json as the iteration number
- For STANDALONE reviews (manual invocation): use max(existing iteration numbers) + 1 from existing review files in the directory
```

This is good documentation, but it's DUPLICATED 4 times. If the naming convention changes, all 4 files must be updated in sync. This violates DRY principle.

**Recommendation**: Move this to ground-rules.md as a shared convention, then reference it from each review action: "Follow the review file naming convention documented in ground-rules.md."

---

### M3: add-task.md doesn't validate that state.json exists
**File**: `taskie/actions/add-task.md:30-37`
**Severity**: Medium

The action (lines 30-37) instructs reading state.json and conditionally setting current_task, but it doesn't handle the case where state.json doesn't exist yet. This could happen if:
1. User creates a plan manually (not using /taskie:new-plan)
2. User runs /taskie:add-task before running any other actions
3. Action tries to read non-existent state.json → jq fails

**Recommendation**: Add check: "If state.json doesn't exist, create it with default values before updating current_task field."

---

### M4: complete-task-tdd.md claims both variants use the same Step 4, but they don't
**Files**: `complete-task.md:62-74`, `complete-task-tdd.md:72-84`
**Severity**: Medium

Both files have "Step 4: Stop and let automation take over" sections that are ALMOST identical, except:

**complete-task.md line 78**:
```markdown
3. If reviews pass (2 consecutive clean reviews), the workflow auto-advances to the next task
```

**complete-task-tdd.md line 78**:
```markdown
3. If reviews pass (2 consecutive clean reviews), the workflow auto-advances to the next task (using `complete-task-tdd` since `tdd: true`)
```

The TDD variant adds a clarification about which action will be used for the next task. This is valuable information, but it raises the question: why doesn't the non-TDD variant have the same clarification? It should say "(using `complete-task` since `tdd: false`)".

**Recommendation**: Add symmetrical clarification to both variants for consistency.

---

## Minor Issues

### I1: Inconsistent terminology for "implementation steps"
**Files**: Multiple
**Severity**: Minor

Some actions say "implement the task" (complete-task.md), others say "implement the selected task" (complete-task-tdd.md), and others say "start implementing the first task" (next-task.md). While semantically equivalent, the inconsistency creates cognitive friction when comparing files.

**Recommendation**: Standardize on "Implement the task" across all task implementation actions.

---

### I2: add-task.md is the only action without a ground-rules reference
**File**: `taskie/actions/add-task.md`
**Severity**: Minor

All other actions start with or include "You MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times." But add-task.md is missing this line (except at the very end, line 39).

The closing reminder (line 39) is present, but the opening statement is missing. Most other actions have it at both the beginning and end for emphasis.

**Recommendation**: Add ground-rules reference at the start of add-task.md for consistency.

---

### I3: Post-review documentation filename pattern inconsistency
**Files**: All post-review actions
**Severity**: Minor

The post-review actions document their output files as:
- `code-post-review-{iteration}.md` (post-code-review.md line 7)
- `plan-post-review-{iteration}.md` (post-plan-review.md line 9)
- etc.

But the file pattern uses "post-review" as a suffix to the artifact type, while the action NAME uses "post-{review-type}" as a prefix. This creates:
- Action: `post-code-review`
- Output: `code-post-review-{iteration}.md`

This is confusing. Why isn't the output file named `post-code-review-{iteration}.md` to match the action name?

**Recommendation**: Either rename actions to `{type}-post-review` OR rename output files to `post-{type}-review-{iteration}.md`. Prefer the second option for consistency with action names.

---

## Positive Observations

1. **Consistent state update pattern across task implementation actions**. All task actions (next-task, complete-task, continue-task) use read-modify-write with atomic writes. Good engineering.

2. **Automated vs standalone detection is cleanly documented**. While the implementation has issues (C2), the INTENT is clear in all review and post-review actions.

3. **TDD variant properly documents RED-GREEN-REFACTOR cycle**. complete-task-tdd.md lines 19-28 provide clear, actionable TDD instructions.

4. **Explicit "do not delegate" constraint in complete-task variants**. Subtask 5.2 acceptance criteria specified removing delegation to next-task, and the implementation correctly inlines all instructions (even if they could be more specific per C1).

5. **Escape hatch documented in complete-task actions**. Lines 72 in both variants mention "To escape the automated cycle at any point, set `next_phase: null`" - this is critical for user control.

---

## Test Coverage Gaps

1. **No tests for review/post-review state update logic**. The conditional state updates based on phase_iteration are complex and error-prone, yet completely untested.

2. **No tests for edge cases in task selection**. What happens if tasks.md is empty? Malformed? Multiple pending tasks? complete-task.md handles these in prose, but without tests.

3. **No tests for TDD vs non-TDD state transitions**. The `tdd` field affects routing in complete-task variants, but there are no tests verifying the correct complete-task-* action is used for the next task.

4. **No tests for review file naming**. The automated vs standalone review file naming logic (phase_iteration vs max+1) is untested.

---

## Recommendations Summary

1. **Critical**: Add explicit implementation workflow to complete-task variants (C1)
2. **Critical**: Document review action calling convention for standalone vs automated detection (C2)
3. **Critical**: Standardize state update patterns across all post-review actions (C3)
4. **Critical**: Add error handling for malformed tasks.md in complete-task (C4)
5. **Critical**: Clarify "transparent" claim in continue-task (C5)
6. **Critical**: Warn about escaping automation when setting phase_iteration to null (C6)
7. **Medium**: Add explicit TASK_ID variable assignment step (M1)
8. **Medium**: Move review file naming convention to ground-rules.md (M2)
9. **Medium**: Add state.json existence check to add-task (M3)
10. **Medium**: Add symmetrical clarification to non-TDD variant about next action (M4)
11. **Minor**: Standardize terminology for "implement" (I1)
12. **Minor**: Add ground-rules reference at start of add-task (I2)
13. **Minor**: Rename output files to match action names (I3)

---

## Cross-Task Integration Issues

### Integration Issue 1: complete-task relies on continue-plan routing that's broken
**Files**: `complete-task.md`, `continue-plan.md`
**Severity**: Critical (cross-task)

complete-task.md (lines 62-64) states:
```markdown
1. The hook will trigger `code-review` automatically
2. Reviews will alternate between opus and sonnet models
3. If reviews pass (2 consecutive clean reviews), the workflow auto-advances to the next task
```

But "auto-advances to the next task" depends on the hook's advance target logic, which is implemented in stop-hook.sh. Looking at task-4's continue-plan.md (lines 228-244), the hook checks if more tasks remain and routes accordingly.

However, the hook's TASKS_REMAIN calculation (stop-hook.sh line 230) uses a complex awk script that may not match complete-task's task selection logic (complete-task.md line 9 "first task with status 'pending'").

**Specific conflict**:
- complete-task selects "first task with status pending BY ASCENDING ID"
- hook's TASKS_REMAIN counts "tasks with status pending EXCLUDING current task"
- If tasks are out of order (task 1 done, task 3 pending, task 2 pending, current=1), complete-task will select task 2, but hook will count 2 pending tasks

**Recommendation**: Align task selection logic between complete-task and hook's TASKS_REMAIN calculation. Document the algorithm in ground-rules.md as the canonical implementation.

### Integration Issue 2: Review actions assume state.json always exists
**Files**: All review and post-review actions
**Severity**: Medium (cross-task)

All review actions (lines 17-18 of each) start with:
```markdown
1. Read `.taskie/plans/{current-plan-dir}/state.json`
2. Check the `phase_iteration` field:
```

But what if state.json doesn't exist? This can happen if:
1. User is working on a plan created before the stateful workflow
2. User accidentally deleted state.json
3. Git merge conflict corrupted state.json

The continue-plan action (from Task 4) handles this: "If it does NOT exist: This is a plan created before the stateful workflow. Skip to Step 3 (git-based routing fallback)."

But review actions have NO such fallback. If state.json doesn't exist, the action will fail when trying to read phase_iteration.

**Recommendation**: Add fallback to all review actions: "If state.json doesn't exist, assume standalone mode and create a minimal state.json with default values before proceeding."

---

## Conclusion

Task 5 implements a comprehensive state management system across 13 action files. The architecture is sound, but the implementation has critical gaps:

1. **Documentation is too generic** - complete-task "inlined instructions" are actually high-level process descriptions (C1)
2. **State update logic is fragile** - relies on implicit hook calling conventions (C2, C3)
3. **Edge cases are unhandled** - missing tasks.md, malformed data, non-existent state.json (C4, M3, I2)
4. **Cross-task integration is untested** - dependencies on hook logic from Task 3 are not verified (I1, I2)

The issues are fixable, but several are CRITICAL because they affect the core state machine behavior. The task should not be considered complete until:
1. All critical issues are resolved
2. Integration tests verify end-to-end workflows (new-plan → create-tasks → complete-task → code-review → auto-advance)
3. Edge case handling is added and tested

**Estimated rework**: 6-8 hours to address all critical issues, add missing documentation, and create integration tests.
