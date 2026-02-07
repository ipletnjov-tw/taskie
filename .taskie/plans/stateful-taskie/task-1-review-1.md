# Task 1 Review: Test Infrastructure

**Reviewer**: Code review action
**Verdict**: FAIL
**Files reviewed**: `tests/hooks/helpers/test-utils.sh`, `tests/hooks/helpers/mock-claude.sh`, `run-tests.sh`, `Makefile`, `task-1.md`

## Must-Run Commands

| Command | Result |
|---------|--------|
| `bash -n tests/hooks/helpers/test-utils.sh` | PASS (no syntax errors) |
| `bash -n tests/hooks/helpers/mock-claude.sh` | PASS (no syntax errors) |
| `make test` | PASS (13/13 tests pass) |
| `make test-validation` | PASS (13/13 tests pass) |

## Issues

### BLOCKING

#### B1: `pass()` and `fail()` functions return exit code 1 on first invocation

**File**: `tests/hooks/helpers/test-utils.sh:10,18`

The `((PASS_COUNT++))` and `((FAIL_COUNT++))` arithmetic expansions return exit code 1 when the variable is 0, because `0++` evaluates to 0, and `(( 0 ))` returns exit code 1 in bash. This means:

- Under `set -e`, the first call to `pass()` or `fail()` will abort the script
- Even without `set -e`, the function's return value is 1 (failure) on the first call

**Reproduction**:
```bash
bash -c 'set -e; source tests/hooks/helpers/test-utils.sh; pass "test1"; echo "never reached"'
# Output: "PASS: test1" then exit code 1, "never reached" is never printed
```

The existing `test-validate-ground-rules.sh` does NOT use `test-utils.sh` (it has its own `pass`/`fail` that use `$((VAR + 1))`), so this bug hasn't been caught yet. But all future test suites (Tasks 2-6) are expected to source `test-utils.sh` and will hit this immediately.

**Fix**: Replace `((PASS_COUNT++))` with `PASS_COUNT=$((PASS_COUNT + 1))` (or `((++PASS_COUNT))` which starts at 1, or `((PASS_COUNT++)) || true`). Same for `FAIL_COUNT`.

### CRITICAL

#### C1: `run-tests.sh` `all` and `hooks` cases are identical copy-paste

**File**: `run-tests.sh:44-60`

The `all)` and `hooks)` cases contain exactly the same code block (a for-loop over `tests/hooks/test-*.sh`). Currently they are semantically the same, but having two identical code blocks is a maintenance risk — if one is updated but not the other, they'll silently diverge.

**Fix**: Either combine them with `all|hooks)` or extract a function.

### MINOR

#### M1: Shebang portability — `#!/bin/bash` vs `#!/usr/bin/env bash`

**Files**: `run-tests.sh:1`, `tests/hooks/test-validate-ground-rules.sh:1`

The new helper files correctly use `#!/usr/bin/env bash` (portable), but `run-tests.sh` and the existing test file use `#!/bin/bash` (not portable). On NixOS, `/bin/bash` doesn't exist, so `./run-tests.sh` fails with "bad interpreter". The Makefile works around this by using `@bash ./run-tests.sh`, but direct execution is broken.

Not blocking since `make test` works, but inconsistent with the helpers.

#### M2: `--verbose` flag was removed without replacement

**File**: `run-tests.sh` (diff)

The original `run-tests.sh` supported a `--verbose` flag that was passed through to test files. The rewrite removed this capability entirely. The existing test file `test-validate-ground-rules.sh` accepts `--verbose` (line 25: `VERBOSE="${1:-}"`), but there's no way to pass it through `run-tests.sh` anymore.

Not blocking for Task 1 scope, but the verbose functionality was lost.

#### M3: `state` suite silently succeeds when no test files exist

**File**: `run-tests.sh:63-69`

The `state` suite iterates over a hardcoded list of test files and uses `if [ -f ... ]` to skip missing ones. If none of the files exist (which is the current state), the suite succeeds silently with no output beyond the header. This is correct behavior for now (tests will be created in Task 3), but could mask issues if files are accidentally deleted later.

#### M4: Clean target removes Python artifacts but project is bash-only

**File**: `Makefile:30-33`

The `clean` target removes `__pycache__` and `.pyc` files, which is irrelevant for a bash-only project. This appears to be leftover from a template and should be updated to clean bash test artifacts (temp dirs, etc.) if needed.

## Acceptance Criteria Checklist

| Criterion | Status | Notes |
|-----------|--------|-------|
| **Subtask 1.1**: File exists at `tests/hooks/helpers/test-utils.sh` | PASS | |
| All 8 functions implemented | PASS | `pass`, `fail`, `create_test_plan`, `create_state_json`, `run_hook`, `assert_approved`, `assert_blocked`, `print_results` |
| `create_test_plan` creates dir with `plan.md` and `tasks.md` | PASS | Valid table format confirmed |
| `run_hook` captures stdout, stderr, exit code separately | PASS | Uses temp files |
| `print_results` exits 1 if failures | PASS | |
| `assert_approved` checks exit 0 and no block decision | PASS | |
| `assert_blocked` checks exit 0 and block decision with optional pattern | PASS | |
| `create_state_json` accepts dir path and JSON string | PASS | |
| `pass()`/`fail()` work correctly | **FAIL** | B1: returns exit code 1 on first call |
| **Subtask 1.2**: File exists and is executable | PASS | `-rwxr-xr-x` |
| Logs invocation args | PASS | |
| Writes review file (PASS/FAIL content) | PASS | Verified both variants |
| Returns structured JSON on stdout | PASS | All 4 fields present, `jq -r '.result.verdict'` works |
| Exits with configured exit code | PASS | |
| Sleeps for delay | PASS | |
| Accepts all CLI flags gracefully | PASS | |
| No real API calls | PASS | |
| **Subtask 1.3**: `run-tests.sh` accepts all arguments | PASS | `all`, `hooks`, `state`, `validation`, file path |
| `state` runs correct test files | PASS | (files don't exist yet, correct per plan) |
| `validation` runs correct test file | PASS | Falls back to `test-validate-ground-rules.sh` |
| `make test-state` target | PASS | |
| `make test-validation` target | PASS | |
| `make test-hooks` target | PASS | |
| `make test` runs all tests | PASS | |
| Single file execution | PASS | (requires `bash` prefix on NixOS) |

## Summary

The implementation is mostly solid. The mock-claude.sh is well-designed and the test helpers cover the right abstractions. However, there is one **blocking** issue (B1) that will cause all future test suites to fail on their first test case when they source `test-utils.sh`. This must be fixed before proceeding to Task 2.
