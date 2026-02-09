#!/usr/bin/env bash
# Shared test helpers for hook tests

# Test counters
PASS_COUNT=0
FAIL_COUNT=0

# Pass a test
pass() {
    local message="$1"
    echo "[PASS] $message"
    PASS_COUNT=$((PASS_COUNT + 1))
}

# Fail a test
fail() {
    local message="$1"
    echo "[FAIL] $message"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# Create a test plan directory with plan.md and tasks.md
create_test_plan() {
    local plan_dir="$1"
    mkdir -p "$plan_dir"

    # Create a minimal plan.md
    cat > "$plan_dir/plan.md" << 'EOF'
# Test Plan

## Overview

This is a test plan for testing purposes.
EOF

    # Create a minimal tasks.md with valid table format
    cat > "$plan_dir/tasks.md" << 'EOF'
| Id | Status | Priority | Description |
|----|--------|----------|-------------|
| 1 | pending | high | Test task 1 |
| 2 | pending | high | Test task 2 |
EOF
}

# Create state.json with provided JSON content
create_state_json() {
    local plan_dir="$1"
    local json_content="$2"

    # Ensure directory exists
    mkdir -p "$plan_dir"

    echo "$json_content" > "$plan_dir/state.json"
}

# Run the hook with JSON input and capture output
run_hook() {
    local json_input="$1"

    # Determine hook script location relative to project root
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(cd "$script_dir/../../.." && pwd)"
    local hook_script="${HOOK_SCRIPT:-$project_root/taskie/hooks/stop-hook.sh}"

    # Create temp files for capturing output
    local stdout_file=$(mktemp /tmp/taskie-test.XXXXXX)
    local stderr_file=$(mktemp /tmp/taskie-test.XXXXXX)
    local exit_code

    # Run the hook
    echo "$json_input" | bash "$hook_script" > "$stdout_file" 2> "$stderr_file"
    exit_code=$?

    # Store results in variables that caller can access
    HOOK_STDOUT=$(cat "$stdout_file")
    HOOK_STDERR=$(cat "$stderr_file")
    HOOK_EXIT_CODE=$exit_code

    # Clean up temp files
    rm -f "$stdout_file" "$stderr_file"

    return $exit_code
}

# Assert hook approved the stop
assert_approved() {
    if [ $HOOK_EXIT_CODE -ne 0 ]; then
        fail "Expected exit code 0, got $HOOK_EXIT_CODE"
        return 1
    fi

    # Check output - should be no output, suppressOutput, or systemMessage (no block decision)
    if [ -n "$HOOK_STDOUT" ]; then
        # If there's output, it should not contain a block decision
        if echo "$HOOK_STDOUT" | grep -q '"decision"[[:space:]]*:[[:space:]]*"block"'; then
            fail "Expected approval, but found block decision in output"
            return 1
        fi

        # If there's JSON output, validate structure
        if echo "$HOOK_STDOUT" | jq empty 2>/dev/null; then
            # Valid JSON - check for expected fields (suppressOutput or systemMessage)
            if ! echo "$HOOK_STDOUT" | jq -e 'has("suppressOutput") or has("systemMessage")' >/dev/null 2>&1; then
                fail "Expected JSON with suppressOutput or systemMessage, got: $HOOK_STDOUT"
                return 1
            fi
        fi
    fi

    return 0
}

# Assert hook blocked the stop
assert_blocked() {
    local pattern="${1:-}"

    # Hook blocks using exit code 2
    if [ $HOOK_EXIT_CODE -ne 2 ]; then
        fail "Expected exit code 2 (block), got $HOOK_EXIT_CODE"
        return 1
    fi

    # Check for error message in stderr
    if ! echo "$HOOK_STDERR" | grep -q "Stop hook error:"; then
        fail "Expected 'Stop hook error:' in stderr, but not found"
        return 1
    fi

    # If pattern provided, check the stderr matches
    if [ -n "$pattern" ]; then
        if ! echo "$HOOK_STDERR" | grep -q "$pattern"; then
            fail "Expected stderr matching '$pattern', but not found: $HOOK_STDERR"
            return 1
        fi
    fi

    return 0
}

# Print test results and exit
print_results() {
    echo ""
    echo "=========================================="
    echo "Test Results:"
    echo "  Passed: $PASS_COUNT"
    echo "  Failed: $FAIL_COUNT"
    echo "=========================================="

    if [ $FAIL_COUNT -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}
