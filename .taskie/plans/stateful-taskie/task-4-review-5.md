# Task 4 Review 5: Comprehensive Analysis of Planning Action Files

**Reviewer**: Claude Sonnet 4.5
**Date**: 2026-02-08
**Scope**: Task 4 - Planning action files (new-plan.md, continue-plan.md, create-tasks.md)
**Review Focus**: Final verification, edge cases, consistency, security, correctness

---

## EXECUTIVE SUMMARY

**Verdict**: **PASS** ✅

All critical issues from previous reviews have been addressed. The implementation is solid, well-documented, and handles edge cases appropriately. A few minor issues remain but they are cosmetic or involve extremely low-probability edge cases.

**Issues Found**:
- **CRITICAL**: 0
- **MEDIUM**: 1
- **MINOR**: 3
- **TRIVIAL/COSMETIC**: 2

---

## CRITICAL ISSUES

None found. ✅

---

## MEDIUM SEVERITY ISSUES

### Issue 4.M1: continue-plan.md code-review crash recovery subtask counting is complex and error-prone

**File**: `taskie/actions/continue-plan.md:46-51`
**Severity**: MEDIUM
**Type**: Implementation complexity

**Description**: The crash recovery heuristic for `code-review` phase requires counting subtasks and calculating completion percentage with several edge cases. The algorithm is described in prose, leaving implementation to the agent:

```
3. If task file exists, count subtasks: completed_count = subtasks with status exactly "completed";
   total_count = all subtasks regardless of status.
   Calculate completion_pct = (completed_count / total_count) * 100.
4. Route based on completion percentage:
   - If completion_pct ≥ 90% → Assume task is done, execute code-review.md
   - If 50% < completion_pct < 90% → Assume task in progress, execute continue-task.md
   - If completion_pct ≤ 50% OR calculation is ambiguous → INFORM USER and ASK
```

**Edge cases to consider**:
1. **Zero subtasks**: Division by zero. Covered by "OR calculation is ambiguous" but could be more explicit
2. **Status field variations**: What if status has extra whitespace (`**Status**:  completed  `)? Case sensitivity?
3. **Missing Status field**: Should these subtasks be counted in total?
4. **Malformed task file**: What if the file is corrupted and doesn't parse correctly?

**Current mitigation**: The "OR calculation is ambiguous" escape hatch handles most of these by asking the user. The percentages are conservative (90% threshold for done, 50% threshold for continue).

**Recommendation**: Add explicit note that edge cases (zero subtasks, malformed files, unparseable status) all fall into the "ambiguous" category and trigger user prompt. Currently implicit but should be explicit for clarity.

**Impact**: LOW - The current design is defensive and asks the user when uncertain. The worst case is an unnecessary user prompt, which is acceptable for a crash recovery heuristic.

**Suggested fix**:
```markdown
4. Route based on completion percentage:
   - If completion_pct ≥ 90% → Assume task is done, execute code-review.md
   - If 50% < completion_pct < 90% → Assume task in progress, execute continue-task.md
   - If completion_pct ≤ 50% OR calculation is ambiguous (zero subtasks, malformed file, unparseable status values) → INFORM USER of the ambiguity and ASK whether to continue implementation or start review
```

---

## MINOR ISSUES

### Issue 4.m1: new-plan.md doesn't specify what plan directory name to use

**File**: `taskie/actions/new-plan.md:5-6`
**Severity**: MINOR
**Type**: Documentation gap

**Description**: The action refers to `{current-plan-dir}` throughout but never explains how to choose this directory name. Should it be based on the plan title? A timestamp? User preference?

**Current text**:
```
The implementation plan MUST have its own subdirectory under `.taskie/plans`.

The implementation plan MUST be written down into a Markdown file in the `.taskie/plans/{current-plan-dir}`. The file MUST be titled `plan.md`.
```

**Impact**: The agent will have to infer an appropriate name. This usually works fine (agents tend to use descriptive kebab-case names), but explicit guidance would be better.

**Recommendation**: Add a note about directory naming:
```
The implementation plan MUST have its own subdirectory under `.taskie/plans`. Use a descriptive kebab-case name based on the plan's purpose (e.g., `stateful-taskie`, `api-refactor`, `add-auth`).
```

