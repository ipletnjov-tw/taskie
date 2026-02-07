# Tasks Review 3 — Clean Slate Analysis

This review examines `tasks.md` and all 6 task files against the plan to ensure exact correspondence. No prior reviews were consulted.

---

## Methodology

For each item below, the plan section is cited alongside the task/subtask that should implement it. Issues are categorized:

- **BLOCKING**: Incorrect behavior if shipped as-is. Must fix before implementation.
- **CRITICAL**: High risk of confusion or rework during implementation. Strongly recommended fix.
- **MINOR**: Cosmetic, consistency, or clarification issue. Fix if convenient.
- **OBSERVATION**: Not wrong, but worth noting for the implementer.

---

## Issue 1: BLOCKING — tasks.md says Task 3 has 51 tests, but the actual count is 51 + 6 = 57 (or 51 depending on grouping)

**Plan reference**: Test suites table shows: Suite 2 (15) + Suite 3 (16) + Suite 4 (14) + Suite 5 (6) = 51 tests. However, Task 3 subtask 3.5 says: "Suite 2 + Suite 5 = 21 tests in one file, Suite 3 = 16 tests, Suite 4 = 14 tests. Total: 51."

This is internally consistent (15 + 6 + 16 + 14 = 51). The discrepancy is that Suite 5 (block message templates, 6 tests) is merged into the same file as Suite 2 in task-3.md subtask 3.5 acceptance criteria: `test-stop-hook-auto-review.sh` contains "15 tests (suite 2) + 6 tests (suite 5) = 21 tests." This is fine.

**However**, the plan's test section lists Suite 5 separately as "Block Message Templates (part of test-stop-hook-auto-review.sh)" — confirming the merge. **No actual issue.** Striking this.

**Revised: NOT AN ISSUE** — Plan and tasks are consistent on the 51 count.

---

## Issue 2: CRITICAL — Task 3 subtask 3.5 says "write tests incrementally" but also "finalized as a single commit"

**Plan reference**: "Tests should be written alongside their corresponding feature implementation, not deferred to a separate test-only task."

**Task 3.5** says: "Tests should be written incrementally as each implementation subtask (3.1-3.4) completes — e.g., write suite 2 tests 4-5, 8-11 after 3.1, suite 4 tests after 3.2, etc. — then finalized as a single commit after all implementation is done."

This contradicts the plan's intent. The plan says tests should be written alongside implementation. But Task 3 has a dedicated test subtask (3.5) that comes AFTER all implementation subtasks (3.1-3.4). The "written incrementally" note is aspirational — the commit structure suggests all tests land in a single final commit.

**Problem**: If tests are deferred to subtask 3.5, the implementer may write 3.1-3.4 without testing, discover integration issues late, and have to rework. The plan explicitly wanted to avoid this.

**Recommendation**: Either (a) merge test writing into each implementation subtask (3.1 includes its tests, 3.2 includes its tests, etc.) and remove subtask 3.5 entirely, or (b) acknowledge that subtask 3.5 is a consolidation/finalization step and explicitly state that partial tests should be written and committed with each implementation subtask.

---

## Issue 3: BLOCKING — Task 2 subtask 2.5 says version bump 2.2.1 → 3.0.0, but this should happen ONCE at the end, not mid-implementation

**Plan reference**: The plan doesn't specify when the version bump happens. CLAUDE.md says "Every change must include a version bump" except test-only changes.

**Task 2.5** says: "Plugin version bumped in both files (MAJOR: 2.2.1 → 3.0.0)."

**Problem**: If version is bumped to 3.0.0 in Task 2, then Tasks 3-6 would need additional bumps (since they also make non-test changes). But the tasks don't mention any further version bumps after Task 2.5.

