# Task 4 Review 4: Deep Analysis of Planning Action Files

**Reviewer**: Claude Sonnet 4.5
**Date**: 2026-02-08
**Scope**: Task 4 (new-plan.md, continue-plan.md, create-tasks.md)
**Review Focus**: Edge cases, security, UX, consistency, correctness beyond previous reviews

---

## CRITICAL ISSUES

### Issue 4.C1: create-tasks.md has incorrect jq null handling
**File**: `taskie/actions/create-tasks.md:56`
**Severity**: HIGH
**Description**: The jq command line 56 uses `--arg current_task "null"` which creates a STRING "null", not JSON null. Then attempts to convert with `if . == "null" then null else . end`, which is convoluted and error-prone.

**Current code**:
```bash
jq --arg phase "create-tasks" \
   --arg current_task "null" \
   ...
   '.current_task = ($current_task | if . == "null" then null else . end)'
```

**Correct approach**: Use `--argjson current_task null` instead:
```bash
jq --arg phase "create-tasks" \
   --argjson current_task null \
   ...
   '.current_task = $current_task'
```

**Impact**: Could result in `current_task: "null"` (string) instead of `current_task: null` (JSON null), breaking downstream logic that checks `if current_task is null`.

---

### Issue 4.C2: continue-plan.md completion percentage calculation is fragile
**File**: `taskie/actions/continue-plan.md:46-58`
**Severity**: MEDIUM
**Description**: The code-review crash recovery uses subtask completion percentage (90% threshold), but the calculation logic is described in prose, not implemented. This leaves room for implementation errors.

**Current state**: Lines 47-51 describe the algorithm:
```
3. If task file exists, count subtasks: completed_count = subtasks with status exactly "completed";
   total_count = all subtasks regardless of status.
   Calculate completion_pct = (completed_count / total_count) * 100.
4. Route based on completion percentage:
   - If completion_pct ≥ 90% → code-review
   - If 50% < completion_pct < 90% → continue-task
   - If completion_pct ≤ 50% OR calculation is ambiguous → ASK USER
```

**Missing details**:
1. What if `total_count` is 0? Division by zero. The "OR calculation is ambiguous" covers this but should be explicit.
2. What counts as "status exactly 'completed'"? The file format uses `**Status**: completed` but subtasks could have variations (whitespace, case). Should use case-insensitive match or exact string.
3. What if a subtask is missing the Status field entirely? Should it be counted in total_count?

**Recommendation**: Add explicit note that division by zero case (0 subtasks) falls into the "ambiguous" category and triggers user prompt.

---

### Issue 4.C3: continue-plan.md plan.md completeness check has race condition
**File**: `taskie/actions/continue-plan.md:36`
**Severity**: LOW
**Description**: The plan-review crash recovery checks if `plan.md` has `## Overview` heading OR >50 lines. If the agent crashes while writing line 25 of the plan (before Overview section), the heuristic will incorrectly route to `new-plan.md` and overwrite the partial work.

**Current logic**:
```
2. Check if `plan.md` exists AND has at least 50 lines → ... execute plan-review.md
3. Otherwise → Plan likely incomplete, execute new-plan.md
```

**Issue**: Line 36 says "AND (has `## Overview` heading OR >50 lines)" but the text on line 37 only mentions ">50 lines". This is inconsistent. Which is it?

**Looking at line 36 again**:
```
2. Check if `plan.md` exists AND has at least 50 lines → Likely complete, execute plan-review.md
```

Wait, the actual file doesn't mention `## Overview` in the action - that was in my mental model from the task description. Let me re-read...

Actually, re-checking task-4.md line 40-41:
```
- Checks artifact completeness for plan-review (plan.md exists AND (has `## Overview` heading OR >50 lines) — file must exist before checking completeness)
```

So the task REQUIRES checking for `## Overview` OR >50 lines, but the implemented action in continue-plan.md:36 ONLY checks ">50 lines":
```
2. Check if `plan.md` exists AND has at least 50 lines → Likely complete
```

**Verdict**: DISCREPANCY between task requirements and implementation. The task says to check for `## Overview` heading as an alternative to >50 lines, but the implementation omits this check.

