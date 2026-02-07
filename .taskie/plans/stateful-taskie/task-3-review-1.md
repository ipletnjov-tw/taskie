# Task 3 Review 1: Auto-Review Logic Implementation

**Reviewer**: Code review action
**Verdict**: FAIL
**Files reviewed**: `taskie/hooks/stop-hook.sh`, all test files, task documentation

## Must-Run Commands

| Command | Result |
|---------|--------|
| `make test` | PARTIAL (56/57 passing, 98.2%) |
| `make test-validation` | PASS (17/17) |

## Issues

### BLOCKING

#### B1: Test 14 failing - auto-advance to all-code-review broken

**File**: `tests/hooks/test-stop-hook-state-transitions.sh:214-237`

Test 14 attempts to verify that code-review auto-advances to all-code-review when no tasks remain, with fresh cycle initialization. The test is failing with the state showing `next_phase=code-review, iteration=0` instead of the expected `next_phase=all-code-review, iteration=0`.

This suggests the auto-advance logic for the code-review -> all-code-review transition is broken. The hook may not be correctly detecting that no tasks remain, or the state write for this specific transition path is failing.

**Impact**: Users will not be able to automatically transition from code-review to all-code-review when all tasks are complete, breaking the workflow.

**Fix required**: Debug and fix the code-review auto-advance logic for the no-tasks-remaining case. Verify the tasks_remain calculation and ensure the state write completes successfully.

### CRITICAL

#### C1: PLUGIN_ROOT variable unused

**File**: `taskie/hooks/stop-hook.sh:14`

The `PLUGIN_ROOT` variable is resolved but never used in the current implementation. While this was intentional (prepared for Task 3), it should actually be used since Task 3 is now complete and the hook calls the `claude` CLI.

**Fix**: Remove if truly unused, or document why it's needed for future use.

#### C2: No test for prompt content verification

**File**: `tests/hooks/test-stop-hook-cli-invocation.sh`

Suite 4 test 8-14 are placeholders. The acceptance criteria specify that prompts should be tested, but there are no tests verifying the actual prompt content passed to the CLI for each review type.

**Fix**: Add tests that verify the prompts contain the expected file paths and review type-specific instructions.

### MINOR

#### M1: Hardcoded systemMessage format inconsistent

**File**: `taskie/hooks/stop-hook.sh:120,266`

The max_reviews=0 message says "Auto-advanced to $ADVANCE_TARGET" but the auto-advance message says "${REVIEW_TYPE} passed". The formatting is inconsistent.

**Recommendation**: Standardize message format across all auto-advance paths.

#### M2: Log file cleanup logic could fail silently

**File**: `taskie/hooks/stop-hook.sh:201`

The `rm -f "$LOG_FILE"` on success could theoretically fail (permissions, disk full, etc.) but this is ignored. While `-f` suppresses errors, the hook should be robust.

**Recommendation**: Not critical since `-f` handles most cases, but consider if this matters for production use.

#### M3: Block message template is generic

**File**: `taskie/hooks/stop-hook.sh:290-296`

The block message is the same for all review types. The template could be more specific per review type (e.g., for plan-review, mention checking the plan; for code-review, mention checking implementation).

**Recommendation**: Differentiate block messages by review type for better UX.

## Acceptance Criteria Checklist

### Subtask 3.1
| Criterion | Status |
|-----------|--------|
| Hook reads state.json with jq default operators | ✅ PASS |
| Identifies review phases correctly | ✅ PASS |
| Falls through to validation for non-review phases | ✅ PASS |
| Falls through for missing/malformed state | ✅ PASS |
| max_reviews==0 skips and auto-advances | ✅ PASS |

### Subtask 3.2
| Criterion | Status |
|-----------|--------|
| phase_iteration incremented before CLI | ✅ PASS |
| Hard stop when max_reviews exceeded | ✅ PASS |
| CLI invoked with correct flags | ✅ PASS |
| Four distinct prompts implemented | ✅ PASS |
| TASK_FILE_LIST built correctly | ✅ PASS |
| Empty list skips review | ✅ PASS |
| Missing task file skips review | ✅ PASS |
| Review file verified after CLI | ✅ PASS |
| CLI failure handled gracefully | ✅ PASS |
| Log file cleanup | ✅ PASS |

### Subtask 3.3
| Criterion | Status |
|-----------|--------|
| Verdict extracted from JSON | ✅ PASS |
| PASS increments consecutive_clean | ✅ PASS |
| FAIL resets consecutive_clean to 0 | ✅ PASS |
| consecutive_clean >= 2 triggers auto-advance | ⚠️ PARTIAL (failing for code-review->all-code-review) |
| Advance targets correct | ⚠️ PARTIAL |
| Fresh cycle init for all-code-review | ❌ FAIL (test 14 failing) |
| Remaining tasks check | ⚠️ NEEDS VERIFICATION |

### Subtask 3.4
| Criterion | Status |
|-----------|--------|
| State written atomically | ✅ PASS |
| phase set to review type | ✅ PASS |
| next_phase set to post-review | ✅ PASS |
| phase_iteration incremented | ✅ PASS |
| review_model toggled | ✅ PASS |
| consecutive_clean written | ✅ PASS |
| Fields preserved | ✅ PASS |
| Block message format | ✅ PASS |

### Subtask 3.5
| Criterion | Status |
|-----------|--------|
| Suite 2: 15 tests | ✅ PASS (19 tests, includes suite 5) |
| Suite 3: 16 tests | ⚠️ PARTIAL (13/16 passing due to test 14) |
| Suite 4: 14 tests | ⚠️ PARTIAL (8 tests, missing tests 8-14) |
| Suite 5: 6 tests | ✅ PASS (integrated with suite 2) |
| TASK_FILE_LIST test exists | ✅ PASS |
| All tests clean up | ✅ PASS |
| make test passes | ❌ FAIL (56/57, test 14 failing) |

## Summary

Task 3 implementation is 98% complete with excellent test coverage (56/57 tests). The core auto-review functionality works correctly for plan-review, tasks-review, and most code-review scenarios. However, there's one BLOCKING issue with the code-review to all-code-review transition that must be fixed.

**Must fix before proceeding**:
- B1: Fix test 14 / code-review auto-advance bug

**Recommended fixes**:
- C1: Address PLUGIN_ROOT usage
- C2: Add prompt content tests

**Total test coverage**: 56/57 passing (98.2%)
- Suite 1: 17/17 ✓
- Suite 2+5: 19/19 ✓
- Suite 3: 13/16 (1 blocking failure)
- Suite 4: 8/8 ✓ (but incomplete, missing tests 8-14)
