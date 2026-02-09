#!/usr/bin/env bash
# Test Suite 1: Stop Hook Validation Rules
#
# Tests validation rules 1-8 for the unified stop hook.
# Rules 1-7: Plan structure validation (ported from validate-ground-rules.sh)
# Rule 8: state.json validation (new in unified hook)

set -uo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-utils.sh"

# Set hook script for test helpers
HOOK_SCRIPT="$SCRIPT_DIR/../../taskie/hooks/stop-hook.sh"

# Configure mock claude CLI (needed for Test 18)
export PATH="$SCRIPT_DIR/helpers:$PATH"

# Verify hook script exists
if [[ ! -f "$HOOK_SCRIPT" ]]; then
    echo "Error: Hook script not found at $HOOK_SCRIPT"
    exit 1
fi

echo "================================"
echo "Test Suite 1: Stop Hook Validation"
echo "================================"
echo ""
echo "Hook: $HOOK_SCRIPT"
echo ""

# Test 1: Check if jq is installed
if command -v jq &> /dev/null; then
    pass "jq dependency installed"
else
    fail "jq is NOT installed"
fi

# Test 2: Invalid JSON input
run_hook "invalid json" || true || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Invalid JSON input"; then
    pass "Invalid JSON correctly caught (exit 2)"
else
    fail "Invalid JSON not handled correctly (exit $HOOK_EXIT_CODE)"
fi

# Test 3: Valid JSON but invalid directory
run_hook '{"cwd": "/nonexistent/directory", "stop_hook_active": false}' || true || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Cannot change to project directory"; then
    pass "Invalid directory correctly caught (exit 2)"
else
    fail "Invalid directory not handled correctly (exit $HOOK_EXIT_CODE)"
fi

# Test 4: Stop hook active (infinite loop prevention)
run_hook '{"cwd": ".", "stop_hook_active": true}' || true || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "suppressOutput"; then
    pass "Stop hook active correctly handled (exit 0 with suppressOutput)"
else
    fail "Stop hook active not handled correctly (exit $HOOK_EXIT_CODE)"
fi

# Test 5: No .taskie directory
run_hook "{\"cwd\": \"$PWD\", \"stop_hook_active\": false}" || true || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "suppressOutput"; then
    pass "No .taskie directory correctly handled (exit 0 with suppressOutput)"
else
    fail "No .taskie directory not handled correctly (exit $HOOK_EXIT_CODE)"
fi

# Test 6: Valid plan structure
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | jq -e '.suppressOutput == true' >/dev/null 2>&1; then
    pass "Valid plan structure correctly validated (exit 0 with suppressOutput)"
else
    fail "Valid plan structure not handled correctly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 7: Invalid plan structure (missing plan.md)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/invalid-file.md" << 'EOF'
This file has an invalid name.
EOF

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Missing required file: plan.md"; then
    pass "Invalid plan structure correctly blocked (exit 2 with error)"
else
    fail "Invalid plan structure not handled correctly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 8: Nested directories
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan/nested"
cat > "$TEST_DIR/.taskie/plans/test-plan/plan.md" << 'EOF'
# Test Plan
EOF
cat > "$TEST_DIR/.taskie/plans/test-plan/nested/extra.md" << 'EOF'
# Should not be here
EOF

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "nested directories"; then
    pass "Nested directories correctly blocked (exit 2)"
else
    fail "Nested directories not handled correctly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 9: Review file without base file
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/plan.md" << 'EOF'
# Test Plan
EOF
cat > "$TEST_DIR/.taskie/plans/test-plan/design-review-1.md" << 'EOF'
# Review of design that does not exist
EOF

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "design-review-1.md requires design.md"; then
    pass "Review without base file correctly blocked (exit 2)"
else
    fail "Review without base file not handled correctly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 10: Post-review file without review file
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/plan.md" << 'EOF'
# Test Plan
EOF
cat > "$TEST_DIR/.taskie/plans/test-plan/plan-post-review-1.md" << 'EOF'
# Post-review without matching review
EOF

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "plan-post-review-1.md requires plan-review-1.md"; then
    pass "Post-review without review correctly blocked (exit 2)"
else
    fail "Post-review without review not handled correctly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 11: Task files without tasks.md
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/plan.md" << 'EOF'
# Test Plan
EOF
cat > "$TEST_DIR/.taskie/plans/test-plan/task-1.md" << 'EOF'
# Task 1
Do something.
EOF

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Task files exist but tasks.md is missing"; then
    pass "Task files without tasks.md correctly blocked (exit 2)"