---

### Issue 4.m2: continue-plan.md all-code-review threshold is different from code-review

**File**: `taskie/actions/continue-plan.md:55-58`
**Severity**: MINOR
**Type**: Inconsistency

**Description**: For `all-code-review` crash recovery, the done threshold is 90% (same as `code-review`), but there's no intermediate threshold like `code-review` has (50%-90% → continue). This means if 89% of tasks are done, it will ask the user instead of routing to continue.

**Current logic for all-code-review**:
```
3. Route based on done percentage:
   - If done_pct ≥ 90% → Assume ready for review, execute all-code-review.md
   - If done_pct < 90% OR calculation is ambiguous → INFORM USER that X out of Y tasks are done and ASK whether to continue implementation or start review anyway
```

**Comparison with code-review logic**:
```
4. Route based on completion percentage:
   - If completion_pct ≥ 90% → code-review
   - If 50% < completion_pct < 90% → continue-task
   - If completion_pct ≤ 50% OR ambiguous → ASK USER
```

**Issue**: For all-code-review, 89% done → asks user. For code-review, 89% done → continues task. This asymmetry might be intentional (no "continue all tasks" action exists), but it's worth noting.

**Impact**: VERY LOW - This is likely intentional. All-code-review happens at plan level, not task level, so there's no equivalent to "continue-task". Asking the user at 89% is reasonable.

**Verdict**: This might be intentional, but worth documenting the asymmetry.

---

### Issue 4.m3: create-tasks.md example hardcodes field order

**File**: `taskie/actions/create-tasks.md:46-58`
**Severity**: MINOR
**Type**: Cosmetic

**Description**: The jq example constructs state.json field by field in a specific order, but JSON objects are unordered. This doesn't affect functionality but might mislead agents into thinking field order matters.

**Current example**:
```bash
jq --arg phase "create-tasks" \
   --argjson current_task null \
   --arg next_phase "tasks-review" \
   --argjson phase_iteration 0 \
   --arg review_model "opus" \
   --argjson consecutive_clean 0 \
   '.phase = $phase | .current_task = $current_task | .next_phase = $next_phase | .phase_iteration = $phase_iteration | .review_model = $review_model | .consecutive_clean = $consecutive_clean' \
   state.json > "$TEMP_STATE"
```

**Impact**: NONE - JSON parsers don't care about field order. This is purely cosmetic.

**Recommendation**: No change needed. Field order consistency across examples actually helps readability.

---

## TRIVIAL / COSMETIC ISSUES

### Issue 4.t1: Inconsistent path notation

**File**: Multiple files
**Severity**: TRIVIAL
**Type**: Cosmetic

**Description**: Some actions use `@${CLAUDE_PLUGIN_ROOT}/actions/foo.md` while others just say "execute foo.md". Inconsistent notation for action references.

**Examples**:
- continue-plan.md line 24: `Execute @${CLAUDE_PLUGIN_ROOT}/actions/post-plan-review.md`
- continue-plan.md line 91: `execute action @${CLAUDE_PLUGIN_ROOT}/actions/continue-task.md`

Both work fine, just minor stylistic inconsistency.

**Impact**: NONE

**Verdict**: COSMETIC ONLY, not worth fixing.

---

### Issue 4.t2: new-plan.md says "escape hatch" but doesn't explain what it escapes FROM

**File**: `taskie/actions/new-plan.md:32`
**Severity**: TRIVIAL
**Type**: Documentation clarity

**Description**: Line 32 says "If you need to escape the automated cycle, set `next_phase: null`" but this is in the context of new-plan, which is the FIRST action in a plan. What cycle are we escaping from? The plan hasn't started yet.

**Context**: Line 32:
```
**Note**: The automated review cycle begins immediately after the plan is created. The hook will trigger `plan-review` when you stop. If you need to escape the automated cycle, set `next_phase: null` in `state.json`.
```

**Analysis**: The note is accurate - the review cycle DOES begin immediately after new-plan. The "escape" refers to stopping the automation before the first review. This is clear on second reading but could be worded better.

**Impact**: NONE - The note is technically correct, just slightly confusing on first read.

