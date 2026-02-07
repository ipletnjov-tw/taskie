# Tasks 4 & 5 Review 1: Hyper-Critical Analysis

**Reviewer**: Self-review (Claude Sonnet 4.5)
**Date**: 2026-02-08
**Verdict**: FAIL
**Review scope**: All 17 action file updates across Tasks 4 and 5

## Executive Summary

This implementation updates all action files to support state.json workflow management. While the core structure is present, there are **CRITICAL issues** that will cause user confusion, workflow breaks, and maintenance nightmares.

## BLOCKING Issues

### B1: continue-plan.md crash recovery logic is AMBIGUOUS and FRAGILE

**Location**: `continue-plan.md` lines 31-49

**Problem**: The crash recovery heuristics are underspecified and will fail in common scenarios:

1. **plan-review crash recovery** (line 33): "has `## Overview` heading OR >50 lines" - what if the user's plan uses a different heading? What if they have a short plan with only 40 lines? This is an arbitrary heuristic that doesn't actually detect "plan completeness".

2. **code-review crash recovery** (line 43): "all subtask status markers show complete (no 'pending' or 'in-progress')" - this will incorrectly classify a task as "incomplete" if the user starts a NEW subtask after a crash. The subtask could be in the file but not yet started.

3. **all-code-review crash recovery** (line 48): "all tasks in tasks.md are marked 'done'" - what if the user is doing an all-code-review for tasks 1-3 while task 4 is still pending? This is too strict.

**Impact**: HIGH - Users will get stuck in infinite loops or incorrect routing after crashes.

**Fix required**:
- Replace arbitrary heuristics with explicit artifact markers (e.g., a comment at the end of plan.md: `<!-- PLAN_COMPLETE -->`)
- OR: Document that crash recovery is best-effort and may route incorrectly, instruct users to manually fix state.json
- OR: Remove crash recovery entirely and just inform user of the state, ask what to do

### B2: Atomic write examples are WRONG - don't handle null values correctly

**Locations**:
- `create-tasks.md` line 51
- `complete-task.md` line 44-55
- `complete-task-tdd.md` line 54-65

**Problem**: The jq examples for writing state.json have a fatal flaw:

```bash
--arg current_task "null"  # This creates the STRING "null", not JSON null
--argjson current_task null  # This would work
```

Lines like `'.current_task = ($current_task | if . == "null" then null else . end)'` are attempting to work around this, but it's convoluted and error-prone. If the user has a task literally named "null", this will break.

**Impact**: HIGH - state.json will have string "null" instead of JSON null, breaking all logic that checks `if current_task is null`.

**Fix required**: Use `--argjson` for null values consistently, remove the string->null conversion hack.

### B3: complete-task and complete-task-tdd DON'T preserve max_reviews correctly

**Locations**:
- `complete-task.md` line 30, line 52
- `complete-task-tdd.md` line 40, line 62

**Problem**: The instructions say "preserve `max_reviews` from existing state" (line 30/40), but the example jq command (line 52/62) does NOT include `--argjson max_reviews` at all! This means max_reviews will be DELETED from state.json when complete-task runs.

**Impact**: CRITICAL - max_reviews configuration will be lost, breaking the review limit system.

**Fix required**: Add max_reviews to the jq command in both files, or use `jq '. + {phase: "complete-task", ...}'` to merge instead of replace.

### B4: Review and post-review actions are INCONSISTENT about file naming

**Location**: Compare:
- `code-review.md` line 7: "Document results in `code-review-{review-id}.md`"
- `post-code-review.md` line 3: "Address issues from `task-{current-task-id}-review-{latest-review-id}.md`"

**Problem**: These two files reference DIFFERENT file naming conventions:
- Review action uses: `code-review-{review-id}.md`
- Post-review action expects: `task-{current-task-id}-review-{latest-review-id}.md`

This is COMPLETELY BROKEN. The post-review action will never find the review file.

**Impact**: CRITICAL - post-code-review will fail immediately because it can't find the review file.

**Fix required**: Standardize on ONE naming convention across all 8 review/post-review files. Current plan docs use `{review-type}-{iteration}.md`, so use that.

## CRITICAL Issues

### C1: No guidance on {review-id} or {review-iteration} numbering

**Locations**: All review action files (plan-review.md, tasks-review.md, code-review.md, all-code-review.md)

**Problem**: The instructions say "document in `{review-type}-{review-id}.md`" but never explain:
- Should review-id be 1, 2, 3... incrementing across ALL reviews?
- Should it be the phase_iteration value?
- Should it be a timestamp?
- What happens if there are multiple standalone reviews?

**Impact**: MEDIUM - Users will create inconsistent filenames, making it hard to track review history.

