#!/usr/bin/env bash
# Test Suite 7: Logging
# Tests that the stop hook writes per-invocation log files under .taskie/logs/
#
# 9 tests total

set -euo pipefail

# Load test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-utils.sh"

echo ""
echo "=========================================="
echo "Test Suite 7: Logging (9 tests)"
echo "=========================================="

# ---- Test 1: Log directory created ----
echo ""
echo "--- Test 1: Log directory created ---"
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
echo "# Test Plan" > "$TEST_DIR/.taskie/plans/test-plan/plan.md"

run_hook "{\"cwd\": \"$TEST_DIR\"}" || true

if [ -d "$TEST_DIR/.taskie/logs" ]; then
    pass "Test 1: .taskie/logs/ directory created"
else
    fail "Test 1: .taskie/logs/ directory NOT created"
fi
rm -rf "$TEST_DIR"

# ---- Test 2: Log file created per invocation ----
echo ""
echo "--- Test 2: Log file created per invocation ---"
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
echo "# Test Plan" > "$TEST_DIR/.taskie/plans/test-plan/plan.md"

run_hook "{\"cwd\": \"$TEST_DIR\"}" || true

LOG_COUNT=$(find "$TEST_DIR/.taskie/logs" -name "hook-*.log" 2>/dev/null | wc -l)
if [ "$LOG_COUNT" -eq 1 ]; then
    pass "Test 2: Exactly 1 hook-*.log file created"
else
    fail "Test 2: Expected 1 log file, found $LOG_COUNT"
fi
rm -rf "$TEST_DIR"

# ---- Test 3: Log file contains invocation header ----
echo ""
echo "--- Test 3: Log file contains invocation header ---"
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
echo "# Test Plan" > "$TEST_DIR/.taskie/plans/test-plan/plan.md"

run_hook "{\"cwd\": \"$TEST_DIR\"}" || true

LOG_FILE=$(find "$TEST_DIR/.taskie/logs" -name "hook-*.log" 2>/dev/null | head -1)
if [ -n "$LOG_FILE" ] && grep -q "=== Hook invocation ===" "$LOG_FILE"; then
    pass "Test 3: Log contains '=== Hook invocation ==='"
else
    fail "Test 3: Log missing invocation header"
fi
rm -rf "$TEST_DIR"

# ---- Test 4: Log contains state fields ----
echo ""
echo "--- Test 4: Log contains state fields ---"
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
echo "# Test Plan" > "$TEST_DIR/.taskie/plans/test-plan/plan.md"
cat > "$TEST_DIR/.taskie/plans/test-plan/state.json" << 'EOF'
{
    "phase": "implementation",
    "next_phase": "code-review",
    "max_reviews": 3,
    "current_task": 1,
    "phase_iteration": null,
    "review_model": "opus",
    "consecutive_clean": 0,
    "tdd": false
}
EOF
# Add tasks.md and task file so code-review path has what it needs
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status | Priority | Description |
|----|--------|----------|-------------|
| 1 | in-progress | high | Test task 1 |
EOF
echo "# Task 1" > "$TEST_DIR/.taskie/plans/test-plan/task-1.md"

# Mock claude CLI to prevent actual invocation
export PATH="$SCRIPT_DIR/helpers:$PATH"
export MOCK_CLAUDE_EXIT_CODE=1
MOCK_CLAUDE_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
export MOCK_CLAUDE_LOG

run_hook "{\"cwd\": \"$TEST_DIR\"}" || true

LOG_FILE=$(find "$TEST_DIR/.taskie/logs" -name "hook-*.log" 2>/dev/null | head -1)
FIELD_MATCH=0
if [ -n "$LOG_FILE" ]; then
    for field in phase next_phase max_reviews current_task phase_iteration review_model consecutive_clean tdd; do
        if grep -q "$field=" "$LOG_FILE"; then
            FIELD_MATCH=$((FIELD_MATCH + 1))
        fi
    done
fi

if [ "$FIELD_MATCH" -eq 8 ]; then
    pass "Test 4: Log contains all 8 state field names"
else
    fail "Test 4: Log contains only $FIELD_MATCH/8 state fields"
fi
rm -rf "$TEST_DIR"
rm -f "$MOCK_CLAUDE_LOG"
unset MOCK_CLAUDE_EXIT_CODE MOCK_CLAUDE_LOG

# ---- Test 5: Log contains review decision ----
echo ""
echo "--- Test 5: Log contains review decision ---"
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
echo "# Test Plan" > "$TEST_DIR/.taskie/plans/test-plan/plan.md"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status | Priority | Description |
|----|--------|----------|-------------|
| 1 | in-progress | high | Test task 1 |
EOF
echo "# Task 1" > "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
cat > "$TEST_DIR/.taskie/plans/test-plan/state.json" << 'EOF'
{
    "phase": "implementation",
    "next_phase": "code-review",
    "max_reviews": 3,
    "current_task": 1,
    "phase_iteration": null,
    "review_model": "opus",
    "consecutive_clean": 0,
    "tdd": false
}
EOF

