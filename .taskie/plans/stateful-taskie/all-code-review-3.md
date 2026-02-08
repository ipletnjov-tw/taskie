# All-Code Review 3: Stateful Taskie Complete Implementation Review

## Summary

Reviewed ALL code changes across all 6 tasks in the stateful-taskie plan. Found 2 critical issues, 3 medium issues, and 8 minor issues.

## Critical Issues

### CRITICAL-1: Code review file naming mismatch between hook and plan/ground-rules

**Location**: `taskie/hooks/stop-hook.sh:138`, `taskie/hooks/stop-hook.sh:176`

The hook produces code review files named `code-review-{iteration}.md` (e.g., `code-review-1.md`):
```bash
REVIEW_FILE="$RECENT_PLAN/${REVIEW_TYPE}-${PHASE_ITERATION}.md"
# For code-review type, this produces: code-review-1.md
```

But the plan (`plan.md:197`) specifies that code reviews should be per-task:
```
Write your review to .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}-review-${ITERATION}.md
```

And ground-rules.md (both Claude Code and Codex versions) document the convention as:
```
task-{task-id}-review-{review-id}.md
```

The validation rules in `stop-hook.sh:346-360` accept BOTH patterns (`code-review-{n}.md` and `task-{id}-review-{n}.md`), but the hook only produces the `code-review-{n}.md` form. Meanwhile, the `code-review.md` action tells agents to write to `code-review-{iteration}.md` and the `post-code-review.md` action tells agents to read from `code-review-{iteration}.md`.

**Impact**: The naming convention is internally consistent within the new stateful workflow (hook writes `code-review-N.md`, action reads `code-review-N.md`), but it **deviates from the plan specification** which called for `task-{current_task}-review-{iteration}.md`. The plan's block message templates (plan.md:245-246) also reference `task-${CURRENT_TASK}-review-${ITERATION}.md`. This means the hook's block messages don't match the actual file locations.

Additionally, the block message in the hook (line 296) is a generic template:
```bash
BLOCK_REASON="Review found issues. See ${REVIEW_FILE}. Run /taskie:${POST_REVIEW_PHASE} to address them."
```
This is significantly less detailed than the plan-specified templates (plan.md:242-261) which include specific instructions about updating state.json atomically, mentioning temp file + mv, etc.

### CRITICAL-2: Subtask 6.1 is still pending — `ground-rules.md` NOT updated for Codex

**Location**: `codex/taskie-ground-rules.md`, `.taskie/plans/stateful-taskie/task-6.md:11`

Task 6, Subtask 6.1 "Update ground-rules.md" has status **pending**. While the Claude Code version (`taskie/ground-rules.md`) WAS updated with state.json documentation (State Management section with schema, state update requirements), the Codex version (`codex/taskie-ground-rules.md`) was NOT updated. The Codex ground-rules file is missing:
- `state.json` in the directory structure (it IS present but described as "optional")
- The full "State Management" section with schema and state update requirements
- The authoritative source documentation

The Claude Code `ground-rules.md` has the State Management section, but the task file says the subtask is still pending, meaning the implementer didn't mark it complete even though partial work was done.

## Medium Issues

### MEDIUM-1: Placeholder tests inflate test count — 8 tests are not real tests

**Location**:
- `tests/hooks/test-stop-hook-auto-review.sh:292-295` — 4 placeholder `pass` calls
- `tests/hooks/test-stop-hook-state-transitions.sh:102-104` — 3 placeholder `pass` calls
- `tests/hooks/test-stop-hook-cli-invocation.sh:187` — 1 placeholder `pass` call

8 out of 70 passing tests are placeholders that unconditionally `pass` without testing anything:
```bash
pass "Placeholder: plan-review block message"
pass "Placeholder: tasks-review block message"
pass "Placeholder: all-code-review block message"
pass "Placeholder: Block decision format verification"
pass "Placeholder: tasks-review state updates (covered in test 3)"
pass "Placeholder: code-review state updates (covered in test 2)"
pass "Placeholder: all-code-review state updates"
pass "Placeholder for additional CLI tests (8-14)"
```