**Two interpretations**:
1. The bump happens once in Task 2.5 and covers all work on this branch (since it's all one feature). Tasks 3-6 don't need bumps because the branch hasn't been released yet.
2. Each task needs its own bump per CLAUDE.md rules.

**Recommendation**: Clarify that the 3.0.0 bump in Task 2.5 covers the entire feature branch. Add a note to Tasks 3-6 stating "No version bump needed — covered by Task 2.5's MAJOR bump."

---

## Issue 4: CRITICAL — Task 4 says "Can run in parallel with Task 3" but tasks.md prerequisite column doesn't reflect this

**Plan reference**: Plan doesn't explicitly define task ordering beyond the dependency chain.

**Task 4 header**: "Prerequisites: Task 2 (hook must exist for block messages to reference). Can run in parallel with Task 3."
**Task 5 header**: "Prerequisites: Task 2 (hook must exist for block messages to reference). Can run in parallel with Task 3."
**tasks.md**: Only has "Priority" column (all high), no "Prerequisites" or dependency information.

**Problem**: `tasks.md` has no mechanism to communicate task dependencies or parallelism opportunities. The dependency information is ONLY in the task files. An implementer looking at `tasks.md` would assume linear execution (1 → 2 → 3 → 4 → 5 → 6) and miss the parallelism.

**Recommendation**: Add a "Prerequisites" or "Depends on" column to `tasks.md` capturing: Task 1 (none), Task 2 (1), Task 3 (2), Task 4 (2), Task 5 (2), Task 6 (1-5).

---

## Issue 5: MINOR — Task 2.5 mentions "Update README.md latest version reference" but no other task mentions README updates

**Plan reference**: The plan's README section shows "Latest version: **v2.2.0**" — already outdated (current is 2.2.1).

**Observation**: Task 2.5 correctly identifies the README version reference needs updating. However, the README currently says v2.2.0, which is already wrong relative to 2.2.1. This is a pre-existing issue, not caused by this plan, but the bump to 3.0.0 in Task 2.5 should fix it.

**No action needed** — Task 2.5 already covers this.

---

## Issue 6: CRITICAL — Task 3.2 acceptance criteria says "do NOT use the shell `timeout` command (not available on macOS)" but the plan says hook timeout is 600 seconds

**Plan reference**: "Hook Timeout — Set to 600 seconds (10 minutes) to allow the `claude` CLI subprocess to complete a full review. If the subprocess times out, the hook should treat it as a failed review."

**Task 3.2** says: "CLI subprocess timeout is handled by Claude Code's 600s hook timeout — do NOT use the shell `timeout` command (not available on macOS). If the hook is killed by the system timeout, the stop is allowed through by default."

**Problem**: The plan says "If the subprocess times out, the hook should treat it as a failed review: log a warning, skip the review, and allow the stop through." But if the hook itself is killed by the system timeout, there's no opportunity for the hook to "treat it as a failed review" or "log a warning." The hook is just killed.

This means the state.json will be left in an inconsistent state: `phase_iteration` was already incremented (step 5b), but the review file was never written and state was never updated with the result. On the next `continue-plan`, the agent will see a stale state.

**Recommendation**: Document this as a known limitation in the task file. The `continue-plan` crash recovery heuristic (Task 4.2) should handle this case — when `next_phase` is a review phase and the expected review file doesn't exist, it indicates a crash/timeout mid-review. The artifact completeness check should cover it.

---

## Issue 7: BLOCKING — Task 3.3 remaining tasks check uses wrong column index

**Plan reference**: "Remaining tasks check: `grep '^|' tasks.md | awk -F'|' '{print $3}' | grep -i 'pending' | wc -l`"

**tasks.md format**: `| Id | Status | Priority | Description | Test strategy |`

Field indices with `awk -F'|'`:
- `$1` = empty (before first `|`)
- `$2` = Id
- `$3` = Status
- `$4` = Priority
- `$5` = Description
- `$6` = Test strategy

So `$3` IS the Status column. **However**, this check greps for "pending" in the Status column. The plan uses "pending" as the status for incomplete tasks. But looking at `tasks.md`, the status values used are literally "pending" — so the check is correct.

**BUT**: The plan says the status check determines if there are remaining **pending** tasks. After code review passes for a task, the hook needs to know if OTHER tasks remain. The current task's status in `tasks.md` might still say "pending" or "in progress" at this point — it hasn't been marked "done" yet because the hook is the one deciding what happens next.

**Problem**: The hook checks for "pending" tasks to decide whether to advance to `all-code-review` or the next `complete-task`. But the CURRENT task being reviewed hasn't been marked complete in `tasks.md` yet — it's still "pending" or "in progress." So the grep will always find at least one pending task (the current one), incorrectly deciding there are remaining tasks and never advancing to `all-code-review`.

**Recommendation**: The remaining tasks check needs to EXCLUDE the current task. Something like:
```bash
grep '^|' tasks.md | grep -v "^| *${CURRENT_TASK} " | awk -F'|' '{print $3}' | grep -i 'pending' | wc -l
```
Or alternatively, check if ANY task OTHER THAN the current one has a "pending" status.

---

## Issue 8: CRITICAL — Task 4.2 (`continue-plan.md`) crash recovery heuristic for plan-review uses ">50 lines" OR "## Overview" heading, but neither is reliable

**Plan reference**: "verify `plan.md` exists and appears complete (contains an `## Overview` heading or is > 50 lines)"

**Task 4.2** acceptance criteria: "Checks artifact completeness for plan-review (plan.md exists and has `## Overview` heading OR >50 lines — either condition suffices)"

**Problem**: A plan file could have an `## Overview` heading but be otherwise empty/incomplete (the heading was written first, content crashes mid-generation). Conversely, a plan could be >50 lines but not have `## Overview` if the plan template changes.

**Recommendation**: This is a best-effort heuristic and the plan acknowledges it. The risk is low — the worst case is a "simply stop to trigger the hook" when the plan is actually incomplete, which will result in a review of an incomplete plan. The reviewer will catch it. **Accept as-is** — this is adequate for crash recovery.

**Revised: OBSERVATION** — The heuristic is imperfect but acceptable for crash recovery.

---

## Issue 9: MINOR — Task 6 prerequisite says "Tasks 1-5" but the edge case tests (suite 6) only need the hook (Tasks 1-3) and some action files

**Plan reference**: "Test distribution strategy: Tests should be written alongside their corresponding feature implementation."

**Task 6.3** says to write all 12 edge case tests. Looking at the test list:
- Tests 1-9, 12: Only test the hook behavior — no action file involvement
- Test 10-11: Test hook behavior across multiple invocations — no action files

**Problem**: None of the suite 6 tests actually require Tasks 4-5 (action file changes). The prerequisite is overly conservative.

**Recommendation**: Change Task 6 prerequisite to "Tasks 1-3 (hook must be fully implemented for edge case tests)" and note that subtasks 6.1-6.2 (ground-rules, Codex updates) can run in parallel with other tasks.

---

## Issue 10: BLOCKING — Task 3.3 auto-advance for `all-code-review` says `next_phase: null` but plan says something different

**Plan reference**: "After all-code-review passes (2 clean) → set `phase: "complete"`, `next_phase: null`, agent stops."

**Task 3.3** acceptance criteria: "`all-code-review → sets phase: "complete", next_phase: null directly (no further routing needed)`"

But look at the auto-advance flow in the plan more carefully: "After all-code-review passes (2 clean) → set `phase: "complete"`, `next_phase: null`, agent stops."

Wait — `next_phase: null` is correct here. The plan also says in `continue-plan.md` routing: "`next_phase` = `"complete"` → set `phase: "complete"`, `next_phase: null`, inform user all tasks are done."

**These are two different paths**:
1. **Hook auto-advance after all-code-review passes**: Hook sets `phase: "complete"`, `next_phase: null` directly.
2. **continue-plan routing**: If `next_phase` is `"complete"`, set `phase: "complete"`, `next_phase: null`.

Path 2 is only reached if the hook set `next_phase: "complete"` but didn't set `phase` yet. But path 1 sets BOTH at once.

**Problem**: There's a subtle inconsistency. If the hook sets `phase: "complete"` AND `next_phase: null`, then `continue-plan`'s `next_phase: "complete"` routing is unreachable dead code. If the hook instead set `next_phase: "complete"` and left `phase` as `"all-code-review"`, then `continue-plan` would handle it.

Looking at other auto-advance targets: for plan-review → `next_phase: "create-tasks"`, `phase` stays as the review phase. For code-review → `next_phase: "complete-task"`, `phase` stays as the review phase. The pattern is: set `next_phase` to the advance target and set `phase` to the review phase.

**Following this pattern consistently**, all-code-review auto-advance should set `next_phase: "complete"` and `phase: "all-code-review"`. Then `continue-plan` handles the routing when the user resumes.

Task 3.3 deviates from this pattern by having the hook set `phase: "complete"` directly. This is inconsistent with how all other auto-advances work.

**Recommendation**: Change Task 3.3 to follow the consistent pattern: on all-code-review auto-advance, set `phase: "all-code-review"`, `next_phase: "complete"`. Let `continue-plan` handle setting `phase: "complete"` and `next_phase: null`. This keeps the hook's behavior uniform.

Alternatively, if the plan intentionally shortcuts here (since "complete" is terminal), document this explicitly as an exception to the pattern and remove the unreachable `next_phase: "complete"` routing from `continue-plan.md`.

---

## Issue 11: CRITICAL — Task 5.4 says review actions "don't update state.json" when hook-invoked, but some review actions (standalone) DO need to update state

**Plan reference**: "code-review.md — When invoked standalone, writes review and sets `next_phase: null`."

**Task 5.4** acceptance criteria: "Review actions (4 files): when `phase_iteration` is null in state.json (standalone), set `next_phase: null`. When `phase_iteration` is non-null (hook-invoked), don't update state.json (hook manages it)."

**Problem**: When invoked standalone, the review action needs to update state with more than just `next_phase: null`. It should also set `phase` to the review type (e.g., `"code-review"`) so `continue-plan` can route correctly if interrupted. The acceptance criteria only mention `next_phase: null` but not `phase`.

**Recommendation**: Expand the standalone review action state writes to include: `phase: "{review-type}"`, `next_phase: null`. And for completeness, clarify that no other fields change in standalone mode.

---

## Issue 12: MINOR — Task 1.3 acceptance criteria lists `make test-hooks` but tasks.md and plan only mention `make test-state` and `make test-validation`

**Plan reference**: Makefile targets listed as `make test-state` and `make test-validation`.

**Task 1.3**: Also lists `make test-hooks` — "runs all hook tests (all test-*.sh files in tests/hooks/)."

This is an addition beyond the plan. It's a useful target but wasn't in the plan specification.

**Recommendation**: Either add `make test-hooks` to the plan's Makefile section or remove it from Task 1.3. Since it's useful and not harmful, adding it is preferable.

---

## Issue 13: MINOR — Task 6 test file is named `test-stop-hook-edge-cases.sh` in the task but the plan says tests are in Suite 6 without specifying a filename

**Plan reference**: The plan doesn't specify a filename for suite 6 tests. The test infrastructure section shows `test-stop-hook-auto-review.sh`, `test-stop-hook-state-transitions.sh`, `test-stop-hook-cli-invocation.sh` but no edge cases file.

**Task 6.3** acceptance criteria: `tests/hooks/test-stop-hook-edge-cases.sh`

This is a reasonable naming choice consistent with the pattern. Not an issue per se, but the plan's test file list should include it.

**Recommendation**: Accept the name. Note the plan's file list is incomplete.

---

## Issue 14: CRITICAL — No task covers `all-code-review.md` or `post-all-code-review.md` state.json updates

**Plan reference**: "all-code-review.md / post-all-code-review.md — Update state.json with appropriate phase transitions."

**Task 5.4** subtitle: "Update all review and post-review action files" — and it lists 8 files including `all-code-review.md` and `post-all-code-review.md`.

**But**: The acceptance criteria in Task 5.4 are generic ("Review actions (4 files)" and "Post-review actions (4 files)") without calling out any `all-code-review`-specific behavior. The `all-code-review` phase has unique routing: its auto-advance target is `"complete"` (not another implementation phase). The post-all-code-review action should set `next_phase: "all-code-review"` in automated mode, which is covered by the generic pattern.

**Problem**: The generic pattern is sufficient here. The unique advance target is handled by the hook (Task 3), not by the action. **Not actually an issue.**

**Revised: NOT AN ISSUE** — generic pattern covers all-code-review actions correctly.

---

## Issue 15: CRITICAL — Task 3.2 `TASK_FILE_LIST` construction has a potential bug

**Plan reference**: `grep '^|' ".taskie/plans/${PLAN_ID}/tasks.md" | grep -oE 'task-[0-9]+\.md'`

**Problem**: In the `tasks.md` table, task files are referenced as text like "task-1.md" in the description or test strategy columns. But looking at the actual `tasks.md` for this plan, there are NO `task-*.md` references in the table! The table has columns: Id, Status, Priority, Description, Test strategy. None contain literal `task-N.md` strings.

The grep pattern `task-[0-9]+\.md` would match ZERO rows in the current tasks.md format. This means `TASK_FILE_LIST` would be empty for every tasks-review and all-code-review, causing the hook to skip those reviews with a warning.

**Root cause**: The plan assumes `tasks.md` contains literal `task-N.md` references. The current format uses task IDs (1, 2, 3...) in the Id column, not filenames. The task file list should be constructed from the Id column:

```bash
TASK_FILE_LIST=$(grep '^|' ".taskie/plans/${PLAN_ID}/tasks.md" | tail -n +3 | awk -F'|' '{gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9]+$/) print ".taskie/plans/'${PLAN_ID}'/task-"$2".md"}' | tr '\n' ' ')
```

**Recommendation**: Fix the `TASK_FILE_LIST` construction in both the plan and Task 3.2 to extract numeric IDs from column 2 and construct filenames. The current grep approach will produce empty results.

---

## Issue 16: OBSERVATION — Test count discrepancy between plan table and task files

**Plan**: "Expected Test Counts" table totals 80 tests: 17 + 15 + 16 + 14 + 6 + 12 = 80.

**Task files**: Task 2 (17 tests) + Task 3 (51 tests which includes suites 2-5) + Task 6 (12 tests) = 80. Consistent.

**No issue** — counts match.

---

## Issue 17: MINOR — Task 2 subtask 2.1 says "Set hook timeout to 600 seconds in plugin.json" but Task 2.5 also says to update plugin.json

Both subtask 2.1 and 2.5 mention `plugin.json` updates. Subtask 2.1 mentions the timeout, while 2.5 mentions registering the hook and removing the old one.

**Recommendation**: Clarify that subtask 2.1 does NOT touch `plugin.json` — it only creates the `stop-hook.sh` file. All `plugin.json` changes happen in subtask 2.5. The timeout reference in 2.1 is just noting the target configuration.

---

## Issue 18: BLOCKING — Task 3.2 hard stop outputs a `systemMessage` but the plan says hard stop should just approve

**Plan reference**: "Max review iterations reached (`phase_iteration > max_reviews` and `max_reviews > 0`): The agent performs a hard stop and waits for user input before proceeding. It does NOT auto-advance to the next phase."

**Task 3.2** acceptance criteria: "Hard stop when `phase_iteration > max_reviews` (approve, no CLI invocation). Output `systemMessage`: 'Max review limit (${MAX_REVIEWS}) reached...'"

**Problem**: Using `systemMessage` means the MESSAGE is shown to the USER, not to Claude. The user sees it, but Claude doesn't know the review limit was reached. Claude will just see a normal stop. On next `continue-plan`, Claude reads `state.json` and sees `next_phase` is still set to a review phase with `phase_iteration > max_reviews`. The hook will again hit the hard stop. This creates a loop where the user keeps running `continue-plan` but the hook keeps hard-stopping.

The plan says "the agent must wait for user input before proceeding" — but with `systemMessage`, the agent has no awareness of WHY it was stopped. The user needs to manually edit `state.json` to set `next_phase: null` or adjust `max_reviews`.

**Recommendation**: This is actually the intended behavior — the user is told (via systemMessage) to edit state.json. But the message should be clear about what the user needs to do. The current acceptance criteria message "Edit state.json to adjust max_reviews or set next_phase manually" covers this. However, confirm this is intentional: the USER must manually intervene after max reviews. Claude cannot be told to do it automatically (that would be a block, not an approve).

**Revised: OBSERVATION** — The behavior is correct but the UX requires the user to edit state.json manually. This should be documented as expected behavior.

---

## Summary

| # | Severity | Summary |
|---|----------|---------|
| 2 | CRITICAL | Task 3.5 test deferral contradicts plan's "write tests alongside implementation" intent |
| 3 | BLOCKING | Version bump timing unclear — should explicitly state 3.0.0 covers entire branch |
| 4 | CRITICAL | tasks.md lacks dependency/prerequisite column; parallelism info only in task files |
| 6 | CRITICAL | Hook timeout crash leaves state.json inconsistent; continue-plan crash recovery should handle it |
| 7 | BLOCKING | Remaining tasks check won't exclude current task — will never reach all-code-review |
| 9 | MINOR | Task 6 prerequisite overly conservative (says Tasks 1-5, only needs 1-3) |
| 10 | BLOCKING | all-code-review auto-advance inconsistent with other auto-advance patterns |
| 11 | CRITICAL | Standalone review actions need to set `phase` too, not just `next_phase: null` |
| 12 | MINOR | `make test-hooks` target not in plan |
| 13 | MINOR | Edge case test filename not in plan's file list |
| 15 | CRITICAL | `TASK_FILE_LIST` grep pattern won't match current tasks.md format — always empty |
| 17 | MINOR | Subtask 2.1 and 2.5 both mention plugin.json — clarify who owns it |
| 18 | OBSERVATION | Hard stop UX requires manual state.json editing by user |

**Blocking issues (3)**: #3, #7, #10
**Critical issues (5)**: #2, #4, #6, #11, #15
**Minor issues (4)**: #9, #12, #13, #17
**Observations (1)**: #18