# Mock claude CLI that succeeds and creates the review file
export PATH="$SCRIPT_DIR/helpers:$PATH"
export MOCK_CLAUDE_EXIT_CODE=0
export MOCK_CLAUDE_VERDICT="FAIL"
MOCK_CLAUDE_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
export MOCK_CLAUDE_LOG
# The mock needs to create the review file - extract plan dir
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="code-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\"}" || true

LOG_FILE=$(find "$TEST_DIR/.taskie/logs" -name "hook-*.log" 2>/dev/null | head -1)
if [ -n "$LOG_FILE" ] && grep -q "DECISION:" "$LOG_FILE"; then
    pass "Test 5: Log contains DECISION: line"
else
    fail "Test 5: Log missing DECISION: line"
    if [ -n "$LOG_FILE" ]; then
        echo "  Log contents:"
        cat "$LOG_FILE" | head -30
    fi
fi
rm -rf "$TEST_DIR"
rm -f "$MOCK_CLAUDE_LOG"
unset MOCK_CLAUDE_EXIT_CODE MOCK_CLAUDE_VERDICT MOCK_CLAUDE_LOG MOCK_CLAUDE_REVIEW_DIR MOCK_CLAUDE_REVIEW_FILE

# ---- Test 6: Log contains CLI invocation ----
echo ""
echo "--- Test 6: Log contains CLI invocation ---"
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
echo "# Test Plan" > "$TEST_DIR/.taskie/plans/test-plan/plan.md"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status | Priority | Description |
|----|--------|----------|-------------|
| 1 | in-progress | high | Test task 1 |
EOF
echo "# Task 1" > "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
cat > "$TEST_DIR/.taskie/plans/test-plan/state.json" << 'EOF'
{
    "phase": "implementation",
    "next_phase": "code-review",
    "max_reviews": 3,
    "current_task": 1,
    "phase_iteration": null,
    "review_model": "opus",
    "consecutive_clean": 0,
    "tdd": false
}
EOF

export PATH="$SCRIPT_DIR/helpers:$PATH"
export MOCK_CLAUDE_EXIT_CODE=1
MOCK_CLAUDE_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
export MOCK_CLAUDE_LOG

run_hook "{\"cwd\": \"$TEST_DIR\"}" || true

LOG_FILE=$(find "$TEST_DIR/.taskie/logs" -name "hook-*.log" 2>/dev/null | head -1)
if [ -n "$LOG_FILE" ] && grep -q "Invoking:.*claude" "$LOG_FILE"; then
    pass "Test 6: Log contains CLI invocation"
else
    fail "Test 6: Log missing CLI invocation line"
    if [ -n "$LOG_FILE" ]; then
        echo "  Log contents:"
        cat "$LOG_FILE" | head -30
    fi
fi
rm -rf "$TEST_DIR"
rm -f "$MOCK_CLAUDE_LOG"
unset MOCK_CLAUDE_EXIT_CODE MOCK_CLAUDE_LOG

# ---- Test 7: Log contains validation result ----
echo ""
echo "--- Test 7: Log contains validation result ---"
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
echo "# Test Plan" > "$TEST_DIR/.taskie/plans/test-plan/plan.md"
# No state.json -> falls through to validation

run_hook "{\"cwd\": \"$TEST_DIR\"}" || true

LOG_FILE=$(find "$TEST_DIR/.taskie/logs" -name "hook-*.log" 2>/dev/null | head -1)
if [ -n "$LOG_FILE" ] && grep -q "Validation" "$LOG_FILE"; then
    pass "Test 7: Log contains 'Validation' line"
else
    fail "Test 7: Log missing validation result"
    if [ -n "$LOG_FILE" ]; then
        echo "  Log contents:"
        cat "$LOG_FILE" | head -30
    fi
fi
rm -rf "$TEST_DIR"

# ---- Test 8: No log for non-Taskie projects ----
echo ""
echo "--- Test 8: No log for non-Taskie projects ---"
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
# No .taskie directory at all

run_hook "{\"cwd\": \"$TEST_DIR\"}" || true

if [ ! -d "$TEST_DIR/.taskie/logs" ]; then
    pass "Test 8: No .taskie/logs/ created for non-Taskie project"
else
    fail "Test 8: .taskie/logs/ was created for non-Taskie project"
fi
rm -rf "$TEST_DIR"

# ---- Test 9: Multiple invocations create separate files ----
echo ""
echo "--- Test 9: Multiple invocations create separate files ---"
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
echo "# Test Plan" > "$TEST_DIR/.taskie/plans/test-plan/plan.md"

# Run hook twice with a 1-second gap so timestamps differ
run_hook "{\"cwd\": \"$TEST_DIR\"}" || true
sleep 1
run_hook "{\"cwd\": \"$TEST_DIR\"}" || true

LOG_COUNT=$(find "$TEST_DIR/.taskie/logs" -name "hook-*.log" 2>/dev/null | wc -l)
if [ "$LOG_COUNT" -ge 2 ]; then
    pass "Test 9: Multiple invocations created $LOG_COUNT separate log files"
else
    fail "Test 9: Expected >= 2 log files, found $LOG_COUNT"
fi
rm -rf "$TEST_DIR"

# Print results
print_results
