# All-Code Review 1: Complete Implementation Review

## Scope

Reviewed ALL code created, changed, or deleted across all 6 tasks in the stateful-taskie plan:

- **Task 1**: Test infrastructure (shared helpers, mock claude CLI, test runner & Makefile)
- **Task 2**: Unified stop hook — validation migration
- **Task 3**: Unified stop hook — auto-review logic
- **Task 4**: Action file changes — planning actions
- **Task 5**: Action file changes — task & review actions
- **Task 6**: Ground rules, Codex updates, edge case tests

Files reviewed:
- `taskie/hooks/stop-hook.sh` (466 lines)
- `taskie/hooks/hooks.json`
- `taskie/ground-rules.md` (139 lines)
- `taskie/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- All 17 action files in `taskie/actions/`
- All 5 test files in `tests/hooks/`
- All 2 helper files in `tests/hooks/helpers/`
- `run-tests.sh`, `Makefile`
- Codex prompts: `taskie-new-plan.md`, `taskie-continue-plan.md`, `taskie-ground-rules.md`

## Test Execution Results

```
make test
```

**Result: 2 FAILURES out of 68 tests**

- Suites 2&5 (Auto-Review & Block Messages): 19/19 PASS
- Suite 4 (CLI Invocation): 8/8 PASS
- Suite 6 (Edge Cases & Integration): 12/12 PASS
- Suite 3 (State Transitions): 14/14 PASS
- Suite 1 (Validation): 15/17 PASS, **2 FAIL**

## Issues Found

### CRITICAL Issues

#### C1: Two test failures in test-stop-hook-validation.sh (Tests 14 & 17)

**File**: `tests/hooks/test-stop-hook-validation.sh:206-254`

Tests 14 and 17 both fail because they use state.json with `"next_phase": "code-review"` which triggers the auto-review code path in the hook. The hook tries to find `task-null.md` (since `current_task` is null in the test state), logs a warning, and returns a "skipping review" message — never reaching the validation logic.

- **Test 14** ("state.json not rejected by filename validation"): expects `"validated successfully"` but gets `"Task file not found, skipping review"`
- **Test 17** ("Valid state.json produces no warnings"): same issue — the auto-review path emits its own warning before validation runs

**Root cause**: The test state.json values use `"next_phase": "code-review"` which activates the auto-review path. To test that state.json doesn't interfere with validation, the state should use `"next_phase": null` (standalone mode) so the hook falls through to validation.

**Fix**: Change the state.json in tests 14 and 17 to use `"next_phase": null` (or a non-review phase like `"complete-task"`) so the hook reaches the validation step. The `phase` field should also be something that doesn't trigger review logic (e.g., `"next-task"`).

---

### MEDIUM Issues

#### M1: Review file naming inconsistency between hook and plan spec for code reviews

**File**: `taskie/hooks/stop-hook.sh:138`

The hook constructs the review file path as:
```
REVIEW_FILE="$RECENT_PLAN/${REVIEW_TYPE}-${PHASE_ITERATION}.md"
```

For `REVIEW_TYPE="code-review"`, this produces `code-review-1.md`, but the plan spec (plan.md, lines 173-177, 197) and the block message template (plan.md, lines 245-246) specify the file should be `task-${CURRENT_TASK}-review-${ITERATION}.md` (e.g., `task-1-review-1.md`).

The hook also builds the CLI prompt (line 176) saying to output to `${REVIEW_TYPE}-${PHASE_ITERATION}.md` which would be `code-review-1.md`, not the per-task review file.

**Impact**: The review file will be named `code-review-1.md` instead of `task-1-review-1.md`. The post-code-review action (line 7) looks for `code-review-{iteration}.md`, matching the hook's actual behavior. However, this diverges from the plan spec and the pre-existing naming convention (`task-{id}-review-{n}.md`). The block message also references the generic name, not the task-specific one.

**Severity rationale**: Medium rather than critical because the action files consistently reference `code-review-{iteration}.md` format (matching the hook), so the workflow functions correctly end-to-end. But it contradicts the plan spec and the established naming convention used for manual reviews.

#### M2: Block message templates are simplified compared to plan spec

**File**: `taskie/hooks/stop-hook.sh:296`

The actual block message is:
```
Review found issues. See ${REVIEW_FILE}. Run /taskie:${POST_REVIEW_PHASE} to address them. Escape hatch: edit state.json to set next_phase manually if needed.
```

The plan spec (lines 245-261) specifies much more detailed block messages that include:
- Explicit instruction to read the review file
- Instruction to perform the specific post-review action
- Instruction to create the post-review documentation file
- Explicit `state.json` update instructions (which fields to set, which to preserve)
- Atomic write instructions (temp file then mv)
- Instruction to update tasks.md and push to remote

The simplified message relies on the post-review action file itself containing these instructions. This is a reasonable design decision (DRY), but it does mean the main agent must correctly look up and follow the post-review action, which it would do anyway since the block message says `Run /taskie:post-code-review`.

#### M3: Temp file location for atomic state writes uses system temp directory

**File**: `taskie/hooks/stop-hook.sh:116,252,282`

The hook uses `mktemp` without specifying the directory:
```bash
TEMP_STATE=$(mktemp)
```

The plan spec (line 275) specifies temp files should be in the same directory:
```bash
TMPFILE=$(mktemp ".taskie/plans/${PLAN_ID}/.state.json.XXXXXX")
```

Using the same directory ensures `mv` is an atomic rename on the same filesystem. When `mktemp` uses `/tmp`, the `mv` may be a cross-filesystem copy-and-delete, which is NOT atomic.

**Impact**: On most Linux setups where `/tmp` is on the same filesystem as the project, this works fine. But on systems with `/tmp` as tmpfs (common on systemd systems), the `mv` would be a cross-device copy — defeating the atomic write guarantee.

#### M4: `tasks.md` created by `create_test_plan` helper lacks the `Reviews` column

**File**: `tests/hooks/helpers/test-utils.sh:38-42`

The test helper creates tasks.md with 4 columns:
```
| Id | Status | Priority | Description |
```

But the actual tasks.md in the plan (`.taskie/plans/stateful-taskie/tasks.md`) has 7 columns:
```
| Id | Status | Priority | Prerequisites | Description | Test strategy | Reviews |
```

This mismatch means tests that parse `tasks.md` columns (e.g., the `TASKS_REMAIN` check at hook line 99 which uses awk `$3` for status) may get different results in tests vs production. Currently the hook uses `$3` (column 3) which would be `Priority` in the test helper but `Priority` in production too — so it happens to work. But the `TASK_FILE_LIST` construction at line 145 uses `$2` for Id which is correct in both cases.

However, the `TASKS_REMAIN` check at line 99 greps for `pending` in `$3` (which is the Priority column, not Status). This is a latent bug — it should check the Status column (`$3` in the 4-column format but `$3` happens to be Priority in the 7-column format). Wait — looking more carefully: the awk `$2` is Id (after the leading empty field from `|`-splitting). Actually with `-F'|'`, field 1 is empty (before first `|`), field 2 is Id, field 3 is Status. So `$3` is Status. This is correct for both the 4-column and 7-column tables.

Re-evaluation: The column indexing is correct. The test helper's simpler table format is fine for testing purposes since the hook only reads columns 2 (Id) and 3 (Status). Downgrading this concern.

#### M5: Hook passes `FILES_TO_REVIEW` as positional args to `claude` CLI

**File**: `taskie/hooks/stop-hook.sh:194`

```bash
CLI_OUTPUT=$(claude --print ... "$PROMPT" $FILES_TO_REVIEW 2>"$LOG_FILE")
```

`$FILES_TO_REVIEW` is unquoted, so word splitting applies. This means file paths with spaces would be split incorrectly. Taskie plan directories with spaces in the name would cause problems. Additionally, the plan spec (lines 192-198) shows `FILES_TO_REVIEW` as part of the prompt string, not as separate positional arguments.

The `claude` CLI may not accept positional arguments after the prompt for specifying files to read — this depends on the CLI's argument parsing. If it does, the unquoted expansion could cause issues with paths containing spaces. If it doesn't accept them, the files would be silently ignored and the review subprocess would need to find files from the prompt text alone.

#### M6: `consecutive_clean` counter logic in auto-advance for code-review all-code-review transition

**File**: `taskie/hooks/stop-hook.sh:240-243`

When auto-advancing from code-review to all-code-review (no tasks remain), the hook resets:
```bash
PHASE_ITERATION=0
REVIEW_MODEL="opus"
CONSECUTIVE_CLEAN=0
```

But these are local variable assignments. They're used in the subsequent `jq` state write (line 253-262), which correctly uses `$PHASE_ITERATION`, `$REVIEW_MODEL`, `$CONSECUTIVE_CLEAN`. However, the auto-advance `jq` also writes `$CONSECUTIVE_CLEAN` which was just set to 0 — but we're in the auto-advance branch where `CONSECUTIVE_CLEAN >= 2`. The reset to 0 is intentional (fresh review cycle), but the `jq` command on line 257 writes the reset value, which is correct. No issue here after careful analysis.

#### M7: Skipped test in state transitions suite

**File**: `tests/hooks/test-stop-hook-state-transitions.sh`

Test 14 ("Auto-advance to all-code-review") is marked as `SKIPPED - needs investigation`. This means the critical code path where code-review auto-advances to all-code-review (when no pending tasks remain) is not fully tested. The edge case test suite (test 11) partially covers this with the "two consecutive clean reviews auto-advance" integration test, but the specific state transitions for this path aren't independently verified.

---

### MINOR Issues

#### m1: `code-review-{n}.md` naming breaks the established filename validation pattern

**File**: `taskie/hooks/stop-hook.sh:138` and `taskie/hooks/stop-hook.sh:351-358`

The validation regex at line 354 allows `task-[a-zA-Z0-9_-]+-review-[0-9]+.md` (task-specific reviews) but does NOT have a pattern for standalone `code-review-{n}.md` files. The hook would flag `code-review-1.md` as an invalid filename when validation runs on a subsequent stop.

Similarly, `code-post-review-{n}.md` (from post-code-review.md action line 7) is not in the allowed patterns.

This means after a code review, the next stop where validation runs would block because `code-review-1.md` is not a recognized filename.

Actually — re-reading the validation patterns more carefully: the regex on line 354 is `^all-code-review-[0-9]+\.md$` which catches `all-code-review-{n}.md`. But there's no pattern for plain `code-review-{n}.md`. This IS a problem.

**Reclassifying to CRITICAL.**

#### m2: `next-task-tdd.md` doesn't set `tdd: true` in state.json

**File**: `taskie/actions/next-task-tdd.md:26-31`

The next-task-tdd action updates state to `"next-task-tdd"` phase but only sets `phase`, `current_task`, `next_phase`, and `phase_iteration`. It preserves `tdd` from existing state via "Preserve all other fields". This is fine if the existing state already has `tdd: true` (e.g., set by `complete-task-tdd`), but if the user invokes `next-task-tdd` standalone on a plan where `tdd` is `false`, the field won't be updated. This is arguably correct since `next-task` is standalone and `tdd` primarily affects the hook's auto-advance target, but it's a potential source of confusion.

#### m3: Codex `taskie-ground-rules.md` missing state.json documentation

**File**: `codex/taskie-ground-rules.md`

The Codex ground rules file does not mention `state.json` at all, despite the plan spec (Section "Codex CLI Updates") stating that Codex prompts should be updated with state file interaction where practical. The `taskie-new-plan.md` and `taskie-continue-plan.md` Codex prompts DO reference state.json, but the ground rules file (which is the shared reference for all Codex prompts) doesn't document it. This means an agent following Codex ground rules wouldn't know about state.json unless it specifically reads one of the two updated prompts.

This was a deliberate design decision per the plan ("Codex prompts are NOT updated for state file writes" except new-plan and continue-plan), but the ground rules could at minimum mention that state.json exists.

#### m4: `hooks.json` has redundant nesting

**File**: `taskie/hooks/hooks.json`

The structure has double nesting:
```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{...}]
    }]
  }
}
```

This may be the correct format for Claude Code plugins, but it looks unusual with `hooks` appearing twice at different nesting levels. If this is not the correct format, the hook might not register properly. This should be verified against the Claude Code plugin hook documentation.

#### m5: Review log file cleanup inconsistency

**File**: `taskie/hooks/stop-hook.sh:201`

The hook cleans up `.review-{ITERATION}.log` on success (`rm -f "$LOG_FILE"`) but leaves it on failure (line 305: "Warning: Review failed..."). This is intentional per the plan ("On failure, the log persists so the user can inspect it"). However, the `.review-1.log` and `.review-2.log` files visible in `git status` suggest these were left from previous test runs or failed reviews. They should probably be in `.gitignore` or cleaned up after inspection.

#### m6: Plan spec expected 80 tests, actual count is 68

The plan specified 80 tests across 6 suites (17+15+16+14+6+12). The actual implementation has 68 passing tests (17+19+14+8+12 — note: suites 2 and 5 were combined into 19 tests, and suite 4 has 8 tests with placeholders). Several tests are marked as "Placeholder" tests that don't fully exercise the described behavior. This is a test coverage gap.

#### m7: `TASKS_REMAIN` check in `max_reviews=0` path doesn't handle missing tasks.md

**File**: `taskie/hooks/stop-hook.sh:99`

The `TASKS_REMAIN` check uses `grep '^|' "$RECENT_PLAN/tasks.md" 2>/dev/null` which correctly suppresses errors if `tasks.md` is missing. However, if `tasks.md` exists but has no pending tasks (all done), `TASKS_REMAIN` would be 0 and the hook would advance to `all-code-review` — which is correct. No issue here.

---

### CRITICAL Issues (Reclassified)

#### C2: `code-review-{n}.md` and `code-post-review-{n}.md` not in validation allowed patterns

**File**: `taskie/hooks/stop-hook.sh:351-358`

The filename validation regex allows these patterns:
- `(plan|design|tasks).md`
- `task-[a-zA-Z0-9_-]+.md`
- `(plan|design|tasks)-review-[0-9]+.md`
- `all-code-review-[0-9]+.md`
- `task-[a-zA-Z0-9_-]+-review-[0-9]+.md`
- `(plan|design|tasks)-post-review-[0-9]+.md`
- `all-code-post-review-[0-9]+.md`
- `task-[a-zA-Z0-9_-]+-post-review-[0-9]+.md`

**Missing patterns**:
- `code-review-[0-9]+.md` — created by the hook for per-task code reviews
- `code-post-review-[0-9]+.md` — created by the post-code-review action

After the hook creates `code-review-1.md` and blocks, the main agent fixes issues and creates `code-post-review-1.md`. On the next stop where validation runs (after post-review completes), the validation will find both files and flag them as invalid filenames, blocking the stop.

This means the automated code review workflow would break after the first review iteration because validation rejects the review files.

## Summary

| Severity | Count | IDs |
|----------|-------|-----|
| Critical | 2 | C1 (test failures), C2 (filename validation gap) |
| Medium | 5 | M1 (review file naming), M2 (simplified block messages), M3 (temp file location), M5 (unquoted FILES_TO_REVIEW), M7 (skipped test) |
| Minor | 6 | m2 (tdd flag), m3 (Codex ground-rules), m4 (hooks.json nesting), m5 (log cleanup), m6 (test count gap), m7 (no issue on re-analysis) |

**Overall Assessment**: The core architecture is solid. The hook logic, state transitions, model alternation, and auto-advance mechanics are well-designed and thoroughly tested. The two critical issues (test failures and filename validation gap) need to be fixed before this can be considered production-ready. The medium issues are mostly spec divergences that don't break functionality but reduce correctness and robustness.

VERDICT: FAIL
