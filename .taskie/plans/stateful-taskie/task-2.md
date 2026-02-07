# Task 2: Unified Stop Hook — Validation Migration

**Prerequisites**: Task 1 (test infrastructure must exist before test refactoring in subtask 2.3).

Create `stop-hook.sh` that replaces `validate-ground-rules.sh`. Port all existing validation rules (1-7) unchanged, add state.json validation (rule 8), update hook registration in `plugin.json`. Write test suite 1 (17 tests).

## Subtasks

### Subtask 2.1: Create `stop-hook.sh` with hook boilerplate and input parsing
- **Short description**: Create `taskie/hooks/stop-hook.sh` with the unified hook structure: read JSON from stdin, extract `cwd` and `stop_hook_active`, validate inputs, `cd` into `cwd`, check for `stop_hook_active` (approve immediately if true), check for `.taskie/plans` directory. Resolve `PLUGIN_ROOT` relative to the hook's location. Note: hook timeout (600 seconds) and hook registration are handled in subtask 2.5, not here.
- **Status**: pending
- **Sample git commit message**: Create stop-hook.sh with input parsing and boilerplate
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 4
- **Test approach**: Test suite 1, tests 1-5: jq check, invalid JSON, invalid directory, stop_hook_active, no .taskie directory.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - File exists at `taskie/hooks/stop-hook.sh` and is executable
  - Reads JSON from stdin, extracts `cwd` and `stop_hook_active`
  - Exits with code 2 + stderr message on invalid JSON or invalid directory
  - Approves immediately with `{"suppressOutput": true}` when `stop_hook_active` is true
  - Executes `cd "$CWD"` after validating the directory exists, before any `.taskie/plans` checks
  - Approves with `{"suppressOutput": true}` when `.taskie/plans` doesn't exist
  - `PLUGIN_ROOT` resolved as `$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)`
  - Finds the most recently modified plan directory using `find` with `\( -name "*.md" -o -name "state.json" \)` to consider both markdown and state.json modification times

### Subtask 2.2: Port validation rules 1-7 from `validate-ground-rules.sh`
- **Short description**: Copy the existing validation logic (rules 1-7) into `stop-hook.sh`. The validation runs in step 6 of the hook logic — after auto-review has been handled or when falling through. Find the most recently modified plan directory using `find` with `\( -name "*.md" -o -name "state.json" \)`. Preserve all existing rule behavior exactly.
- **Status**: pending
- **Sample git commit message**: Port validation rules 1-7 to stop-hook.sh
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 5
- **Test approach**: Test suite 1, tests 6-13: all original validation tests pass against the new hook with identical behavior.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - All 7 validation rules from `validate-ground-rules.sh` are present in `stop-hook.sh`
  - The `find` heuristic includes `state.json` in modification time consideration
  - Rules produce identical block/approve decisions as the original hook
  - Tests 6-13 from test suite 1 all pass

### Subtask 2.3: Refactor and rename existing validation tests
- **Short description**: Refactor `tests/hooks/test-validate-ground-rules.sh` to source `test-utils.sh` for common functions. Rename the file to `tests/hooks/test-stop-hook-validation.sh` to match the new hook name. Update the test file to point at `stop-hook.sh` instead of `validate-ground-rules.sh`. Preserve all 13 existing test cases with identical behavior.
- **Status**: pending
- **Sample git commit message**: Refactor validation tests to use shared helpers, point at stop-hook.sh
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 4
- **Test approach**: Run the refactored test file and verify all 13 tests still pass with the same pass/fail outcomes as before the refactor.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - Old file `tests/hooks/test-validate-ground-rules.sh` is removed
  - New file `tests/hooks/test-stop-hook-validation.sh` exists
  - New file sources `tests/hooks/helpers/test-utils.sh`
  - Tests point at `taskie/hooks/stop-hook.sh` (not the old hook)
  - All 13 original tests pass with identical behavior
  - Test output format is consistent with shared helpers

### Subtask 2.4: Add state.json validation (rule 8) and write tests 14-17
- **Short description**: Add rule 8: if `state.json` exists, validate that it is valid JSON and contains the required fields (`phase`, `next_phase`, `review_model`, `max_reviews`, `consecutive_clean`, `tdd`). If validation fails, log a warning to stderr but do NOT block the stop. Use `jq` default operators for reading fields to handle forward-compatibility. Write tests 14-17 for suite 1.
- **Status**: pending
- **Sample git commit message**: Add state.json validation rule and tests 14-17
- **Git commit hash**:
- **Priority**: medium
- **Complexity**: 4
- **Test approach**: Test suite 1, tests 14-17: state.json not rejected by filename validation, invalid JSON warning, missing fields warning, valid state.json passes.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - `state.json` is not matched by rule 2 (filename validation for `.md` files)
  - Invalid JSON in `state.json` logs a warning but doesn't block
  - Missing required fields log a warning but don't block
  - Valid `state.json` produces no warnings
  - All fields read with `jq` default operators (e.g. `(.consecutive_clean // 0)`)
  - Tests 14-17 added to `test-stop-hook-validation.sh`
  - All 17 tests in suite 1 pass

### Subtask 2.5: Update hook registration and remove old hook
- **Short description**: Update `taskie/.claude-plugin/plugin.json` to register `stop-hook.sh` instead of `validate-ground-rules.sh`. Set the timeout to 600 seconds. Remove `validate-ground-rules.sh`. Bump the plugin version (MAJOR bump — the stateful hook changes workflow behavior and replaces the validation hook).
- **Status**: pending
- **Sample git commit message**: Register stop-hook.sh in plugin.json, remove old hook, bump version
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 2
- **Test approach**: Verify `plugin.json` references `stop-hook.sh`, old hook is removed, `make test-validation` passes.
- **Must-run commands**: `make test-validation`
- **Acceptance criteria**:
  - `plugin.json` hook entry points to `hooks/stop-hook.sh` with 600-second timeout
  - `validate-ground-rules.sh` is removed
  - Plugin version bumped in both `.claude-plugin/marketplace.json` and `taskie/.claude-plugin/plugin.json` (MAJOR: 2.2.1 → 3.0.0)
  - Update `README.md` latest version reference to match
  - Update `tests/README.md` with new test file descriptions
  - All 17 tests in test suite 1 pass
  - `make test-validation` passes