The plan specifies 80 tests total. The actual test count is 70, with only 62 being real tests. The task-6 file claims "53/53 pass" but the test runner shows 70 total. The discrepancy is not documented.

### MEDIUM-2: Suite 3 Test 14 is skipped but counted as passing

**Location**: `tests/hooks/test-stop-hook-state-transitions.sh:213-223`

Test 14 ("Auto-advance to all-code-review when no tasks remain") is marked as SKIPPED with a `pass` call and investigation notes. This test was supposed to verify a critical auto-advance path (code review passes, no remaining tasks → advance to all-code-review). The skip note says "pre-existing from Task 3" and the investigation suggests the hook doesn't properly trigger in this scenario.

This is a potentially real bug in the hook's auto-advance logic for the code-review → all-code-review transition when there are no remaining pending tasks. The test was skipped rather than fixing the underlying issue.

### MEDIUM-3: `hooks.json` has incorrect nesting structure

**Location**: `taskie/hooks/hooks.json`

The current structure:
```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh",
        "timeout": 600
      }]
    }]
  }
}
```

This has a double nesting: `hooks.Stop[0].hooks[0]` which seems redundant and may not match the Claude Code plugin hooks schema. If the schema expects `hooks.Stop` to be an array of hook objects directly (without the intermediate `hooks` key), this could cause the hook to not be registered properly. However, since the hook was verified to work during the development process, this may be the correct schema — but it should be verified against the Claude Code plugin documentation.

## Minor Issues

### MINOR-1: `TODO` comment left in test file

**Location**: `tests/hooks/test-stop-hook-auto-review.sh:46`

```bash
# TODO: Once verdict extraction is implemented, check for block decision
# For now, just verify CLI was called
```

Verdict extraction IS implemented (subtask 3.3). This TODO should have been cleaned up and the test should verify the block decision, not just that the CLI was called.

### MINOR-2: `run-tests.sh` `hooks` and `all` arguments are equivalent

**Location**: `run-tests.sh:44`

```bash
case "$TEST_SUITE" in
    all|hooks)
```

Both `all` and `hooks` run the exact same code path. The `hooks` argument should potentially only run hook tests (if other test types existed), but since all tests are hook tests, there's no behavioral difference. This is misleading — the `all` argument implies it might run more than just hooks.

### MINOR-3: `test-stop-hook-edge-cases.sh` not listed in `run-tests.sh` state target

**Location**: `run-tests.sh:55`

The `state` argument only runs 3 specific files:
```bash
for test_file in test-stop-hook-auto-review.sh test-stop-hook-state-transitions.sh test-stop-hook-cli-invocation.sh; do
```

But `test-stop-hook-edge-cases.sh` contains state-related tests too (e.g., max_reviews=0, auto-advance, model alternation integration). It should be included in the `state` target.

### MINOR-4: `tests/README.md` structure diagram is outdated

**Location**: `tests/README.md:20-31`

The README's directory tree doesn't include `test-stop-hook-edge-cases.sh` or the `claude` symlink. Also, suites 2-5 description says "will be added in Task 3" (future tense) but they already exist.

### MINOR-5: `complete-task.md` mktemp doesn't use same-directory pattern

**Location**: `taskie/actions/complete-task.md:47` and `taskie/actions/complete-task-tdd.md:58`

The example uses `TEMP_STATE=$(mktemp)` which creates the temp file in `/tmp`, not in the same directory as `state.json`. The plan specifies (plan.md:275): "Temp file is in the same directory — ensures mv is a rename (same filesystem), not a copy." This could cause a cross-filesystem `mv` which is not atomic.

The hook itself does this correctly: `TEMP_STATE=$(mktemp "${STATE_FILE}.XXXXXX")`. But the action file examples use the wrong pattern. Since action files are prompts (the agent executes the commands), the incorrect example could lead to non-atomic writes.

### MINOR-6: `create-tasks.md` example uses wrong mktemp pattern too

**Location**: `taskie/actions/create-tasks.md:48`

Same issue as MINOR-5: `TEMP_STATE=$(mktemp)` instead of `TEMP_STATE=$(mktemp ".taskie/plans/{plan-dir}/.state.json.XXXXXX")`.

