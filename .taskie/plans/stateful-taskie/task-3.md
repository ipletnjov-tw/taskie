# Task 3: Unified Stop Hook — Auto-Review Logic

**Prerequisites**: Task 2 (stop-hook.sh must exist with steps 1-4 and step 6 validation already implemented).

Implement the core auto-review system in `stop-hook.sh`: state detection (step 5), `claude` CLI invocation with structured JSON output, verdict extraction, state transitions, model alternation, block message templates, auto-advance logic, and atomic state writes. Write test suites 2-5 (51 tests).

**Note on hook steps**: Steps 1-3 (input parsing, `.taskie/plans` check, plan directory detection) and step 6 (validation fallback) are implemented in Task 2. This task implements step 5 (the auto-review logic that sits between plan detection and validation).

## Subtasks

### Subtask 3.1: Implement state.json reading and review phase detection (step 5)
- **Short description**: After validation setup (step 4), read `state.json` with `jq` default operators. Check if `next_phase` is a review phase (`plan-review`, `tasks-review`, `code-review`, `all-code-review`). If not a review phase, fall through to step 6 (validation). If `state.json` is missing or malformed, fall through to validation. Implement step 5a: `max_reviews == 0` early return — set `next_phase` to the advance target, write state atomically, approve.
- **Status**: pending
- **Sample git commit message**: Implement state reading and review phase detection in stop-hook
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 5
- **Test approach**: Test suite 2, tests 4-5, 8-11: standalone mode, post-review phases, missing/malformed state, non-review next_phase values. Test suite 6, test 8: max_reviews=0 skip.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - Hook reads `state.json` using `jq` with default operators for all fields
  - Correctly identifies review phases in `next_phase`
  - Falls through to validation when `next_phase` is null, a post-review phase, or a non-review advance target
  - Falls through to validation when `state.json` is missing or malformed (with warning)
  - `max_reviews == 0`: sets `phase` to the review phase, sets `next_phase` to the advance target, writes `phase_iteration: 0` (no increment, but must be written for state consistency), writes state atomically, approves, does NOT invoke CLI

### Subtask 3.2: Implement `claude` CLI invocation and review file verification (step 5b-e)
- **Short description**: Implement step 5b (increment `phase_iteration`), step 5c (`phase_iteration <= max_reviews` check — hard stop if exceeded), step 5d (`claude` CLI invocation with `--print`, `--model`, `--output-format json`, `--json-schema`, `--dangerously-skip-permissions`, correct prompt per review type, stderr to log file), step 5e (verify review file was written to disk). Build `TASK_FILE_LIST` with POSIX-compatible grep for tasks-review and all-code-review prompts. Use `current_task` directly for code-review prompts.
- **Status**: pending
- **Sample git commit message**: Implement claude CLI invocation and review file verification
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 7
- **Test approach**: Test suite 2, tests 1-3, 6-7, 12: review triggers for all four types, max reviews reached, all-code-review trigger. Test suite 4, tests 1-14: CLI flag verification, prompt content, review file paths, failure handling.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - `phase_iteration` incremented before CLI invocation
  - Hard stop when `phase_iteration > max_reviews` (approve, no CLI invocation). Output `systemMessage`: "Max review limit (${MAX_REVIEWS}) reached for ${REVIEW_TYPE}. Edit state.json to adjust max_reviews or set next_phase manually."
  - CLI invoked with `--print`, `--model ${REVIEW_MODEL}`, `--output-format json`, `--json-schema '{"type":"object","properties":{"verdict":{"type":"string","enum":["PASS","FAIL"]}},"required":["verdict"]}'`, `--dangerously-skip-permissions`
  - Four distinct prompt templates for plan-review, tasks-review, code-review, all-code-review
  - `TASK_FILE_LIST` built by extracting numeric task IDs from column 2 (Id column) of `tasks.md` table rows (skip header rows with `tail -n +3`), then constructing filenames: `grep '^|' tasks.md | tail -n +3 | awk -F'|' '{gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9]+$/) printf ".taskie/plans/'${PLAN_ID}'/task-%s.md ", $2}'`
  - Empty `TASK_FILE_LIST` → skip review, approve with warning (applies to tasks-review and all-code-review only)
  - Missing `task-${current_task}.md` during code-review → skip review, approve with warning
  - Code-review uses `current_task` from state directly (not TASK_FILE_LIST)
  - Review file existence verified after CLI returns
  - CLI failure (exit code, missing review file, not on PATH) → approve with warning
  - CLI subprocess timeout is handled by Claude Code's 600s hook timeout — do NOT use the shell `timeout` command (not available on macOS). If the hook is killed by the system timeout, the stop is allowed through by default. **KNOWN LIMITATION**: If the hook times out after incrementing `phase_iteration` but before writing the review file, `state.json` will be left inconsistent. **RECOVERY MECHANISM**: The crash recovery heuristic in Task 4.2 (`continue-plan.md`) automatically handles this timeout-induced inconsistency by checking artifact completeness (review file existence) when resuming with `next_phase` set to a review phase.
  - Log file (`.review-${ITERATION}.log`) cleaned up after successful review (CLI exited 0 and review file was written, regardless of PASS/FAIL verdict), persists on CLI failure for debugging

