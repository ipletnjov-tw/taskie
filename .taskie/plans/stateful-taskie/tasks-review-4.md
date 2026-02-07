# Tasks Review 4 — Clean Slate Analysis

Examining `tasks.md` and all 6 task files against the plan. No prior reviews consulted.

---

## Severity Key

- **BLOCKING**: Will cause incorrect behavior if shipped. Must fix.
- **CRITICAL**: High risk of confusion or rework. Strongly recommended.
- **MINOR**: Cosmetic or clarity. Fix if convenient.

---

## Issue 1: BLOCKING — Test suite 3, test 14 expects `next_phase: "complete"` but plan says `phase: "complete"`, `next_phase: null`

**Plan** (State Transitions, auto-advance boundaries): "After all-code-review passes (2 clean) -> set `phase: "complete"`, `next_phase: null`, agent stops."

**Plan** (Hook Logic, step 5g advance target mapping): "`"complete"` for all-code-review."

**Test suite 3, test 14** (in plan): `{..., consecutive_clean: 1, next_phase: "all-code-review"}, MOCK_CLAUDE_VERDICT=PASS` -> Expected: `{..., next_phase: "complete"}`

**Task 3.3** acceptance criteria: "all-code-review -> `complete` (letting `continue-plan` handle final phase transition to `phase: "complete"`, `next_phase: null`)"

These are actually consistent with each other: the hook sets `next_phase: "complete"` (the advance target), and then `continue-plan` handles the final routing (`next_phase: "complete"` -> set `phase: "complete"`, `next_phase: null`). This matches the pattern of all other auto-advances (hook sets `next_phase` to advance target, `continue-plan` routes).

**BUT**: The plan's auto-advance boundary section says "set `phase: "complete"`, `next_phase: null`" — implying the hook does it directly. Task 3.3 says the hook sets `next_phase: "complete"` and lets `continue-plan` do the rest. These contradict.

The task's approach is more consistent with how all other auto-advances work (hook sets advance target in `next_phase`, `continue-plan` routes). The plan's wording is the outlier.

**Recommendation**: The plan should be updated to match the task. The hook sets `next_phase: "complete"`, `phase: "all-code-review"`. Then `continue-plan` handles `next_phase: "complete"` -> `phase: "complete"`, `next_phase: null`. The task files are correct; the plan text is misleading.

**Revised: MINOR** — Plan text is slightly misleading but task files and test expectations are correct and internally consistent. No task file changes needed; plan could be updated for clarity.

---

## Issue 2: CRITICAL — Task 4.3 says to preserve `tdd` from existing state, but `create-tasks.md` runs AFTER `new-plan.md` which sets `tdd: false`