### MINOR-7: `hooks.json` description says "Validates directory structure and triggers automated reviews" but doesn't mention the 600-second timeout

**Location**: `taskie/hooks/hooks.json:2`

This is cosmetic but the statusMessage ("Validating plan structure and checking for reviews...") doesn't indicate to the user that the hook may take up to 10 minutes if it triggers an automated review. A user seeing this status for minutes could think something is hung.

### MINOR-8: Codex ground-rules doesn't have state.json in Process section

**Location**: `codex/taskie-ground-rules.md:9-25`

The Codex ground-rules Process section doesn't mention the `state.json` phase for complete implementation reviews (all-code-review). This was added to the Claude Code ground-rules but not the Codex version. Given the limited Codex scope (only new-plan and continue-plan were updated per the plan), this is expected but should be noted.

## Test Verification

All must-run commands executed successfully:
- `make test` — 70/70 tests pass (17 validation + 19 auto-review + 14 state-transitions + 8 cli-invocation + 12 edge-cases)
- `bash -n tests/hooks/helpers/test-utils.sh` — syntax OK
- `bash -n tests/hooks/helpers/mock-claude.sh` — syntax OK

## Files Reviewed

### Hook & Infrastructure
- `taskie/hooks/stop-hook.sh` — unified stop hook (464 lines)
- `taskie/hooks/hooks.json` — hook registration
- `taskie/.claude-plugin/plugin.json` — version 3.0.0
- `.claude-plugin/marketplace.json` — version 3.0.0

### Action Files (all 16)
- `taskie/actions/new-plan.md` — state.json initialization
- `taskie/actions/continue-plan.md` — state-based routing
- `taskie/actions/create-tasks.md` — state write after tasks
- `taskie/actions/next-task.md` — standalone mode
- `taskie/actions/next-task-tdd.md` — standalone TDD mode
- `taskie/actions/complete-task.md` — automation entry point
- `taskie/actions/complete-task-tdd.md` — automation TDD entry point
- `taskie/actions/continue-task.md` — transparent pass-through
- `taskie/actions/code-review.md` — review with state detection
- `taskie/actions/post-code-review.md` — post-review with state
- `taskie/actions/plan-review.md` — plan review with state
- `taskie/actions/post-plan-review.md` — post-plan-review with state
- `taskie/actions/tasks-review.md` — tasks review with state
- `taskie/actions/post-tasks-review.md` — post-tasks-review with state
- `taskie/actions/all-code-review.md` — all-code review with state
- `taskie/actions/post-all-code-review.md` — post-all-code-review with state
- `taskie/actions/add-task.md` — add task with state

### Ground Rules
- `taskie/ground-rules.md` — updated with State Management section
- `codex/taskie-ground-rules.md` — NOT updated (partial)

### Codex Prompts
- `codex/taskie-new-plan.md` — state.json init added
- `codex/taskie-continue-plan.md` — state-based routing added

### Test Files
- `tests/hooks/helpers/test-utils.sh` — shared helpers
- `tests/hooks/helpers/mock-claude.sh` — mock CLI
- `tests/hooks/test-stop-hook-validation.sh` — 17 tests
- `tests/hooks/test-stop-hook-auto-review.sh` — 19 tests (4 placeholders)
- `tests/hooks/test-stop-hook-state-transitions.sh` — 14 tests (3 placeholders, 1 skipped)
- `tests/hooks/test-stop-hook-cli-invocation.sh` — 8 tests (1 placeholder)
- `tests/hooks/test-stop-hook-edge-cases.sh` — 12 tests

### Other
- `run-tests.sh` — test runner
- `Makefile` — make targets
- `tests/README.md` — test documentation
- `README.md` — version updated to v3.0.0

## Verdict Summary

| Severity | Count | Details |
|----------|-------|---------|
| Critical | 2 | Code review naming mismatch with plan; Subtask 6.1 pending |
| Medium | 3 | 8 placeholder tests; Skipped test 14 hides potential bug; hooks.json nesting |
| Minor | 8 | TODO left in test, misleading run args, missing edge-case test in state target, outdated README, non-atomic mktemp in action examples, etc. |

VERDICT: FAIL
