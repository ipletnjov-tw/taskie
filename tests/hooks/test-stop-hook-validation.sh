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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
    pass "Valid plan structure correctly validated (exit 0 with success message)"
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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q '"decision": "block"' && echo "$HOOK_STDOUT" | grep -q "Missing required file: plan.md"; then
    pass "Invalid plan structure correctly blocked (missing plan.md + invalid filename)"
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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q '"decision": "block"' && echo "$HOOK_STDOUT" | grep -q "nested directories"; then
    pass "Nested directories correctly blocked"
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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q '"decision": "block"' && echo "$HOOK_STDOUT" | grep -q "design-review-1.md requires design.md"; then
    pass "Review without base file correctly blocked"
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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q '"decision": "block"' && echo "$HOOK_STDOUT" | grep -q "plan-post-review-1.md requires plan-review-1.md"; then
    pass "Post-review without review correctly blocked"
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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q '"decision": "block"' && echo "$HOOK_STDOUT" | grep -q "Task files exist but tasks.md is missing"; then
    pass "Task files without tasks.md correctly blocked"
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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q '"decision": "block"' && echo "$HOOK_STDOUT" | grep -q "non-table content"; then
    pass "Non-table tasks.md correctly blocked"
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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q '"decision": "block"' && echo "$HOOK_STDOUT" | grep -q "no table rows"; then
    pass "Empty tasks.md correctly blocked"
else
    fail "Empty tasks.md not handled correctly (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

# Test 14: state.json is not rejected by filename validation
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "implementation", "next_phase": null, "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDERR" | grep -q "invalid JSON" && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
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
if [ $HOOK_EXIT_CODE -eq 0 ] && echo "$HOOK_STDERR" | grep -q "missing required fields" && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
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
if [ $HOOK_EXIT_CODE -eq 0 ] && ! echo "$HOOK_STDERR" | grep -q "Warning" && echo "$HOOK_STDOUT" | grep -q "validated successfully"; then
    pass "Valid state.json produces no warnings"
else
    fail "Valid state.json incorrectly warned (exit $HOOK_EXIT_CODE)"
fi
rm -rf "$TEST_DIR"

print_results