**Fix required**: Add explicit instructions: "use `phase_iteration` value from state.json for automated reviews, use incrementing number for standalone reviews"

### C2: continue-plan.md routing for "complete" is INCOMPLETE

**Location**: `continue-plan.md` line 55

**Problem**: The instructions say "Set `phase: 'complete'`, `next_phase: null`, inform user all tasks are done" - but this doesn't say HOW to inform the user or WHAT to do after. Should the agent just stop? Should it suggest creating a PR? Should it run final checks?

**Impact**: MEDIUM - Poor user experience at the end of implementation.

**Fix required**: Add specific instructions for what to do when reaching "complete" state.

### C3: next-task and next-task-tdd don't explain HOW to select next task

**Locations**:
- `next-task.md` - no mention of task selection at all
- `next-task-tdd.md` - no mention of task selection at all

**Problem**: These actions say "implement the next task" but never explain how to determine which task is "next". Should it be:
- First pending task by ID?
- Task specified by current_task in state.json?
- User provides task ID?

Compare to `complete-task.md` line 9: "identify the first task with status 'pending'" - this is explicit. next-task.md should be equally explicit.

**Impact**: MEDIUM - Inconsistent task selection between standalone and automated workflows.

**Fix required**: Add task selection logic to both next-task files: "Read tasks.md and select the first task with status 'pending' by ascending task ID"

### C4: Post-review actions have INCOMPLETE state update instructions

**Locations**: All 4 post-review action files (post-code-review.md, post-plan-review.md, post-tasks-review.md, post-all-code-review.md)

**Problem**: The state update section says "Preserve all other fields: phase_iteration, max_reviews, review_model, consecutive_clean, current_task, tdd" - but it's missing `phase_iteration: null` explicitly in the jq command.

Looking at post-code-review.md lines 19-20:
```
- `next_phase`: `"code-review"` (return to review for another iteration)
- Preserve all other fields: `phase_iteration`, `max_reviews`, ...
```

But how does the agent KNOW to preserve phase_iteration? There's no example jq command showing the full set of fields to preserve. Without an example, the agent might use `jq '.phase = "post-code-review" | .next_phase = "code-review"'` which would DELETE all other fields.

**Impact**: MEDIUM-HIGH - State corruption when post-review actions run.

**Fix required**: Add complete jq example commands to all 4 post-review files showing how to preserve all fields.

## MINOR Issues

### M1: create-tasks.md example has unescaped newline in comment

**Location**: `create-tasks.md` line 51 (jq command)

**Problem**: The jq command spans multiple lines with backslashes for line continuation, but it's inside a markdown fenced code block. This might render incorrectly or confuse users about whether newlines should be literal.

**Impact**: LOW - Cosmetic/clarity issue.

**Fix**: Either show the command on one long line, or add a note: "Note: backslashes allow line continuation in bash"

### M2: Inconsistent terminology: "review-id" vs "iteration" vs "review_number"

**Problem**: Throughout the files, we use:
- `{review-id}` in action files
- `phase_iteration` in state.json
- `{iteration}` in hook error messages

This is confusing. Are these the same thing?

**Impact**: LOW - Clarity issue.

**Fix**: Standardize on one term, preferably "iteration" since that matches state.json.

### M3: continue-plan.md is MASSIVE (87 lines) compared to others

**Problem**: continue-plan.md is significantly longer than other action files. This makes it harder to read and maintain.

**Impact**: LOW - Maintainability concern.

**Fix**: Consider splitting into sub-sections with clearer headers, or extract the routing table into a separate reference document.

### M4: Ground-rules reference is inconsistent

**Problem**:
- Most files use: `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md`
- create-tasks.md line 3 uses: `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` (correct)
- add-task.md line 30 uses: `.taskie/ground-rules.md` (WRONG - this is the old path)

**Impact**: LOW - add-task.md won't load ground-rules correctly.

**Fix**: Fix add-task.md to use `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md`

### M5: No instructions on what to do if state.json is CORRUPTED

**Problem**: All read-modify-write instructions assume state.json is valid JSON. What if it's corrupted (partial write, disk full, etc.)?

**Impact**: LOW - Edge case, but could happen.

**Fix**: Add a note: "If state.json is corrupted or invalid JSON, restore from git history or manually recreate with default values"

## Summary Statistics

**Total issues**: 14
- BLOCKING: 4
- CRITICAL: 4
- MINOR: 6

**Estimated fix time**: 2-3 hours to address all blocking and critical issues.

**Recommendation**: REJECT implementation until blocking issues are fixed. Critical issues should also be addressed before merge.

## Verdict

**FAIL** - Too many blocking issues to accept as-is. The implementation has the right structure but critical details are wrong or missing.