else
    fail "Task files without tasks.md not handled correctly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 12: tasks.md with non-table content
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/plan.md" << 'EOF'
# Test Plan
EOF
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
# Tasks
This is not a table, it's prose.
EOF

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "non-table content"; then
    pass "Non-table tasks.md correctly blocked (exit 2)"
else
    fail "Non-table tasks.md not handled correctly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 13: Empty tasks.md (no table rows)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/plan.md" << 'EOF'
# Test Plan
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/tasks.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "no table rows"; then
    pass "Empty tasks.md correctly blocked (exit 2)"
else
    fail "Empty tasks.md not handled correctly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 14: state.json is not rejected by filename validation
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "implementation", "next_phase": null, "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | jq -e '.suppressOutput == true' >/dev/null 2>&1; then
    pass "state.json not rejected by filename validation"
else
    fail "state.json incorrectly blocked (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 15: Invalid JSON in state.json logs warning but doesn't block
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "{ invalid json }" > "$TEST_DIR/.taskie/plans/test-plan/state.json"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDERR" | grep -q "invalid JSON" && echo "$HOOK_STDOUT" | jq -e '.suppressOutput == true' >/dev/null 2>&1; then
    pass "Invalid JSON in state.json logs warning but doesn't block"
else
    fail "Invalid JSON in state.json handled incorrectly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 16: Missing required fields in state.json logs warning but doesn't block
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"max_reviews": 8}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDERR" | grep -q "missing required fields" && echo "$HOOK_STDOUT" | jq -e '.suppressOutput == true' >/dev/null 2>&1; then
    pass "Missing required fields in state.json logs warning but doesn't block"
else
    fail "Missing fields in state.json handled incorrectly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 17: Valid state.json produces no warnings
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "implementation", "next_phase": null, "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": null}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && ! echo "$HOOK_STDERR" | grep -q "Warning" && echo "$HOOK_STDOUT" | jq -e '.suppressOutput == true' >/dev/null 2>&1; then
    pass "Valid state.json produces no warnings"
else
    fail "Valid state.json incorrectly warned (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 18: TASKIE_HOOK_SKIP env var check and CLI invocation
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

# Run hook - verify it sets TASKIE_HOOK_SKIP=true before CLI invocation
run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Check that hook log shows TASKIE_HOOK_SKIP=true in the CLI invocation
HOOK_LOG=$(find "$TEST_DIR/.taskie/logs" -name "hook-*.log" | head -1)
if grep -q "TASKIE_HOOK_SKIP=true.*claude" "$HOOK_LOG"; then
    pass "TASKIE_HOOK_SKIP set before CLI invocation (recursion protection enabled)"
else
    fail "TASKIE_HOOK_SKIP not set in CLI invocation"
fi
rm -rf "$TEST_DIR"
rm -f "$MOCK_LOG"
unset MOCK_CLAUDE_LOG MOCK_CLAUDE_VERDICT MOCK_CLAUDE_REVIEW_DIR MOCK_CLAUDE_REVIEW_FILE MOCK_CLAUDE_EXIT_CODE

# Test 19: Invalid filename pattern (Rule 2)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
# Create file with invalid pattern
echo "# Invalid" > "$TEST_DIR/.taskie/plans/test-plan/code-review-1-response.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Invalid filename"; then
    pass "Invalid filename pattern correctly blocked (exit 2)"
else
    fail "Invalid filename pattern not caught (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 20: Review file missing post-review (Rule 5b)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
# Create multiple review files but missing post-review for iteration 1
echo "# Plan Review 1" > "$TEST_DIR/.taskie/plans/test-plan/plan-review-1.md"
echo "# Plan Review 2" > "$TEST_DIR/.taskie/plans/test-plan/plan-review-2.md"
echo "# Post Review 2" > "$TEST_DIR/.taskie/plans/test-plan/plan-post-review-2.md"
# Missing plan-post-review-1.md

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "plan-review-1.md requires plan-post-review-1.md"; then
    pass "Review missing post-review correctly blocked (exit 2)"
else
    fail "Review missing post-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 21: task-X-code-review without task file (Rule 7)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1  | done   |
EOF
# Create code review for task-2 but no task-2.md file
echo "# Code Review" > "$TEST_DIR/.taskie/plans/test-plan/task-2-code-review-1.md"
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "task-2-code-review-1.md requires task-2.md"; then
    pass "Code review without task file correctly blocked (exit 2)"
else
    fail "Code review without task file not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 22: Invalid non-.md files (Rule 9)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
# Create garbage files
touch "$TEST_DIR/.taskie/plans/test-plan/.review-1.log"
echo "garbage" > "$TEST_DIR/.taskie/plans/test-plan/random.txt"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Invalid file in plan directory"; then
    pass "Invalid non-.md files correctly blocked (exit 2)"
