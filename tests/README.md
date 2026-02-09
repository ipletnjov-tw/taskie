# Taskie Test Suite

This directory contains automated tests for the Taskie framework components.

## Usage

```bash
./run-tests.sh              # Run all tests
./run-tests.sh hooks        # Run all hook tests
./run-tests.sh state        # Run state/auto-review tests
./run-tests.sh validation   # Run validation tests only
make test                   # Run all tests via Make
make test-validation        # Run validation tests
make test-state             # Run state/auto-review tests
./run-tests.sh logging      # Run logging tests
make test-logging           # Run logging tests
```

## Test Organization

```
tests/
├── README.md
└── hooks/
    ├── helpers/
    │   ├── test-utils.sh              # Shared test helper functions
    │   ├── mock-claude.sh             # Mock claude CLI for testing
    │   └── claude                     # Symlink to mock-claude.sh
    ├── test-stop-hook-validation.sh   # Test suite 1: validation rules 1-8
    ├── test-stop-hook-auto-review.sh  # Test suites 2 & 5: auto-review triggers
    ├── test-stop-hook-state-transitions.sh  # Test suite 3: state transitions
    ├── test-stop-hook-cli-invocation.sh     # Test suite 4: CLI invocation
    ├── test-stop-hook-edge-cases.sh   # Test suite 6: edge cases & integration
    ├── test-stop-hook-logging.sh      # Test suite 7: hook logging
    └── test-stop-hook-cli-logging.sh  # Test suite 8: CLI real-time logging

Repo root:
├── run-tests.sh                       # Test runner script
└── Makefile                           # Test targets
```

## Test Suite 1: Validation Rules

The `test-stop-hook-validation.sh` script validates the unified Stop hook's validation logic:

1. **Dependency Check** - Verifies jq is installed
2. **Invalid JSON Input** - Tests malformed JSON handling (exit 2)
3. **Invalid Directory** - Tests non-existent directory handling (exit 2)
4. **Infinite Loop Prevention** - Tests stop_hook_active flag
5. **Non-Taskie Projects** - Tests graceful skip when no .taskie directory
6. **Valid Plan Structure** - Tests successful validation
7. **Invalid Plan Structure** - Tests missing plan.md and invalid filename
8. **Nested Directories** - Tests files in subdirectories of a plan
9. **Review Without Base File** - Tests review file without its base document
10. **Post-Review Without Review** - Tests post-review without matching review
11. **Task Files Without tasks.md** - Tests task files present but tasks.md missing
12. **Non-Table tasks.md** - Tests tasks.md containing prose instead of a table
13. **Empty tasks.md** - Tests tasks.md with no table rows
14. **state.json Not Rejected** - Tests that state.json is not rejected by filename validation
15. **Invalid JSON in state.json** - Tests that invalid JSON logs warning but doesn't block
16. **Missing Fields in state.json** - Tests that missing required fields log warning but don't block
17. **Valid state.json** - Tests that valid state.json produces no warnings

### Expected Behavior

| Test Scenario | Exit Code | Output Type | Decision |
|---------------|-----------|-------------|----------|
| Missing jq | 2 | stderr | Operational error |
| Invalid JSON | 2 | stderr | Operational error |
| Invalid directory | 2 | stderr | Operational error |
| stop_hook_active | 0 | JSON (suppressOutput) | Allow stop |
| No .taskie dir | 0 | JSON (suppressOutput) | Allow stop |
| Valid plan | 0 | JSON (systemMessage) | Allow stop |
| Invalid plan | 0 | JSON (decision: block) | Block stop |
| Nested directories | 0 | JSON (decision: block) | Block stop |
| Review without base | 0 | JSON (decision: block) | Block stop |
| Post-review without review | 0 | JSON (decision: block) | Block stop |
| Tasks without tasks.md | 0 | JSON (decision: block) | Block stop |
| Non-table tasks.md | 0 | JSON (decision: block) | Block stop |
| Empty tasks.md | 0 | JSON (decision: block) | Block stop |
| state.json present | 0 | JSON (systemMessage) | Allow stop |
| Invalid JSON in state.json | 0 | stderr warning + JSON | Allow stop |
| Missing fields in state.json | 0 | stderr warning + JSON | Allow stop |
| Valid state.json | 0 | JSON (systemMessage) | Allow stop |

## Test Suites 2-5: Auto-Review Logic (Task 3)

Test suites 2-5 test the automated review functionality:
- **Suite 2 & 5**: Auto-review trigger conditions and block messages (22 tests)
- **Suite 3**: State transitions and phase changes (14 tests)
- **Suite 4**: CLI invocation and flags (8 tests)

## Test Suite 6: Edge Cases & Integration (Task 6)

Test suite 6 tests edge cases and integration scenarios:
- max_reviews=0 handling
- Auto-advance transitions
- Model alternation integration
- State field preservation
- 12 tests total

## Test Suite 7: Hook Logging

Test suite 7 tests the per-invocation hook logging system:
- Log directory creation (`.taskie/logs/`)
- Log file creation per invocation (`hook-{timestamp}.log`)
- Invocation header present in log
- State fields logged when state.json exists
- Review decision logged when review triggers
- CLI invocation logged
- Validation result logged
- No log files for non-Taskie projects
- Multiple invocations create separate files
- 9 tests total

## Test Suite 8: CLI Real-Time Logging

Test suite 8 tests the real-time Claude CLI output logging with `tee`:
- CLI log file created (`.taskie/logs/cli-{timestamp}-{type}-{iter}.log`)
- CLI log filename pattern includes review type and iteration
- CLI log contains mock JSON output (verdict, session_id, cost)
- CLI log preserved after successful review (not deleted)
- Hook log references CLI log file location
- Multiple CLI invocations create separate log files
- CLI log filename format validation (timestamp + type + iteration)
- 7 tests total

## Shared Test Helpers

The `tests/hooks/helpers/test-utils.sh` file provides common functions:

- `pass(message)` - Mark a test as passed
- `fail(message)` - Mark a test as failed
- `create_test_plan(dir)` - Create a valid test plan structure
- `create_state_json(dir, json)` - Create state.json with provided JSON
- `run_hook(json_input)` - Run hook and capture stdout/stderr/exit code
- `assert_approved()` - Assert hook approved the stop
- `assert_blocked([pattern])` - Assert hook blocked with optional reason pattern
- `print_results()` - Print test results and exit

The `tests/hooks/helpers/mock-claude.sh` provides a mock Claude CLI for testing:

- Configured via environment variables (MOCK_CLAUDE_VERDICT, MOCK_CLAUDE_EXIT_CODE, etc.)
- Simulates the real CLI's JSON output format
- Logs invocation arguments for verification
- Supports delays for timeout testing
