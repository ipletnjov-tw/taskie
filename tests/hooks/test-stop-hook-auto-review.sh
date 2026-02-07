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

# TODO: Test 1-3: Review triggers for plan/tasks/code review (Subtask 3.2)
# TODO: Test 6-7: all-code-review trigger, max reviews reached (Subtask 3.2)
# TODO: Test 12: all-code-review with no task files (Subtask 3.2)

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