else
    fail "Invalid non-.md files not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 23: Old code-review pattern should be invalid (Rule 2)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Old pattern" > "$TEST_DIR/.taskie/plans/test-plan/code-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Invalid filename.*code-review-1.md"; then
    pass "Old code-review-N.md pattern correctly blocked (exit 2)"
else
    fail "Old code-review pattern not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 24: Old code-post-review pattern should be invalid (Rule 2)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Old pattern" > "$TEST_DIR/.taskie/plans/test-plan/code-post-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Invalid filename.*code-post-review-1.md"; then
    pass "Old code-post-review-N.md pattern correctly blocked (exit 2)"
else
    fail "Old code-post-review pattern not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 25: Completely random .md filename (Rule 2)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Random" > "$TEST_DIR/.taskie/plans/test-plan/random-garbage-file.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Invalid filename.*random-garbage-file.md"; then
    pass "Random .md filename correctly blocked (exit 2)"
else
    fail "Random .md filename not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 26: design-review without design.md (Rule 4)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Design Review" > "$TEST_DIR/.taskie/plans/test-plan/design-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "design-review-1.md requires design.md"; then
    pass "design-review without design.md correctly blocked (exit 2)"
else
    fail "design-review without design.md not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 27: tasks-review without tasks.md (Rule 4)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Tasks Review" > "$TEST_DIR/.taskie/plans/test-plan/tasks-review-1.md"
rm -f "$TEST_DIR/.taskie/plans/test-plan/tasks.md"  # Remove tasks.md from create_test_plan

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "tasks-review-1.md requires tasks.md"; then
    pass "tasks-review without tasks.md correctly blocked (exit 2)"
else
    fail "tasks-review without tasks.md not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 28: tasks-post-review without tasks-review (Rule 5)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Post Review" > "$TEST_DIR/.taskie/plans/test-plan/tasks-post-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "tasks-post-review-1.md requires tasks-review-1.md"; then
    pass "tasks-post-review without tasks-review correctly blocked (exit 2)"
else
    fail "tasks-post-review without tasks-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 29: task-X-post-review without task-X-review (Rule 5)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
echo "# Post Review" > "$TEST_DIR/.taskie/plans/test-plan/task-1-post-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "task-1-post-review-1.md requires task-1-review-1.md"; then
    pass "task-X-post-review without task-X-review correctly blocked (exit 2)"
else
    fail "task-X-post-review without task-X-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 30: task-X-code-post-review without task-X-code-review (Rule 5)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
echo "# Code Post Review" > "$TEST_DIR/.taskie/plans/test-plan/task-1-code-post-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "task-1-code-post-review-1.md requires task-1-code-review-1.md"; then
    pass "task-X-code-post-review without task-X-code-review correctly blocked (exit 2)"
else
    fail "task-X-code-post-review without task-X-code-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 31: tasks-review missing post-review (Rule 5b)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Tasks Review 1" > "$TEST_DIR/.taskie/plans/test-plan/tasks-review-1.md"
echo "# Tasks Review 2" > "$TEST_DIR/.taskie/plans/test-plan/tasks-review-2.md"
echo "# Post Review 2" > "$TEST_DIR/.taskie/plans/test-plan/tasks-post-review-2.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "tasks-review-1.md requires tasks-post-review-1.md"; then
    pass "tasks-review missing post-review correctly blocked (exit 2)"
else
    fail "tasks-review missing post-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 32: task-X-review missing post-review (Rule 5b)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
echo "# Task Review 1" > "$TEST_DIR/.taskie/plans/test-plan/task-1-review-1.md"
echo "# Task Review 2" > "$TEST_DIR/.taskie/plans/test-plan/task-1-review-2.md"
echo "# Post Review 2" > "$TEST_DIR/.taskie/plans/test-plan/task-1-post-review-2.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "task-1-review-1.md requires task-1-post-review-1.md"; then
    pass "task-X-review missing post-review correctly blocked (exit 2)"
else
    fail "task-X-review missing post-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 33: task-X-code-review missing post-review (Rule 5b)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
echo "# Code Review 1" > "$TEST_DIR/.taskie/plans/test-plan/task-1-code-review-1.md"
echo "# Code Review 2" > "$TEST_DIR/.taskie/plans/test-plan/task-1-code-review-2.md"
echo "# Code Post Review 2" > "$TEST_DIR/.taskie/plans/test-plan/task-1-code-post-review-2.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "task-1-code-review-1.md requires task-1-code-post-review-1.md"; then
    pass "task-X-code-review missing post-review correctly blocked (exit 2)"
