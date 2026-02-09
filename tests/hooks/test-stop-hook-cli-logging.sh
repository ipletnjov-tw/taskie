#!/usr/bin/env bash
# Test Suite 8: CLI Real-Time Logging
#
# Tests that Claude CLI output is streamed in real-time to log files
# while also being captured for verdict parsing.

set -uo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-utils.sh"

# Set hook script for test helpers
HOOK_SCRIPT="$SCRIPT_DIR/../../taskie/hooks/stop-hook.sh"

# Configure mock claude CLI
export PATH="$SCRIPT_DIR/helpers:$PATH"

echo "========================================"
echo "Test Suite 8: CLI Real-Time Logging"
echo "========================================"
echo ""
echo "Hook: $HOOK_SCRIPT"
echo ""

# Cleanup function
cleanup() {
    rm -rf "${TEST_DIR:-}" "${MOCK_LOG:-}" 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: CLI log file is created
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Check CLI log file exists
CLI_LOG=$(find "$TEST_DIR/.taskie/logs" -name "cli-*.log" 2>/dev/null | head -1)
if [ -n "$CLI_LOG" ] && [ -f "$CLI_LOG" ]; then
    pass "Test 1: CLI log file created"
else
    fail "Test 1: CLI log file NOT created"
fi
cleanup

# Test 2: CLI log file naming pattern
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
# Create task file for code-review
cat > "$TEST_DIR/.taskie/plans/test-plan/task-2.md" << 'TASK'
# Task 2: Test task
TASK
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-code-review", "next_phase": "code-review", "review_model": "sonnet", "max_reviews": 5, "consecutive_clean": 1, "tdd": false, "current_task": 2, "phase_iteration": 2}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="code-review-3.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Check naming pattern: cli-{timestamp}-{type}-{iteration}.log
CLI_LOG=$(find "$TEST_DIR/.taskie/logs" -name "cli-*-code-review-3.log" 2>/dev/null | head -1)
if [ -n "$CLI_LOG" ]; then
    pass "Test 2: CLI log filename matches pattern (cli-*-code-review-3.log)"
else
    fail "Test 2: CLI log filename pattern incorrect"
fi
cleanup

# Test 3: CLI log contains mock output
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
# Create task files for tasks-review
cat > "$TEST_DIR/.taskie/plans/test-plan/task-1.md" << 'TASK'
# Task 1
TASK
cat > "$TEST_DIR/.taskie/plans/test-plan/task-2.md" << 'TASK'
# Task 2
TASK
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-tasks-review", "next_phase": "tasks-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="tasks-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Check CLI log contains JSON output from mock
CLI_LOG=$(find "$TEST_DIR/.taskie/logs" -name "cli-*.log" 2>/dev/null | head -1)
if [ -n "$CLI_LOG" ] && grep -q '"verdict"' "$CLI_LOG" && grep -q '"session_id"' "$CLI_LOG"; then
    pass "Test 3: CLI log contains mock JSON output"
else
    fail "Test 3: CLI log missing expected content"
fi
cleanup

# Test 4: CLI log is preserved (not deleted on success)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Check CLI log still exists after successful review
CLI_LOG=$(find "$TEST_DIR/.taskie/logs" -name "cli-*.log" 2>/dev/null | head -1)
if [ -n "$CLI_LOG" ] && [ -f "$CLI_LOG" ]; then
    pass "Test 4: CLI log preserved after successful review"
else
    fail "Test 4: CLI log was deleted on success"
fi
cleanup

# Test 5: Hook log references CLI log file
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "sonnet", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Check hook log mentions CLI log file
HOOK_LOG=$(find "$TEST_DIR/.taskie/logs" -name "hook-*.log" 2>/dev/null | head -1)
if [ -n "$HOOK_LOG" ] && grep -q "CLI output streaming in real-time to:" "$HOOK_LOG"; then
    pass "Test 5: Hook log references CLI log file location"
else
    fail "Test 5: Hook log doesn't mention CLI log file"
fi
cleanup

# Test 6: Multiple CLI invocations create separate log files
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"

# First invocation
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Second invocation (different iteration)
sleep 1  # Ensure different timestamp
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "sonnet", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 1}'

export MOCK_CLAUDE_REVIEW_FILE="plan-review-2.md"
run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Check two CLI log files exist
CLI_LOG_COUNT=$(find "$TEST_DIR/.taskie/logs" -name "cli-*.log" 2>/dev/null | wc -l)
if [ "$CLI_LOG_COUNT" -eq 2 ]; then
    pass "Test 6: Multiple CLI invocations create separate log files"
else
    fail "Test 6: Found $CLI_LOG_COUNT CLI log files (expected 2)"
fi
cleanup

# Test 7: CLI log file path format validation
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
# Create task files for all-code-review
cat > "$TEST_DIR/.taskie/plans/test-plan/task-1.md" << 'TASK'
# Task 1
TASK
cat > "$TEST_DIR/.taskie/plans/test-plan/task-2.md" << 'TASK'
# Task 2
TASK
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-all-code-review", "next_phase": "all-code-review", "review_model": "opus", "max_reviews": 3, "consecutive_clean": 0, "tdd": true, "current_task": 1, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="all-task-1-code-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Validate format: cli-YYYY-MM-DDTHH-MM-SS-{type}-{iter}.log
CLI_LOG=$(find "$TEST_DIR/.taskie/logs" -name "cli-*.log" 2>/dev/null | head -1)
if [ -n "$CLI_LOG" ] && echo "$CLI_LOG" | grep -qE 'cli-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}-all-code-review-1\.log$'; then
    pass "Test 7: CLI log filename format is correct"
else
    fail "Test 7: CLI log filename format invalid: $(basename "$CLI_LOG")"
fi
cleanup

print_results
