# Task 3: Unified Stop Hook — Auto-Review Logic

Implement the core auto-review system in `stop-hook.sh`: state detection (step 5), `claude` CLI invocation with structured JSON output, verdict extraction, state transitions, model alternation, block message templates, auto-advance logic, and atomic state writes. Write test suites 2-5 (51 tests).

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
  - `max_reviews == 0`: sets `phase` to the review phase, sets `next_phase` to the advance target, writes state atomically, approves, does NOT invoke CLI, does NOT increment `phase_iteration`

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
  - Hard stop when `phase_iteration > max_reviews` (approve, no CLI invocation). Output `systemMessage` warning user that max review limit was reached.
  - CLI invoked with `--print`, `--model ${REVIEW_MODEL}`, `--output-format json`, `--json-schema`, `--dangerously-skip-permissions`
  - Four distinct prompt templates for plan-review, tasks-review, code-review, all-code-review
  - `TASK_FILE_LIST` built with `grep '^|' | grep -oE 'task-[0-9]+\.md'` (POSIX)
  - Empty `TASK_FILE_LIST` → skip review, approve with warning
  - Code-review uses `current_task` from state directly (not TASK_FILE_LIST)
  - Review file existence verified after CLI returns
  - CLI failure (exit code, missing review file, not on PATH) → approve with warning
  - CLI subprocess should have a timeout (e.g. `timeout 540` to leave 60s buffer for the hook's 600s total timeout)
  - Log file (`.review-${ITERATION}.log`) cleaned up after successful review, persists on failure for debugging

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
    - tasks-review → `complete-task` or `complete-task-tdd` (based on `tdd`)
    - code-review → `complete-task`/`complete-task-tdd` if tasks remain, `all-code-review` if none remain
    - all-code-review → sets `phase: "complete"`, `next_phase: null` directly (no further routing needed)
  - Auto-advance approves the stop (no block) — user stop point
  - Approve output includes `systemMessage` informing the user what happened and what to do next (e.g. "Code review passed. Run /taskie:continue-plan to proceed.")
  - Remaining tasks check uses grep on `tasks.md` for `pending` status rows

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

### Subtask 3.5: Write test suites 2-5
- **Short description**: Implement all tests for suites 2 (auto-review logic, 15 tests), 3 (state transitions, 16 tests), 4 (CLI invocation, 14 tests), and 5 (block message templates, 6 tests) as specified in the plan. Tests use the mock `claude` CLI and shared helpers. Each test creates its own temp directory and cleans up in a trap. Tests should be written incrementally as each implementation subtask (3.1-3.4) completes — e.g., write suite 2 tests 4-5, 8-11 after 3.1, suite 4 tests after 3.2, etc. — then finalized as a single commit after all implementation is done.
- **Status**: pending
- **Sample git commit message**: Add test suites 2-5 for auto-review, state transitions, CLI invocation, block messages
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 8
- **Test approach**: Run `make test` and verify all 51 tests pass. Verify each test file is self-contained and cleans up after itself.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - `tests/hooks/test-stop-hook-auto-review.sh` contains 15 tests (suite 2) + 6 tests (suite 5) = 21 tests
  - `tests/hooks/test-stop-hook-state-transitions.sh` contains 16 tests (suite 3)
  - `tests/hooks/test-stop-hook-cli-invocation.sh` contains 14 tests (suite 4)
  - All tests source shared helpers and use mock claude
  - All tests clean up temp directories in trap handlers
  - `make test` passes with all 51 tests green