**Plan**: "`create-tasks.md` — After creating tasks, updates `state.json` (read-modify-write): set `phase: "create-tasks"`, `current_task: null`, `next_phase: "tasks-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`. Preserve `max_reviews` from existing state."

**Task 4.3**: "Preserve `max_reviews` and `tdd` from existing state"

The plan only says to preserve `max_reviews`. Task 4.3 additionally preserves `tdd`. This is actually sensible — `tdd` could have been set by the user editing state.json before running `create-tasks`. But it deviates from the plan text which only mentions preserving `max_reviews`.

**Recommendation**: This is a reasonable enhancement. Either update the plan to match (preserve both `max_reviews` and `tdd`) or revert to plan text (preserve only `max_reviews`, reset `tdd: false`). Preserving both is safer.

**Revised: MINOR** — Task is more conservative than plan. Keep the task's approach (preserve both).

---

## Issue 3: CRITICAL — Task 1.3 test runner `state` argument includes `test-stop-hook-cli-invocation.sh` but this file tests CLI invocation, not state transitions

**Task 1.3** acceptance criteria: "`state` argument runs: `test-stop-hook-auto-review.sh`, `test-stop-hook-state-transitions.sh`, `test-stop-hook-cli-invocation.sh`"

The `state` argument is documented as running "state-related tests only." The CLI invocation tests (suite 4) verify that the correct flags are passed to the `claude` CLI — these are related to the auto-review feature but aren't specifically "state" tests. Meanwhile, `test-stop-hook-edge-cases.sh` (Task 6) contains state-related tests like `max_reviews=0`, model alternation integration, and consecutive clean integration, but isn't included in `state`.

**Recommendation**: Either rename the argument to something more inclusive (e.g. `auto-review`) or document that `state` means "all tests related to the stateful auto-review feature." The current name is slightly misleading but not blocking.

**Revised: MINOR** — naming quibble, not blocking.

---

## Issue 4: CRITICAL — Task 3.5 subtask description says "finalized as a single commit" while the updated guidance says "write and commit incrementally"

**Task 3.5** short description: still says "finalized as a single commit after all implementation is done" in some parts, while the updated text says "Write tests alongside implementation: as you complete each implementation subtask (3.1-3.4), immediately write and commit the corresponding tests."

The sample git commit message is still: "Add test suites 2-5 for auto-review, state transitions, CLI invocation, block messages" — suggesting a single commit.

**Problem**: The short description and sample commit message contradict the updated guidance about incremental writing. An implementer might follow the commit message pattern and defer.

**Recommendation**: Update the sample commit message to reflect incremental commits (e.g. one per subtask) or remove the single sample message and replace with a note that tests should have their own commits alongside each implementation subtask.

---

## Issue 5: MINOR — Task 2.1 acceptance criteria still mentions "Finds the most recently modified plan directory" but this is also in subtask 2.2

Both subtask 2.1 and 2.2 mention finding the most recently modified plan directory. In 2.1 it's in the acceptance criteria, in 2.2 it's in the short description. The plan directory finding is part of hook step 3 which is a natural fit for the boilerplate (2.1), but step 6 (validation, 2.2) also needs it.

This is fine since 2.1 creates the function and 2.2 uses it. No action needed.

---

## Issue 6: CRITICAL — `make test-hooks` target exists in Task 1.3 but the plan only specifies `make test-state` and `make test-validation`

**Plan** (Makefile targets): `make test-state` and `make test-validation`

**Task 1.3**: Also includes `make test-hooks` — "runs all hook tests"

This is a useful addition. But `make test-hooks` and `make test` with the `hooks` argument overlap (`hooks` runs all test files in `tests/hooks/`). And `make test` already runs all tests.

**Recommendation**: Keep it — it's useful and non-breaking. But update the plan's Makefile section to include `make test-hooks` so there's no gap.

**Revised: MINOR** — useful addition, just needs plan alignment.

---

## Issue 7: BLOCKING — Plan's `TASK_FILE_LIST` grep is wrong but Task 3.2 has the fix — verify test suite 4 test 7 still works

**Plan** (CLI Invocation section): `grep '^|' ".taskie/plans/${PLAN_ID}/tasks.md" | grep -oE 'task-[0-9]+\.md'`

**Task 3.2**: Uses the corrected approach: `grep '^|' tasks.md | tail -n +3 | awk -F'|' '{gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9]+$/) printf ".taskie/plans/'${PLAN_ID}'/task-%s.md ", $2}'`

The task correctly fixed this. But **test suite 4, test 7** says: "Tasks review prompt contains tasks reference — prompt contains `tasks.md` and `tasks-review-`". This tests that the prompt mentions `tasks.md` but doesn't verify the individual task file list is correctly constructed.

**Test suite 2, test 3** (tasks review trigger) verifies the hook triggers a tasks review. It uses the mock CLI which doesn't validate prompt content — it just writes a review file.

**Problem**: No test explicitly verifies that the corrected `TASK_FILE_LIST` construction produces the right file paths from the task ID column. The mock CLI accepts any prompt. If the awk command has a bug, tests would pass but the real CLI would get wrong file paths.

**Recommendation**: Add a test in suite 4 (or suite 6) that creates a `tasks.md` with known IDs (e.g. 1, 2, 3), triggers a tasks-review or all-code-review, and checks that `MOCK_CLAUDE_LOG` contains all three file paths (`task-1.md`, `task-2.md`, `task-3.md`). This would catch regressions in the `TASK_FILE_LIST` construction.

---

## Issue 8: MINOR — Task 2.5 acceptance criteria says "Update `tests/README.md` with new test file descriptions" but no other task mentions this

Task 2.5 is the only place this appears. It's a reasonable addition but easy to forget. Low risk since it's documentation.

---

## Issue 9: CRITICAL — Task 4.2 `continue-plan.md` routing for `next_phase: "complete-task"` / `"complete-task-tdd"` says "execute the next task" but doesn't specify HOW to determine the next task

**Plan**: "`next_phase` = `"complete-task"` / `"complete-task-tdd"` -> execute the next task with the automation entry point"

**Task 4.2** acceptance criteria: "Routes correctly for both `complete-task` and `complete-task-tdd` variants when either is the `next_phase` value"

**Problem**: When `continue-plan` sees `next_phase: "complete-task"`, it needs to figure out WHICH task to execute next. The `current_task` in state.json points to the task that just finished its review cycle (e.g. task 1). The next task would be task 2. But how does `continue-plan` know to pick task 2? It needs to:
1. Read `tasks.md`
2. Find the next pending task after `current_task`
3. Pass that task ID to the `complete-task` action

This logic isn't specified in the acceptance criteria. The `complete-task.md` action (Task 5.2) says it determines the next task from `tasks.md` internally — but `continue-plan` needs to route TO `complete-task`, not determine the task itself.

**Recommendation**: Clarify in Task 4.2 that when `next_phase` is `"complete-task"` or `"complete-task-tdd"`, `continue-plan` executes the corresponding action file which internally determines the next pending task from `tasks.md`. The routing is just "execute `complete-task.md`" — the task selection is delegated to the action. Add this to the acceptance criteria.

---

## Issue 10: MINOR — Task 6 edge case test 5 says "state.json exists but plan.md doesn't" should trigger rule 1 block, but auto-review might take precedence

**Test 6.5**: "Concurrent plan creation — state.json exists but plan.md doesn't -> validation blocks for missing plan.md (rule 1)"

But if state.json has `next_phase: "code-review"`, the auto-review logic (step 5) would trigger BEFORE validation (step 6). Test 6.6 explicitly tests this precedence. So test 6.5 likely assumes `next_phase` is null or not a review phase in its state.json.

**Recommendation**: Ensure test 6.5 uses `next_phase: null` in its state.json to avoid auto-review taking precedence. If it does, the test is fine. Just needs to be explicit about the state.json content.

---

## Summary

| # | Severity | Summary |
|---|----------|---------|
| 1 | MINOR | Plan text says hook sets `phase: "complete"` directly for all-code-review, but tasks correctly use `next_phase: "complete"` pattern. Plan text is the outlier — no task changes needed. |
| 2 | MINOR | Task 4.3 preserves `tdd` in addition to `max_reviews` — more conservative than plan, which is fine. |
| 3 | MINOR | `state` test runner argument name slightly misleading (includes CLI invocation tests). |
| 4 | CRITICAL | Task 3.5 sample commit message still suggests single commit, contradicting incremental guidance. |
| 6 | MINOR | `make test-hooks` is a useful addition not in the plan; keep it. |
| 7 | BLOCKING | No test verifies the corrected `TASK_FILE_LIST` construction produces correct file paths from task IDs. |
| 8 | MINOR | `tests/README.md` update only mentioned in Task 2.5. |
| 9 | CRITICAL | Task 4.2 doesn't specify that `continue-plan` delegates task selection to `complete-task.md` rather than determining the next task itself. |
| 10 | MINOR | Edge case test 6.5 should explicitly use `next_phase: null` to avoid auto-review precedence. |

**Blocking (1)**: #7
**Critical (2)**: #4, #9
**Minor (6)**: #1, #2, #3, #6, #8, #10
