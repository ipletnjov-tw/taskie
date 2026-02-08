#!/usr/bin/env bash
# Test Suite 6: Edge Cases & Integration Tests
#
# Tests edge cases and integration scenarios for the unified stop hook.
# Covers multiple plan directories, unknown fields, model alternation, etc.

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
echo "Test Suite 6: Edge Cases & Integration"
echo "================================"
echo ""
echo "Hook: $HOOK_SCRIPT"
echo ""

# Cleanup function
cleanup() {
    rm -rf "${TEST_DIR:-}" "${MOCK_LOG:-}" 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: Multiple plan directories - hook validates/reviews only the most recent plan
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/old-plan"
create_state_json "$TEST_DIR/.taskie/plans/old-plan" '{"phase": "next-task", "next_phase": null, "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": null}'
sleep 1  # Ensure different mtime
create_test_plan "$TEST_DIR/.taskie/plans/recent-plan"
create_state_json "$TEST_DIR/.taskie/plans/recent-plan" '{"phase": "next-task", "next_phase": null, "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": null}'
touch "$TEST_DIR/.taskie/plans/recent-plan/state.json"  # Make it most recent

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if assert_approved; then
    pass "Multiple plan directories - validates most recent plan only"
else
    fail "Multiple plan directories - validation failed"
fi
cleanup

# Test 2: state.json with extra unknown fields - hook works normally, ignores them
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "next-task", "next_phase": null, "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": null, "custom_field": 42, "extra": "ignored"}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if assert_approved; then
    pass "Unknown fields in state.json ignored correctly"
else
    fail "Unknown fields caused validation failure"
fi
cleanup

# Test 3: Phase iteration is null (non-review phase, standalone) - should approve
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "next-task", "next_phase": null, "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": null}'

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if assert_approved; then
    pass "Standalone mode (phase_iteration: null) approved"
else
    fail "Standalone mode incorrectly blocked"
fi
cleanup

# Test 4: review_model is unexpected value - hook passes it to CLI (CLI handles validation)
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "haiku", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if [ -f "$MOCK_LOG" ] && grep -q -- "--model haiku" "$MOCK_LOG"; then
    pass "Unexpected review_model value passed to CLI correctly"
else
    fail "Unexpected review_model not passed to CLI"
fi
cleanup

# Test 5: Concurrent plan creation - state.json exists but plan.md doesn't (validation blocks)
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "new-plan", "next_phase": null, "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": null}'
# Note: plan.md does NOT exist

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if assert_blocked "plan.md"; then
    pass "Concurrent plan creation - validation blocks for missing plan.md"
else
    fail "Concurrent plan creation - should have blocked for missing plan.md"
fi
cleanup

# Test 6: Auto-review takes precedence over validation - validation NOT reached
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
# Add a nested directory that would trigger validation error (if validation was reached)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan/nested-dir"
touch "$TEST_DIR/.taskie/plans/test-plan/nested-dir/file.txt"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-code-review", "next_phase": "code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 0}'
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="code-review-1.md"  # phase_iteration 0 → first review is iteration 1
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
# Auto-review should run and block for post-review; validation is NOT reached
if [ -f "$MOCK_LOG" ] && assert_blocked "post-code-review"; then
    pass "Auto-review takes precedence - validation not reached"
else
    fail "Auto-review precedence test failed"
fi
cleanup

# Test 7: Empty plan directory - no plan subdirectories, should approve
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/.taskie/plans"
# No plan subdirectories exist

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if assert_approved; then
    pass "Empty plan directory approved (no plans to validate)"
else
    fail "Empty plan directory incorrectly failed"
fi
cleanup

# Test 8: max_reviews=0 - auto-advance state without CLI invocation
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-code-review", "next_phase": "code-review", "review_model": "opus", "max_reviews": 0, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 0}'
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"

export MOCK_CLAUDE_LOG="$MOCK_LOG"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
# Should approve without calling CLI, and advance next_phase
STATE_CONTENT=$(cat "$TEST_DIR/.taskie/plans/test-plan/state.json")
NEXT_PHASE=$(echo "$STATE_CONTENT" | jq -r '.next_phase')
PHASE_ITER=$(echo "$STATE_CONTENT" | jq -r '.phase_iteration')

if assert_approved && [ ! -s "$MOCK_LOG" ] && [ "$NEXT_PHASE" = "complete-task" ] && [ "$PHASE_ITER" = "0" ]; then
    pass "max_reviews=0 auto-advances without CLI invocation"
else
    fail "max_reviews=0 did not auto-advance correctly (next_phase: $NEXT_PHASE, phase_iteration: $PHASE_ITER, log_empty: $([[ ! -s "$MOCK_LOG" ]] && echo yes || echo no))"
fi
cleanup

# Test 9: Backwards compatibility - no state.json, valid plan (validation only, no auto-review)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
# Note: state.json does NOT exist

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true
if assert_approved; then
    pass "Backwards compatibility - valid plan without state.json approved"
else
    fail "Backwards compatibility failed"
fi
cleanup

# Test 10: Full model alternation across 4 iterations (integration)
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_EXIT_CODE=0

# Iteration 1: opus
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Simulate post-review fixing issues
rm -f "$TEST_DIR/.taskie/plans/test-plan/plan-review-1.md"
jq '.phase = "post-plan-review" | .next_phase = "plan-review" | .phase_iteration = 1 | .review_model = "sonnet" | .consecutive_clean = 0' \
    "$TEST_DIR/.taskie/plans/test-plan/state.json" > "$TEST_DIR/.taskie/plans/test-plan/state.json.tmp"
