#!/usr/bin/env bash
# Test Suite 3: Stop Hook State Transitions
#
# Tests state.json updates and field transitions after reviews.

set -uo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-utils.sh"

# Set hook script for test helpers
HOOK_SCRIPT="$SCRIPT_DIR/../../taskie/hooks/stop-hook.sh"

# Configure mock claude
export PATH="$SCRIPT_DIR/helpers:$PATH"

echo "================================"
echo "Test Suite 3: State Transitions"
echo "================================"
echo ""
echo "Hook: $HOOK_SCRIPT"
echo ""

cleanup() {
    rm -rf "${TEST_DIR:-}" "${MOCK_LOG:-}" 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: State updated correctly after plan-review FAIL
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

# Verify state updates
PHASE=$(jq -r '.phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
NEXT_PHASE=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
ITERATION=$(jq -r '.phase_iteration' "$TEST_DIR/.taskie/plans/test-plan/state.json")
MODEL=$(jq -r '.review_model' "$TEST_DIR/.taskie/plans/test-plan/state.json")
CLEAN=$(jq -r '.consecutive_clean' "$TEST_DIR/.taskie/plans/test-plan/state.json")

if [ "$PHASE" = "plan-review" ] && [ "$NEXT_PHASE" = "post-plan-review" ] && [ "$ITERATION" = "1" ] && [ "$MODEL" = "sonnet" ] && [ "$CLEAN" = "0" ]; then
    pass "State updated correctly after plan-review FAIL"
else
    fail "State incorrect: phase=$PHASE, next_phase=$NEXT_PHASE, iteration=$ITERATION, model=$MODEL, clean=$CLEAN"
fi
cleanup

# Test 2: Model alternation opus -> sonnet
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "implementation", "next_phase": "code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 1, "tdd": false, "current_task": 1, "phase_iteration": 2}'

export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="code-review-3.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

MODEL=$(jq -r '.review_model' "$TEST_DIR/.taskie/plans/test-plan/state.json")
if [ "$MODEL" = "sonnet" ]; then
    pass "Model alternation opus -> sonnet"
else
    fail "Model not alternated correctly: $MODEL"
fi
cleanup

# Test 3: Model alternation sonnet -> opus
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1 | done |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-tasks-review", "next_phase": "tasks-review", "review_model": "sonnet", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 1}'

export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="tasks-review-2.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

MODEL=$(jq -r '.review_model' "$TEST_DIR/.taskie/plans/test-plan/state.json")
if [ "$MODEL" = "opus" ]; then
    pass "Model alternation sonnet -> opus"
else
    fail "Model not alternated correctly: $MODEL"
fi
cleanup

# Test 4: tasks-review state updates after FAIL
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1 | pending |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "create-tasks", "next_phase": "tasks-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="tasks-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

PHASE=$(jq -r '.phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
NEXT_PHASE=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
ITERATION=$(jq -r '.phase_iteration' "$TEST_DIR/.taskie/plans/test-plan/state.json")

if [ "$PHASE" = "tasks-review" ] && [ "$NEXT_PHASE" = "post-tasks-review" ] && [ "$ITERATION" = "1" ]; then
    pass "tasks-review state updates correctly after FAIL"
else
    fail "tasks-review state incorrect: phase=$PHASE, next_phase=$NEXT_PHASE, iteration=$ITERATION"
fi
cleanup

# Test 5: code-review state updates after FAIL
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "complete-task", "next_phase": "code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": 1, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="code-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

PHASE=$(jq -r '.phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
NEXT_PHASE=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
ITERATION=$(jq -r '.phase_iteration' "$TEST_DIR/.taskie/plans/test-plan/state.json")

if [ "$PHASE" = "code-review" ] && [ "$NEXT_PHASE" = "post-code-review" ] && [ "$ITERATION" = "1" ]; then
    pass "code-review state updates correctly after FAIL"
else
    fail "code-review state incorrect: phase=$PHASE, next_phase=$NEXT_PHASE, iteration=$ITERATION"
fi
cleanup

# Test 6: all-code-review state updates after FAIL
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1 | done |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "complete-task", "next_phase": "all-code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="all-code-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

PHASE=$(jq -r '.phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
NEXT_PHASE=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
ITERATION=$(jq -r '.phase_iteration' "$TEST_DIR/.taskie/plans/test-plan/state.json")

if [ "$PHASE" = "all-code-review" ] && [ "$NEXT_PHASE" = "post-all-code-review" ] && [ "$ITERATION" = "1" ]; then
    pass "all-code-review state updates correctly after FAIL"
else
    fail "all-code-review state incorrect: phase=$PHASE, next_phase=$NEXT_PHASE, iteration=$ITERATION"
fi
cleanup

# Test 9: consecutive_clean increments on PASS
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 0, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

CLEAN=$(jq -r '.consecutive_clean' "$TEST_DIR/.taskie/plans/test-plan/state.json")
if [ "$CLEAN" = "1" ]; then
    pass "consecutive_clean incremented on PASS (0 -> 1)"
else
    fail "consecutive_clean not incremented: $CLEAN"
fi
cleanup

# Test 10: consecutive_clean resets to 0 on FAIL
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 1, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

CLEAN=$(jq -r '.consecutive_clean' "$TEST_DIR/.taskie/plans/test-plan/state.json")
if [ "$CLEAN" = "0" ]; then
    pass "consecutive_clean resets on FAIL (1 -> 0)"
else
    fail "consecutive_clean not reset: $CLEAN"
fi
cleanup

# Test 11: Auto-advance to create-tasks after 2 clean plan-reviews
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 1, "tdd": false, "current_task": null, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

NEXT=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
if [ $HOOK_EXIT_CODE -eq 0 ] && [ "$NEXT" = "create-tasks" ] && echo "$HOOK_STDOUT" | grep -q "passed"; then
    pass "Auto-advance to create-tasks after 2 clean plan-reviews"
else
    fail "Auto-advance not triggered correctly: next_phase=$NEXT"
fi
cleanup

# Test 12: Auto-advance to complete-task after 2 clean tasks-reviews (tdd=false)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1 | done |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-tasks-review", "next_phase": "tasks-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 1, "tdd": false, "current_task": 1, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="tasks-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

NEXT=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
if [ "$NEXT" = "complete-task" ]; then
    pass "Auto-advance to complete-task (tdd=false)"
else
    fail "Auto-advance incorrect: next_phase=$NEXT"
fi
cleanup

# Test 13: Auto-advance to complete-task-tdd (tdd=true)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1 | done |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-tasks-review", "next_phase": "tasks-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 1, "tdd": true, "current_task": 1, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="tasks-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

NEXT=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
if [ "$NEXT" = "complete-task-tdd" ]; then
    pass "Auto-advance to complete-task-tdd (tdd=true)"
else
    fail "Auto-advance incorrect: next_phase=$NEXT"
fi
cleanup

# Test 14: Auto-advance to all-code-review when no tasks remain
MOCK_LOG=$(mktemp /tmp/taskie-test.XXXXXX)
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1  | done   |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "implementation", "next_phase": "code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 1, "tdd": false, "current_task": 1, "phase_iteration": 0}'

export MOCK_CLAUDE_LOG="$MOCK_LOG"
export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="code-review-1.md"
export MOCK_CLAUDE_EXIT_CODE=0

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

NEXT=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
ITERATION=$(jq -r '.phase_iteration' "$TEST_DIR/.taskie/plans/test-plan/state.json")
if [ "$NEXT" = "all-code-review" ] && [ "$ITERATION" = "0" ]; then
    pass "Auto-advance to all-code-review with fresh cycle (iteration=0)"
else
    fail "Auto-advance incorrect: next_phase=$NEXT, iteration=$ITERATION"
fi
cleanup

# Test 15: Auto-advance to complete after all-code-review
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Id | Status |
|----|--------|
| 1 | done |
EOF
touch "$TEST_DIR/.taskie/plans/test-plan/task-1.md"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-all-code-review", "next_phase": "all-code-review", "review_model": "opus", "max_reviews": 8, "consecutive_clean": 1, "tdd": false, "current_task": 1, "phase_iteration": 0}'

export MOCK_CLAUDE_VERDICT="PASS"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="all-code-review-1.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

NEXT=$(jq -r '.next_phase' "$TEST_DIR/.taskie/plans/test-plan/state.json")
if [ "$NEXT" = "complete" ]; then
    pass "Auto-advance to complete after all-code-review"
else
    fail "Auto-advance incorrect: next_phase=$NEXT"
fi
cleanup

# Test 16: All fields preserved during state update
TEST_DIR=$(mktemp -d /tmp/taskie-test.XXXXXX)
create_test_plan "$TEST_DIR/.taskie/plans/test-plan"
create_state_json "$TEST_DIR/.taskie/plans/test-plan" '{"phase": "post-plan-review", "next_phase": "plan-review", "review_model": "opus", "max_reviews": 5, "consecutive_clean": 0, "tdd": true, "current_task": 3, "phase_iteration": 2}'

export MOCK_CLAUDE_VERDICT="FAIL"
export MOCK_CLAUDE_REVIEW_DIR="$TEST_DIR/.taskie/plans/test-plan"
export MOCK_CLAUDE_REVIEW_FILE="plan-review-3.md"

run_hook "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" || true

MAX=$(jq -r '.max_reviews' "$TEST_DIR/.taskie/plans/test-plan/state.json")
TASK=$(jq -r '.current_task' "$TEST_DIR/.taskie/plans/test-plan/state.json")
TDD=$(jq -r '.tdd' "$TEST_DIR/.taskie/plans/test-plan/state.json")

if [ "$MAX" = "5" ] && [ "$TASK" = "3" ] && [ "$TDD" = "true" ]; then
    pass "All fields preserved during state update"
else
    fail "Fields not preserved: max_reviews=$MAX, current_task=$TASK, tdd=$TDD"
fi
cleanup

print_results
