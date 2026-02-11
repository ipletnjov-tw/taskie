#!/usr/bin/env bash
# Test Suite 4: Stop Hook CLI Invocation
#
# Tests claude CLI invocation flags, prompts, and failure handling.

set -uo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-utils.sh"

# Set hook script for test helpers
HOOK_SCRIPT="$SCRIPT_DIR/../../taskie/hooks/stop-hook.sh"

# Configure mock claude CLI
export PATH="$SCRIPT_DIR/helpers:$PATH"

echo "================================"
echo "Test Suite 4: CLI Invocation"
echo "================================"
echo ""
echo "Hook: $HOOK_SCRIPT"
echo ""

# Cleanup
cleanup() {
    rm -rf "${TEST_DIR:-}" "${MOCK_LOG:-}" 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: CLI invoked with correct flags for plan-review
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

if grep -q -- "--model opus" "$MOCK_LOG" && \
   grep -q -- "--output-format json" "$MOCK_LOG" && \
   grep -q -- "--dangerously-skip-permissions" "$MOCK_LOG" && \
   grep -q -- "--json-schema" "$MOCK_LOG"; then
    pass "CLI invoked with correct flags for plan-review"
else
    fail "CLI flags incorrect (check $MOCK_LOG)"
fi
cleanup

# Test 2: phase_iteration incremented before CLI invocation
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-tasks-review", "next_phase": "tasks-review", "review_model": "sonnet", "max_reviews": 5, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 2}'
# Add tasks.md
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1 | pending |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="tasks-review-3.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Check that review file has iteration 3 (was 2, should be incremented to 3)
if [ -f "$TEST_DIR/.taskie/plans/test-plan/tasks-review-3.md" ]; then
    pass "phase_iteration incremented correctly (2 -> 3)"
else
    fail "phase_iteration not incremented (expected tasks-review-3.md)"
fi
cleanup

# Test 3: Max reviews reached - hard stop
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "code-review", "next_phase": "code-review", "review_model": "opus", "max_reviews": 3, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 3}'
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "Max review limit (3) reached"; then
    pass "Max reviews reached triggers hard stop"
else
    fail "Max reviews not handled correctly"
fi
cleanup

# Test 4: Slash command invocation for tasks-review
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-tasks-review", "next_phase": "tasks-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 0}'
# Create tasks.md with known task IDs
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status | Description |
|----|--------|-------------|
| 1 | pending | Task 1 |
| 2 | done | Task 2 |
| 3 | pending | Task 3 |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
touch "$TEST_DIR/.taskie/plans/test-plan/task-2.md"
touch "$TEST_DIR/.taskie/plans/test-plan/task-3.md"

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="tasks-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

if grep -q "/taskie:tasks-review" "$MOCK_LOG"; then
    pass "Slash command used correctly (/taskie:tasks-review)"
else
    fail "Slash command not found (expected /taskie:tasks-review in prompt)"
fi
cleanup

# Test 5: Empty TASK_FILE_LIST skips review
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-tasks-review", "next_phase": "tasks-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'
# tasks.md exists with task rows but no actual task files
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1  | done   |
EOF
# Don't create task-1.md file, so TASK_FILE_LIST is empty

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "No task files found"; then
    pass "Empty TASK_FILE_LIST skips review with warning"
else
    fail "Empty TASK_FILE_LIST not handled correctly"
fi
cleanup

# Test 6: Missing task file for code-review skips review
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "implementation", "next_phase": "code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 5, "phase_iteration": 0}'
# task-5.md doesn't exist

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "Task file not found"; then
    pass "Missing task file for code-review skips with warning"
else
    fail "Missing task file not handled correctly"
fi
cleanup

# Test 7: CLI failure handled gracefully
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=1  # Simulate CLI failure

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "CLI failed"; then
    pass "CLI failure blocks with exit 2"
else
    fail "CLI failure not handled correctly (exit=$HOOK_EXIT_CODE)"
fi
cleanup

# Test 8: CLI invoked with correct model for code-review
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "complete-task", "next_phase": "code-review", "review_model": "sonnet", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="task-1-code-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

if [ -f "$MOCK_LOG" ] && grep -q "sonnet" "$MOCK_LOG"; then
    pass "CLI invoked with correct model (sonnet)"
else
    fail "CLI not invoked with correct model"
fi
cleanup

print_results