**Recommendation**: Rephrase slightly:
```
**Note**: The automated review cycle begins immediately after the plan is created. The hook will trigger `plan-review` when you stop. To disable this automation, set `next_phase: null` in `state.json`.
```

---

## POSITIVE OBSERVATIONS

### ✅ Excellent error handling

All three actions handle edge cases defensively:
- `new-plan.md`: Initializes state from scratch with all required fields
- `continue-plan.md`: Comprehensive crash recovery with multi-level heuristics, fallback to git history
- `create-tasks.md`: Read-modify-write pattern preserves existing state

### ✅ Atomic writes

All state.json updates use the temp file + mv pattern to prevent corruption. Example from create-tasks.md:
```bash
TEMP_STATE=$(mktemp)
jq ... state.json > "$TEMP_STATE"
mv "$TEMP_STATE" state.json
```

### ✅ Clear separation of automated vs standalone modes

The distinction between `next_phase` for automation and `next_phase: null` for standalone is well-documented and consistently applied.

### ✅ Backwards compatibility

`continue-plan.md` gracefully falls back to git-based routing when state.json doesn't exist, maintaining compatibility with pre-stateful plans.

### ✅ Directory setup

`new-plan.md` now explicitly mentions creating the plan directory with `mkdir -p`, addressing previous review feedback.

---

## ACCEPTANCE CRITERIA VERIFICATION

Checking all acceptance criteria from task-4.md:

### Subtask 4.1: new-plan.md
- ✅ Instructs agent to create state.json with all 8 fields
- ✅ All default values match plan schema
- ✅ State constructed from scratch (not read-modify-write)
- ✅ Note about automated review cycle present (line 32)
- ✅ Note about escape hatch present (line 32)

### Subtask 4.2: continue-plan.md
- ✅ Reads state.json as first step (line 9)
- ✅ Routes correctly for all next_phase values
- ✅ Delegates to complete-task/complete-task-tdd (lines 62-63)
- ✅ Two-level crash recovery heuristic implemented (lines 34-59)
- ✅ Catch-all for next_phase: null with review phases (lines 77-80)
- ✅ Falls back to git history when state.json missing (line 84)
- ✅ Handles next_phase: "complete" (lines 64-68)
- ✅ Routes correctly for both complete-task variants

### Subtask 4.3: create-tasks.md
- ✅ Uses read-modify-write pattern (line 33)
- ✅ Sets phase, current_task, next_phase, phase_iteration, review_model, consecutive_clean
- ✅ Preserves max_reviews and tdd (line 42)
- ✅ Always sets next_phase: "tasks-review" (line 37)
- ✅ Ground-rules reference added (line 3)
- ✅ Uses atomic write pattern (lines 47-57)

**All acceptance criteria PASSED.** ✅

---

## MUST-RUN COMMANDS

Task files specify "N/A (prompt file, no executable code)" for all subtasks.

Manual verification would involve:
1. Running `/taskie:new-plan` and checking state.json initialization
2. Running `/taskie:continue-plan` in various state.json configurations
3. Running `/taskie:create-tasks` and verifying state update

These cannot be automated but should be tested manually before release.

---

## RECOMMENDATIONS

### Priority 1 (Optional - Quality improvement)
- **4.M1**: Add explicit note that edge cases in subtask counting fall into "ambiguous" category

### Priority 2 (Optional - Documentation clarity)
- **4.m1**: Add guidance on plan directory naming conventions
- **4.t2**: Rephrase "escape hatch" note for clarity

### Not recommended
- **4.m2**: Document asymmetry between code-review and all-code-review thresholds (likely intentional)
- **4.m3**: Leave example field order as-is (consistency aids readability)
- **4.t1**: Leave path notation as-is (both forms work fine)

---

## FINAL VERDICT

**PASS** ✅

Task 4 implementation is **production-ready**. All critical and high-severity issues from previous reviews have been resolved. The remaining issues are minor documentation improvements that would be nice-to-have but are not blockers.

The code demonstrates:
- Robust error handling
- Defensive programming
- Clear documentation
- Backwards compatibility
- Atomic state updates

**Recommendation**: Accept as-is. The minor issues can be addressed in future iterations if needed, but they do not affect correctness or safety.

---

**Review completed**: 2026-02-08
**Next step**: Proceed to Task 5 review