mv "$TEST_DIR/.taskie/plans/test-plan/state.json.tmp" "$TEST_DIR/.taskie/plans/test-plan/state.json"

# Iteration 2: sonnet
export MOCK_CLAUDE_REVIEW_FILE="plan-review-2.md"
run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Simulate post-review fixing issues
rm -f "$TEST_DIR/.taskie/plans/test-plan/plan-review-2.md"
jq '.phase = "post-plan-review" | .next_phase = "plan-review" | .phase_iteration = 2 | .review_model = "opus" | .consecutive_clean = 0' \
    "$TEST_DIR/.taskie/plans/test-plan/state.json" > "$TEST_DIR/.taskie/plans/test-plan/state.json.tmp"
mv "$TEST_DIR/.taskie/plans/test-plan/state.json.tmp" "$TEST_DIR/.taskie/plans/test-plan/state.json"

# Iteration 3: opus
export MOCK_CLAUDE_REVIEW_FILE="plan-review-3.md"
run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Simulate post-review fixing issues
rm -f "$TEST_DIR/.taskie/plans/test-plan/plan-review-3.md"
jq '.phase = "post-plan-review" | .next_phase = "plan-review" | .phase_iteration = 3 | .review_model = "sonnet" | .consecutive_clean = 0' \
    "$TEST_DIR/.taskie/plans/test-plan/state.json" > "$TEST_DIR/.taskie/plans/test-plan/state.json.tmp"
mv "$TEST_DIR/.taskie/plans/test-plan/state.json.tmp" "$TEST_DIR/.taskie/plans/test-plan/state.json"

# Iteration 4: sonnet
export MOCK_CLAUDE_REVIEW_FILE="plan-review-4.md"
run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Verify model alternation in log
MODEL_1=$(sed -n '1p' "$MOCK_LOG" | grep -oE -- '--model [a-z]+' | awk '{print $2}')
MODEL_2=$(sed -n '2p' "$MOCK_LOG" | grep -oE -- '--model [a-z]+' | awk '{print $2}')
MODEL_3=$(sed -n '3p' "$MOCK_LOG" | grep -oE -- '--model [a-z]+' | awk '{print $2}')
MODEL_4=$(sed -n '4p' "$MOCK_LOG" | grep -oE -- '--model [a-z]+' | awk '{print $2}')

if [ "$MODEL_1" = "opus" ] && [ "$MODEL_2" = "sonnet" ] && [ "$MODEL_3" = "opus" ] && [ "$MODEL_4" = "sonnet" ]; then
    pass "Full model alternation across 4 iterations (opus → sonnet → opus → sonnet)"
else
    fail "Model alternation incorrect: $MODEL_1 → $MODEL_2 → $MODEL_3 → $MODEL_4"
fi
cleanup

# Test 11: Two consecutive clean reviews auto-advance (integration)
MOCK_LOG=$(mktemp)
TEST_DIR=$(mktemp -d)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_EXIT_CODE=0

# First PASS review - should block and increment consecutive_clean to 1
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

CONSEC_CLEAN_1=$(jq -r '.consecutive_clean' "$TEST_DIR/.taskie/plans/test-plan/state.json")
NEXT_PHASE_1=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")

# Simulate post-review (no fixes needed for PASS)
rm -f "$TEST_DIR/.taskie/plans/test-plan/plan-review-1.md"
jq '.phase = "post-plan-review" | .next_phase = "plan-review" | .phase_iteration = 1 | .review_model = "sonnet"' \
    "$TEST_DIR/.taskie/plans/test-plan/state.json" > "$TEST_DIR/.taskie/plans/test-plan/state.json.tmp"
mv "$TEST_DIR/.taskie/plans/test-plan/state.json.tmp" "$TEST_DIR/.taskie/plans/test-plan/state.json"

# Second PASS review - should approve and advance to create-tasks
export MOCK_CLAUDE_REVIEW_FILE="plan-review-2.md"
run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

CONSEC_CLEAN_2=$(jq -r '.consecutive_clean' "$TEST_DIR/.taskie/plans/test-plan/state.json")
NEXT_PHASE_2=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")

if [ "$CONSEC_CLEAN_1" = "1" ] && [ "$NEXT_PHASE_1" = "post-plan-review" ] && \
   [ "$CONSEC_CLEAN_2" = "2" ] && [ "$NEXT_PHASE_2" = "create-tasks" ] && \
   assert_approved; then
    pass "Two consecutive clean reviews auto-advance to next phase"
else
    fail "Consecutive clean auto-advance failed (clean1: $CONSEC_CLEAN_1, next1: $NEXT_PHASE_1, clean2: $CONSEC_CLEAN_2, next2: $NEXT_PHASE_2)"
fi
cleanup

# Test 12: Atomic write - no temp files left behind
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

# Check for temp files (.state.json.*)
TEMP_FILES=$(find "$TEST_DIR/.taskie/plans/test-plan" -name ".state.json.*" 2>/dev/null | wc -l)
if [ "$TEMP_FILES" -eq 0 ]; then
    pass "Atomic write leaves no temp files behind"
else
    fail "Atomic write left $TEMP_FILES temp file(s) behind"
fi
cleanup

# Print results
print_results
