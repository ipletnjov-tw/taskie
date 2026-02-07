# Task 1: Test Infrastructure

**Prerequisites**: None (this task MUST complete before any other task begins).

Set up the shared test helpers, mock `claude` CLI, and test runner/Makefile updates that all other tasks depend on.

## Subtasks

### Subtask 1.1: Create shared test helpers (`tests/hooks/helpers/test-utils.sh`)
- **Short description**: Extract common test patterns into a shared helper file with `pass()`, `fail()`, `create_test_plan()`, `create_state_json()`, `run_hook()`, `assert_approved()`, `assert_blocked()`, and `print_results()` functions.
- **Status**: pending
- **Sample git commit message**: Add shared test helpers for hook tests
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 4
- **Test approach**: Source the file and verify each function works: `pass` increments counter, `fail` increments counter, `create_test_plan` creates a valid plan directory, `run_hook` captures stdout+stderr+exit code, assertions work correctly.
- **Must-run commands**: `bash -n tests/hooks/helpers/test-utils.sh` (syntax check)
- **Acceptance criteria**:
  - File exists at `tests/hooks/helpers/test-utils.sh`
  - All 8 functions listed in the plan are implemented: `pass`, `fail`, `create_test_plan`, `create_state_json`, `run_hook`, `assert_approved`, `assert_blocked`, `print_results`
  - `create_test_plan` creates a directory with `plan.md` and `tasks.md` (valid table format)
  - `run_hook` pipes JSON to the hook, captures stdout, stderr, and exit code separately
  - `print_results` exits 1 if any failures occurred

### Subtask 1.2: Create mock claude CLI (`tests/hooks/helpers/mock-claude.sh`)
- **Short description**: Create a mock `claude` CLI script that simulates the real CLI based on environment variables: `MOCK_CLAUDE_EXIT_CODE`, `MOCK_CLAUDE_REVIEW_DIR`, `MOCK_CLAUDE_REVIEW_FILE`, `MOCK_CLAUDE_DELAY`, `MOCK_CLAUDE_LOG`, `MOCK_CLAUDE_VERDICT`. **Note:** The mock code sample in `plan.md` is outdated (predates the JSON verdict change). Follow the acceptance criteria below, not the plan's code sample.
- **Status**: pending
- **Sample git commit message**: Add mock claude CLI for hook tests
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 3
- **Test approach**: Run the mock directly with various environment variable combinations and verify behavior: review file written, exit code returned, args logged, delay observed.
- **Must-run commands**: `bash -n tests/hooks/helpers/mock-claude.sh` (syntax check)
- **Acceptance criteria**:
  - File exists at `tests/hooks/helpers/mock-claude.sh` and is executable
  - Logs invocation args to `MOCK_CLAUDE_LOG` when set
  - Writes a review file to `MOCK_CLAUDE_REVIEW_DIR/MOCK_CLAUDE_REVIEW_FILE` when both are set (review content is plain markdown without VERDICT lines — the verdict is returned via stdout JSON separately)
  - Returns structured JSON on stdout matching `--output-format json` format: `{"result":{"verdict":"PASS"}}` or `{"result":{"verdict":"FAIL"}}` based on `MOCK_CLAUDE_VERDICT` (default `FAIL`). The hook extracts the verdict via `jq -r '.result.verdict'`.
  - Exits with `MOCK_CLAUDE_EXIT_CODE` (default 0)
  - Sleeps for `MOCK_CLAUDE_DELAY` seconds when set
  - Gracefully accepts all CLI flags the hook passes (`--print`, `--model`, `--output-format`, `--json-schema`, `--dangerously-skip-permissions`) without errors — flags are logged but don't alter mock behavior
  - Does NOT make any real API calls

### Subtask 1.3: Update test runner and Makefile
- **Short description**: Update `run-tests.sh` to discover and run all `test-*.sh` files in `tests/hooks/`. Add `make test-state` and `make test-validation` targets to the Makefile. Support running a single test file by path.
- **Status**: pending
- **Sample git commit message**: Update test runner and Makefile for new test suites
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 3
- **Test approach**: Run `make test` and verify it discovers all test files. Run `make test-validation` and verify it runs only validation tests. Run `./run-tests.sh tests/hooks/test-stop-hook-validation.sh` and verify single-file execution.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - `run-tests.sh` accepts arguments: `all` (default), `hooks`, `state`, `validation`, or a specific file path
  - `make test-state` runs only state/auto-review test files
  - `make test-validation` runs only the validation test file
  - `make test` runs all tests (existing behavior preserved)
  - Single file execution works: `./run-tests.sh tests/hooks/test-stop-hook-validation.sh`