else
    fail "task-X-code-review missing post-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 34: all-code-review missing post-review (Rule 5b)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1  | done   |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
echo "# All Code Review 1" > "$TEST_DIR/.taskie/plans/test-plan/all-code-review-1.md"
echo "# All Code Review 2" > "$TEST_DIR/.taskie/plans/test-plan/all-code-review-2.md"
echo "# Post Review 2" > "$TEST_DIR/.taskie/plans/test-plan/all-code-post-review-2.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "all-code-review-1.md requires all-code-post-review-1.md"; then
    pass "all-code-review missing post-review correctly blocked (exit 2)"
else
    fail "all-code-review missing post-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 35: Various non-.md file extensions (Rule 9)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/script.sh"
echo "code" > "$TEST_DIR/.taskie/plans/test-plan/file.js"
echo "data" > "$TEST_DIR/.taskie/plans/test-plan/config.json"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "Invalid file in plan directory"; then
    pass "Various non-.md extensions correctly blocked (exit 2)"
else
    fail "Various non-.md extensions not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 36: design-review missing post-review (Rule 5b)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Design" > "$TEST_DIR/.taskie/plans/test-plan/design.md"
echo "# Design Review 1" > "$TEST_DIR/.taskie/plans/test-plan/design-review-1.md"
echo "# Design Review 2" > "$TEST_DIR/.taskie/plans/test-plan/design-review-2.md"
echo "# Post Review 2" > "$TEST_DIR/.taskie/plans/test-plan/design-post-review-2.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "design-review-1.md requires design-post-review-1.md"; then
    pass "design-review missing post-review correctly blocked (exit 2)"
else
    fail "design-review missing post-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 37: Most recent iteration does NOT require post-review (negative test)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Plan Review 1" > "$TEST_DIR/.taskie/plans/test-plan/plan-review-1.md"
echo "# Post Review 1" > "$TEST_DIR/.taskie/plans/test-plan/plan-post-review-1.md"
echo "# Plan Review 2" > "$TEST_DIR/.taskie/plans/test-plan/plan-review-2.md"
# plan-review-2.md is most recent, should NOT require post-review

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ]; then
    pass "Most recent review iteration does not require post-review (exit 0)"
else
    fail "Most recent iteration incorrectly required post-review (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 38: Multiple missing post-reviews (3+ iterations)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
echo "# Plan Review 1" > "$TEST_DIR/.taskie/plans/test-plan/plan-review-1.md"
echo "# Plan Review 2" > "$TEST_DIR/.taskie/plans/test-plan/plan-review-2.md"
echo "# Plan Review 3" > "$TEST_DIR/.taskie/plans/test-plan/plan-review-3.md"
echo "# Post Review 3" > "$TEST_DIR/.taskie/plans/test-plan/plan-post-review-3.md"
# Missing plan-post-review-1.md and plan-post-review-2.md

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "plan-review-1.md requires plan-post-review-1.md" && echo "$HOOK_STDERR" | grep -q "plan-review-2.md requires plan-post-review-2.md"; then
    pass "Multiple missing post-reviews correctly blocked (exit 2)"
else
    fail "Multiple missing post-reviews not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 39: Different task IDs - task-2-code-review
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-2.md"
echo "# Code Review 1" > "$TEST_DIR/.taskie/plans/test-plan/task-2-code-review-1.md"
echo "# Code Review 2" > "$TEST_DIR/.taskie/plans/test-plan/task-2-code-review-2.md"
echo "# Post Review 2" > "$TEST_DIR/.taskie/plans/test-plan/task-2-code-post-review-2.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "task-2-code-review-1.md requires task-2-code-post-review-1.md"; then
    pass "task-2-code-review missing post-review correctly blocked (exit 2)"
else
    fail "task-2-code-review missing post-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

# Test 40: task-3-review missing post-review
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-3.md"
echo "# Task Review 1" > "$TEST_DIR/.taskie/plans/test-plan/task-3-review-1.md"
echo "# Task Review 2" > "$TEST_DIR/.taskie/plans/test-plan/task-3-review-2.md"
echo "# Post Review 2" > "$TEST_DIR/.taskie/plans/test-plan/task-3-post-review-2.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 2 ] && echo "$HOOK_STDERR" | grep -q "task-3-review-1.md requires task-3-post-review-1.md"; then
    pass "task-3-review missing post-review correctly blocked (exit 2)"
else
    fail "task-3-review missing post-review not caught (exit $HOOK_EXIT_CODE, stderr: $HOOK_STDERR)"
fi
rm -rf "$TEST_DIR"

print_results