### Subtask 3.3: Implement verdict extraction and consecutive clean tracking (step 5f-g)
- **Short description**: Extract verdict from `CLI_OUTPUT` via `jq -r '.result.verdict'`. If `PASS`, increment `consecutive_clean`. If `FAIL` or parse failure, reset `consecutive_clean` to 0. Implement step 5g: if `consecutive_clean >= 2`, auto-advance — set `next_phase` to the advance target based on review type and `tdd` field. For code review, check `tasks.md` for remaining pending tasks to decide between `complete-task` variant and `all-code-review`. For all-code-review advance, enter fresh review cycle (`phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`). Approve the stop (user stop point).
- **Status**: pending
- **Sample git commit message**: Implement verdict extraction and auto-advance logic
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 7
- **Test approach**: Test suite 2, tests 13-15: one clean (not enough), two clean (advance), clean-then-dirty (reset). Test suite 3, tests 9-15: consecutive_clean state changes, all four advance targets, all-fields-updated check.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - Verdict extracted from structured JSON output via `jq -r '.result.verdict'`
  - `PASS` → increment `consecutive_clean`; `FAIL` or parse error → reset to 0
  - `consecutive_clean >= 2` → auto-advance with correct advance target:
    - plan-review → `create-tasks`
    - tasks-review → `complete-task-tdd` if `tdd == true`, `complete-task` if `tdd == false`
    - code-review (tasks remain) → `complete-task-tdd` if `tdd == true`, `complete-task` if `tdd == false`
    - code-review (no tasks remain) → `all-code-review` with fresh cycle init (`phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`)
    - all-code-review → `complete` (letting `continue-plan` handle final phase transition to `phase: "complete"`, `next_phase: null`)
  - Auto-advance approves the stop (no block) — user stop point
  - Approve output includes `systemMessage` informing the user what happened and what to do next (e.g. "Code review passed. Run /taskie:continue-plan to proceed.")
  - Remaining tasks check: `grep '^|' tasks.md | tail -n +3 | awk -F'|' -v cur="${CURRENT_TASK}" '{gsub(/[[:space:]]/, "", $2); if ($2 != cur) print $3}' | grep -i 'pending' | wc -l` — skips header rows, extracts status column (3rd field) for all tasks except current (exact Id match on stripped column 2), avoids partial matches that would incorrectly exclude task 10/11/12 when current is task 1. If count > 0, tasks remain.

### Subtask 3.4: Implement block message templates and state update for non-advance (step 5h)
- **Short description**: When `consecutive_clean < 2`, write state atomically (set `phase` to review phase, `next_phase` to post-review phase, incremented `phase_iteration`, toggled `review_model`, `consecutive_clean`). Return block decision with the correct template per review type. Templates must include: review file path, post-review action name, state.json update instructions (read-modify-write, temp file + mv), escape hatch note. Model alternation: `opus` ↔ `sonnet`.
- **Status**: pending
- **Sample git commit message**: Implement block messages and non-advance state updates
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 5
- **Test approach**: Test suite 3, tests 1-8: state correctly updated after review for all four types, model alternation, field preservation. Test suite 5, tests 1-6: block message content verification.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - State written atomically (temp file + `mv`)
  - `phase` set to the review phase (e.g. `"code-review"`)
  - `next_phase` set to the corresponding post-review phase
  - `phase_iteration` incremented
  - `review_model` toggled: `opus` → `sonnet`, `sonnet` → `opus`
  - `consecutive_clean` written (incremented or reset)
  - `max_reviews`, `current_task`, `tdd` preserved unchanged
  - Block message contains: review file path, post-review action, state.json instructions, escape hatch
  - Four distinct templates for code-review, plan-review, tasks-review, all-code-review

### Subtask 3.5: Verify test suites 2-5 (tracking/verification subtask)
- **Short description**: This is a tracking/verification subtask to ensure all tests for suites 2-5 are present and passing after subtasks 3.1-3.4 complete. Tests should be written and committed alongside each implementation subtask (3.1-3.4), NOT deferred to a separate phase. **Implementation approach**: As you complete each implementation subtask, immediately write and commit the corresponding tests. For example: write and commit suite 2 tests 4-5, 8-11 immediately after completing 3.1; write and commit suite 4 tests immediately after completing 3.2. This subtask serves as the final verification that all 51 tests exist and pass, not as a separate implementation phase.
- **Status**: pending
- **Sample git commit message**: Tests should be committed incrementally with each implementation subtask (e.g., "Add suite 2 tests for state detection and max_reviews logic", "Add suite 4 tests for CLI invocation", etc.)
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 8
- **Test approach**: Write and commit tests incrementally alongside subtasks 3.1-3.4 implementation. Run `make test` after each commit to verify tests pass. Final verification: all 51 tests pass and each test file is self-contained with cleanup.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - `tests/hooks/test-stop-hook-auto-review.sh` contains 15 tests (suite 2) + 6 tests (suite 5) = 21 tests
  - `tests/hooks/test-stop-hook-state-transitions.sh` contains 16 tests (suite 3)
  - `tests/hooks/test-stop-hook-cli-invocation.sh` contains 14 tests (suite 4)
  - Suite 4 includes a test that verifies `TASK_FILE_LIST` construction: creates a `tasks.md` with known task IDs (e.g. 1, 2, 3), triggers tasks-review or all-code-review, and checks that `MOCK_CLAUDE_LOG` contains the expected file paths (`task-1.md`, `task-2.md`, `task-3.md`) to catch regressions in the awk-based ID extraction
  - All tests source shared helpers and use mock claude
  - All tests clean up temp directories in trap handlers
  - `make test` passes with all 51 tests green
  - Tests implicitly verify steps 1-3 (from Task 2) work correctly since auto-review tests require valid input parsing and plan detection to function