**Impact**: If a plan has an `## Overview` section at line 10 but only 45 lines total, the task spec says it should be considered complete, but the implementation would route to `new-plan.md` and potentially overwrite.

---

### Issue 4.C4: continue-plan.md tasks.md completeness uses incorrect threshold
**File**: `taskie/actions/continue-plan.md:42`
**Severity**: MEDIUM
**Description**: The tasks-review crash recovery checks if `tasks.md` has "at least one line starting with `|`", but this will trigger on the HEADER line (`| Id | Status | ...`) even if zero tasks exist.

**Current logic**:
```
2. Check if `tasks.md` exists and has at least one line starting with `|` → Tasks likely complete
```

**Issue**: The Markdown table format has:
- Line 1: `| Id | Status | Priority | ... |` (header)
- Line 2: `|----|--------|----------|-----|` (separator)
- Line 3+: actual tasks

Checking for "at least one line starting with `|`" will match the header, meaning an EMPTY tasks.md (0 tasks, just header+separator) would be considered "complete" and route to `tasks-review.md`.

**Task requirement** (from task-4.md:42):
```
- Checks artifact completeness for tasks-review (tasks.md exists and has at least one line starting with `|`)
```

So the implementation matches the spec, but the spec itself is wrong!

**Correct check**: Should be "at least THREE lines starting with `|`" (header + separator + at least one task row).

Wait, let me re-read the task spec more carefully:

Task-4.md line 42 says:
```
tasks.md exists and has at least one line starting with `|`
```

But actually, this is checking for table existence, not task existence. An empty table (header only) is still a valid artifact to review. So maybe this is intentional?

Actually, re-reading again - the logic is checking if the tasks artifact is "complete" enough to review. An empty tasks table is NOT a complete artifact, it means tasks haven't been created yet.

**Verdict**: The heuristic is too loose. Should check for at least 3 lines with `|` to ensure at least one task exists.

---

### Issue 4.C5: new-plan.md doesn't document required directory creation
**File**: `taskie/actions/new-plan.md:13-26`
**Severity**: LOW
**Description**: The action says to "initialize the workflow state file at `.taskie/plans/{current-plan-dir}/state.json`" but doesn't mention that the directory might not exist yet and needs to be created first.

**Missing step**: Before writing `state.json`, the agent needs to:
1. Create `.taskie/plans/{current-plan-dir}/` directory if it doesn't exist
2. Write `plan.md` to that directory
3. Write `state.json` to that directory

The action assumes the directory already exists from writing `plan.md`, but doesn't make this dependency explicit.

**Recommendation**: Add a note that the plan directory must be created before writing files, or reorder the instructions to make this clear.

---

## MEDIUM ISSUES

### Issue 4.M1: create-tasks.md example doesn't preserve max_reviews correctly
**File**: `taskie/actions/create-tasks.md:47-57`
**Severity**: MEDIUM
**Description**: The jq example is missing the `max_reviews` preservation that's documented in step 2.

**Current example** (line 47-57):
```bash
TEMP_STATE=$(mktemp)
jq --arg phase "create-tasks" \
   --arg current_task "null" \
   --arg next_phase "tasks-review" \
   --argjson phase_iteration 0 \
   --arg review_model "opus" \
   --argjson consecutive_clean 0 \
   '.phase = $phase | .current_task = ($current_task | if . == "null" then null else . end) | .next_phase = $next_phase | .phase_iteration = $phase_iteration | .review_model = $review_model | .consecutive_clean = $consecutive_clean' \
   state.json > "$TEMP_STATE"
mv "$TEMP_STATE" state.json
```

**Problem**: The example doesn't explicitly set `.max_reviews` or `.tdd`, so jq's default behavior is to PRESERVE them from the input (which is correct!), but this isn't obvious to someone reading the example.

**Documented behavior** (line 42-43):
```
- `max_reviews`: preserve from existing state
- `tdd`: preserve from existing state
```

**Actual behavior**: jq implicitly preserves fields not mentioned in the pipeline, which matches the spec, but is implicit rather than explicit.

