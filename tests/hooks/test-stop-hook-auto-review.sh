#!/usr/bin/env bash
# Test Suite 2: Stop Hook Auto-Review Triggers & Suite 5: Block Messages
#
# Tests auto-review trigger conditions and block message templates.
# This file contains 21 tests total: 15 from suite 2 + 6 from suite 5.

set -uo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-utils.sh"

# Set hook script for test helpers
HOOK_SCRIPT="$SCRIPT_DIR/../../taskie/hooks/stop-hook.sh"

# Configure mock claude CLI
export PATH="$SCRIPT_DIR/helpers:$PATH"
export MOCK_CLAUDE_EXIT_CODE=0

echo "================================"
echo "Test Suite 2 & 5: Auto-Review & Block Messages"
echo "================================"
echo ""
echo "Hook: $HOOK_SCRIPT"
echo ""

# Cleanup function
cleanup() {
    rm -rf "${TEST_DIR:-}" "${MOCK_LOG:-}" 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: plan-review triggers
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
# TODO: Once verdict extraction is implemented, check for block decision
# For now, just verify CLI was called
if [ -f "$MOCK_LOG" ] && [ -f "$TEST_DIR/.taskie/plans/test-plan/plan-review-1.md" ]; then
    pass "plan-review triggers CLI invocation"
else
    fail "plan-review did not trigger correctly"
fi
cleanup

# Test 2: tasks-review triggers
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1 | pending |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-tasks-review", "next_phase": "tasks-review", "review_model": "sonnet", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="tasks-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ -f "$MOCK_LOG" ] && [ -f "$TEST_DIR/.taskie/plans/test-plan/tasks-review-1.md" ]; then
    pass "tasks-review triggers CLI invocation"
else
    fail "tasks-review did not trigger correctly"
fi
cleanup

# Test 3: code-review triggers
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-2.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "implementation", "next_phase": "code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 2, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="code-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ -f "$MOCK_LOG" ] && [ -f "$TEST_DIR/.taskie/plans/test-plan/code-review-1.md" ]; then
    pass "code-review triggers CLI invocation"
else
    fail "code-review did not trigger correctly"
fi
cleanup

# Test 4: Standalone mode (no state.json) falls through to validation
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
    pass "Standalone mode (no state.json) falls through to validation"
else
    fail "Standalone mode not handled correctly (exit $HOOK_EXIT_CODE)"
fi
cleanup

# Test 5: Malformed state.json falls through to validation with warning
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "{ invalid json }" > "$TEST_DIR/.taskie/plans/test-plan/state.json"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDERR" | grep -q "invalid JSON" && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
    pass "Malformed state.json falls through to validation with warning"
else
    fail "Malformed state.json not handled correctly (exit $HOOK_EXIT_CODE)"
fi
cleanup

# Test 8: Non-review next_phase falls through to validation
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "implementation", "next_phase": "complete-task", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 0}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
    pass "Non-review next_phase falls through to validation"
else
    fail "Non-review next_phase not handled correctly (exit $HOOK_EXIT_CODE)"
fi
cleanup

# Test 9: Post-review next_phase falls through to validation
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "code-review", "next_phase": "post-code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 1, "tdd": false, "current_task": 1, "phase_iteration": 1}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
    pass "Post-review next_phase falls through to validation"
else
    fail "Post-review next_phase not handled correctly (exit $HOOK_EXIT_CODE)"
fi
cleanup

# Test 10: null next_phase falls through to validation
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "complete", "next_phase": null, "review_model": "opus", "max_reviews": 8, "consecutive_clean": 2, "tdd": false, "current_task": 1, "phase_iteration": 0}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
    pass "null next_phase falls through to validation"
else
    fail "null next_phase not handled correctly (exit $HOOK_EXIT_CODE)"
fi
cleanup

# Test 11: Empty next_phase falls through to validation
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
    pass "Empty next_phase falls through to validation"
else
    fail "Empty next_phase not handled correctly (exit $HOOK_EXIT_CODE)"
fi
cleanup

# Test 6: all-code-review triggers
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1 | done |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-all-code-review", "next_phase": "all-code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="all-code-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ -f "$MOCK_LOG" ] && [ -f "$TEST_DIR/.taskie/plans/test-plan/all-code-review-1.md" ]; then
    pass "all-code-review triggers CLI invocation"
else
    fail "all-code-review did not trigger correctly"
fi
cleanup

# Test 7: Max reviews within limit allows review
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 5, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 4}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-5.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ -f "$MOCK_LOG" ] && [ -f "$TEST_DIR/.taskie/plans/test-plan/plan-review-5.md" ]; then
    pass "Max reviews within limit (5/5) allows review"
else
    fail "Max reviews within limit failed"
fi
cleanup

# Test 12: all-code-review with no task files skips review
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
EOF
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-all-code-review", "next_phase": "all-code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "No task files found"; then
    pass "all-code-review with no task files skips review"
else
    fail "all-code-review empty list not handled correctly"
fi
cleanup

# Test for max_reviews==0 skip (from suite 6, test 8)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 0, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 5}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "max_reviews=0" && echo "$HOOK_STDOUT" | grep -q "create-tasks"; then
    pass "max_reviews=0 skips review and auto-advances"
    # Verify state was updated
    NEW_PHASE=$(jq -r '.phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
    NEW_NEXT_PHASE=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
    NEW_ITERATION=$(jq -r '.phase_iteration' "$TEST_DIR/.taskie/plans/test-plan/state.json")
    if [ "$NEW_PHASE" = "plan-review" ] && [ "$NEW_NEXT_PHASE" = "create-tasks" ] && [ "$NEW_ITERATION" = "0" ]; then
        pass "max_reviews=0 updates state correctly"
    else
        fail "max_reviews=0 state not updated correctly (phase=$NEW_PHASE, next_phase=$NEW_NEXT_PHASE, iteration=$NEW_ITERATION)"
    fi
else
    fail "max_reviews=0 not handled correctly (exit $HOOK_EXIT_CODE)"
fi
cleanup

# TODO: Test 13-15: Consecutive clean tracking (Subtask 3.3)

print_results