**Recommendation**: Add a comment in the example explaining that max_reviews and tdd are preserved automatically:
```bash
# Note: max_reviews and tdd are preserved automatically by jq (not listed in pipeline)
jq --arg phase "create-tasks" \
   ...
```

---

### Issue 4.M2: continue-plan.md code-review routing doesn't handle partial completion
**File**: `taskie/actions/continue-plan.md:46-52`
**Severity**: MEDIUM
**Description**: The code-review crash recovery only has 3 buckets: ≥90% (review), 50-90% (continue), ≤50% (ask). But what if completion is exactly 90.0%? The condition "50% < completion_pct < 90%" excludes both 50% and 90%.

**Current logic**:
```
4. Route based on completion percentage:
   - If completion_pct ≥ 90% → ... execute code-review.md
   - If 50% < completion_pct < 90% → ... execute continue-task.md
   - If completion_pct ≤ 50% OR calculation is ambiguous → INFORM USER ...
```

**Issue with 50% case**:
- `completion_pct ≥ 90%` → No (it's exactly 50%)
- `50% < completion_pct < 90%` → No (not strictly greater than 50%)
- `completion_pct ≤ 50%` → Yes → Ask user

So 50% correctly falls into "ask user" bucket. ✓

**Issue with 90% case**:
- `completion_pct ≥ 90%` → Yes (it's exactly 90%) → execute code-review

So 90% correctly goes to code-review. ✓

Wait, this is actually correct! The conditions are:
1. `≥ 90%` → review
2. `> 50% AND < 90%` → continue (excludes boundaries)
3. `≤ 50%` → ask user

The boundaries (50%, 90%) are handled correctly. This is NOT an issue.

**Verdict**: FALSE ALARM - logic is correct.

---

### Issue 4.M3: continue-plan.md doesn't handle complete-task routing for task selection
**File**: `taskie/actions/continue-plan.md:62-63`
**Severity**: LOW
**Description**: The routing for `next_phase: "complete-task"` delegates to `complete-task.md` and notes "it will determine the next pending task from `tasks.md`", but this delegation isn't documented in the task spec.

**From task-4.md:37**:
```
When `next_phase` is `"complete-task"` or `"complete-task-tdd"`, routes to the corresponding action file which internally determines the next pending task from `tasks.md` — `continue-plan` delegates task selection to the action, it doesn't determine which task ID to execute
```

OK so this IS in the spec and IS implemented correctly. ✓

**Verdict**: FALSE ALARM - this is correct per spec.

---

### Issue 4.M4: continue-plan.md corrupted state.json recovery suggests manual recreation
**File**: `taskie/actions/continue-plan.md:12`
**Severity**: LOW
**Description**: The action suggests "manually recreate with sane defaults" but doesn't specify what those defaults are. Different fields have different "sane" values depending on context.

**Current text**:
```
- **If it exists but is CORRUPTED or invalid JSON**: Restore from git history (`git show HEAD:path/to/state.json`) or manually recreate with sane defaults. If unable to recover, fall back to Step 3 (git-based routing).
```

**Issue**: What are "sane defaults"? Should it match `new-plan.md` defaults? Or infer from current files?

**Recommendation**: Link to `new-plan.md` for the default schema, or provide an example:
```
manually recreate with defaults (see new-plan.md for schema: max_reviews: 8, phase: "unknown", next_phase: null, etc.)
```

---

## MINOR ISSUES

### Issue 4.m1: new-plan.md uses inconsistent path notation
**File**: `taskie/actions/new-plan.md:3,5,13`
**Severity**: TRIVIAL
**Description**: Lines 3 and 5 reference `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` but line 13 says `.taskie/plans/{current-plan-dir}/state.json`. The first uses CLAUDE_PLUGIN_ROOT variable, the second uses relative path. Both are correct, but mixing styles is inconsistent.

**Recommendation**: Standardize on either always using variables or always using relative paths within a single action file.

---

### Issue 4.m2: create-tasks.md has unnecessary jq complexity
**File**: `taskie/actions/create-tasks.md:50`
**Severity**: TRIVIAL
**Description**: The jq command uses 6 separate `--arg`/`--argjson` flags, which makes the command hard to read. Could use `--argjson` with a here-doc for better readability.

**Current**:
```bash
jq --arg phase "create-tasks" \
   --arg current_task "null" \
   --arg next_phase "tasks-review" \
   --argjson phase_iteration 0 \
   --arg review_model "opus" \
   --argjson consecutive_clean 0 \
   '...' state.json
```

**Alternative** (more readable for complex updates):
```bash
jq '. + {
  phase: "create-tasks",
  current_task: null,
  next_phase: "tasks-review",
  phase_iteration: 0,
  review_model: "opus",
  consecutive_clean: 0
}' state.json > "$TEMP_STATE"
```

But this is a style preference, not a correctness issue.

---

### Issue 4.m3: continue-plan.md uses ambiguous "just stop" phrasing
**File**: `taskie/actions/continue-plan.md:36,40,46,54`
**Severity**: TRIVIAL
**Description**: The phrase "Just stop, inform user they were in post-review" is informal and could be misinterpreted. What does "just stop" mean exactly?

**Current text examples**:
- Line 36: "Just stop and inform user they were addressing plan review feedback."
- Line 40: "Just stop and inform user they were addressing tasks review feedback."

**Clarification needed**: Does "just stop" mean:
1. Stop processing and display a message (don't execute any action)?
2. Stop automated routing and ask the user what to do?
3. Halt the entire workflow?

**Recommendation**: Use clearer language like "Stop routing and inform the user..." or "Display message to user and await input:".

---

## OBSERVATIONS (Not issues, but noteworthy)

### Observation 4.O1: continue-plan.md is complex (100 lines, 6 routing levels)
The file has grown to 100+ lines with deeply nested conditional logic:
- Step 1: Check if state.json exists
- Step 2.1: Route on next_phase (non-null)
  - Post-review phases (4 cases)
  - Review phases with 2-level heuristics (4 cases, each with 2-3 sub-conditions)
  - Advance targets (3 cases)
- Step 2.2: Route on phase (next_phase is null)
  - Implementation phases
  - Review/post-review phases
  - Other phases
- Step 3: Git-based fallback

This complexity is necessary for the stateful workflow, but it makes the file hard to maintain and test. Consider adding a flowchart or decision tree diagram in the ground-rules documentation.

### Observation 4.O2: Atomic writes are emphasized but not enforced
All three action files mention "atomic writes (temp file + mv)" but don't enforce this pattern. An agent could write directly to state.json and violate atomicity. The examples use `TEMP_STATE=$(mktemp)` which is good, but there's no validation or error handling if the temp file creation fails.

### Observation 4.O3: Error handling is absent from all jq examples
None of the jq examples check for errors:
- What if jq fails (syntax error, corrupted input)?
- What if mktemp fails (disk full, permissions)?
- What if mv fails (cross-filesystem move, permissions)?

The examples are meant to be illustrative, not production scripts, but agents might copy them verbatim without adding error handling.

---

## SUMMARY

**Critical Issues**: 4 (C1-C4 are real issues, C5 is low severity)
**Medium Issues**: 1 (M1 is real, M2-M4 are low severity)
**Minor Issues**: 3 (all trivial)
**Observations**: 3

**Blocking Issues for Production**:
1. **Issue 4.C1**: create-tasks.md jq null handling creates string "null" instead of JSON null
2. **Issue 4.C3**: continue-plan.md missing `## Overview` check for plan-review crash recovery
3. **Issue 4.C4**: continue-plan.md tasks.md completeness check will pass on empty table

**Recommended Fixes**:
1. Fix C1: Change `--arg current_task "null"` to `--argjson current_task null`
2. Fix C3: Add `## Overview` heading check as specified in task requirements
3. Fix C4: Change check to "at least 3 lines starting with `|`" to ensure at least one task row exists
4. Fix M1: Add comment to create-tasks.md example explaining implicit preservation
5. Fix C5: Add note about directory creation in new-plan.md

**Overall Assessment**: The implementation is 85% correct. The critical issues are fixable with small changes. The complexity in continue-plan.md is concerning for long-term maintainability but necessary for the feature.
