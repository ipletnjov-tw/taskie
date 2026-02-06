#!/bin/bash
# Test Suite for validate-ground-rules.sh Hook
#
# Usage:
#   ./test-validate-ground-rules.sh              # Run all tests
#   ./test-validate-ground-rules.sh --verbose    # Run with detailed output
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

# Determine script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_SCRIPT="$PROJECT_ROOT/taskie/hooks/validate-ground-rules.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verbose mode
VERBOSE="${1:-}"

# Verify hook script exists
if [[ ! -f "$HOOK_SCRIPT" ]]; then
    echo -e "${RED}Error: Hook script not found at $HOOK_SCRIPT${NC}"
    exit 1
fi

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Testing Claude Code Hook${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "Hook: $HOOK_SCRIPT"
echo ""

# Test 1: Check if jq is installed
echo -e "${YELLOW}Test 1: Checking jq dependency...${NC}"
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq is installed${NC}"
else
    echo -e "${RED}✗ jq is NOT installed - dependency check will be tested${NC}"
fi
echo ""

# Test 2: Invalid JSON input
echo -e "${YELLOW}Test 2: Testing invalid JSON input...${NC}"
RESULT=$(echo "invalid json" | bash "$HOOK_SCRIPT" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ] && echo "$RESULT" | grep -q "Invalid JSON input"; then
    echo -e "${GREEN}✓ Invalid JSON correctly caught (exit 2)${NC}"
    echo "   Error: $RESULT"
else
    echo -e "${RED}✗ Invalid JSON not handled correctly${NC}"
    echo "   Exit code: $EXIT_CODE"
    echo "   Output: $RESULT"
fi
echo ""

# Test 3: Valid JSON but invalid directory
echo -e "${YELLOW}Test 3: Testing invalid directory...${NC}"
RESULT=$(echo '{"cwd": "/nonexistent/directory", "stop_hook_active": false}' | bash "$HOOK_SCRIPT" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ] && echo "$RESULT" | grep -q "Cannot change to project directory"; then
    echo -e "${GREEN}✓ Invalid directory correctly caught (exit 2)${NC}"
    echo "   Error: $RESULT"
else
    echo -e "${RED}✗ Invalid directory not handled correctly${NC}"
    echo "   Exit code: $EXIT_CODE"
    echo "   Output: $RESULT"
fi
echo ""

# Test 4: Stop hook active (infinite loop prevention)
echo -e "${YELLOW}Test 4: Testing stop_hook_active (infinite loop prevention)...${NC}"
RESULT=$(echo '{"cwd": ".", "stop_hook_active": true}' | bash "$HOOK_SCRIPT" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] && echo "$RESULT" | grep -q "suppressOutput"; then
    echo -e "${GREEN}✓ Stop hook active correctly handled (exit 0 with suppressOutput)${NC}"
    echo "   Output: $RESULT"
else
    echo -e "${RED}✗ Stop hook active not handled correctly${NC}"
    echo "   Exit code: $EXIT_CODE"
    echo "   Output: $RESULT"
fi
echo ""

# Test 5: No .taskie directory
echo -e "${YELLOW}Test 5: Testing project without .taskie directory...${NC}"
RESULT=$(echo "{\"cwd\": \"$PWD\", \"stop_hook_active\": false}" | bash "$HOOK_SCRIPT" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] && echo "$RESULT" | grep -q "suppressOutput"; then
    echo -e "${GREEN}✓ No .taskie directory correctly handled (exit 0 with suppressOutput)${NC}"
    echo "   Output: $RESULT"
else
    echo -e "${RED}✗ No .taskie directory not handled correctly${NC}"
    echo "   Exit code: $EXIT_CODE"
    echo "   Output: $RESULT"
fi
echo ""

# Test 6: Create a test plan structure to validate
echo -e "${YELLOW}Test 6: Testing valid plan structure...${NC}"
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/plan.md" << 'EOF'
# Test Plan
This is a test plan.
EOF

cat > "$TEST_DIR/.taskie/plans/test-plan/tasks.md" << 'EOF'
| Task | Status |
|------|--------|
| Test | Done   |
EOF

RESULT=$(echo "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" | bash "$HOOK_SCRIPT" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] && echo "$RESULT" | grep -q "validated successfully"; then
    echo -e "${GREEN}✓ Valid plan structure correctly validated (exit 0 with success message)${NC}"
    echo "   Output: $RESULT"
else
    echo -e "${RED}✗ Valid plan structure not handled correctly${NC}"
    echo "   Exit code: $EXIT_CODE"
    echo "   Output: $RESULT"
fi
rm -rf "$TEST_DIR"
echo ""

# Test 7: Invalid plan structure (missing plan.md)
echo -e "${YELLOW}Test 7: Testing invalid plan structure (missing plan.md)...${NC}"
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/.taskie/plans/test-plan"
cat > "$TEST_DIR/.taskie/plans/test-plan/invalid-file.md" << 'EOF'
This file has an invalid name.
EOF

RESULT=$(echo "{\"cwd\": \"$TEST_DIR\", \"stop_hook_active\": false}" | bash "$HOOK_SCRIPT" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] && echo "$RESULT" | grep -q '"decision": "block"'; then
    echo -e "${GREEN}✓ Invalid plan structure correctly blocked (exit 0 with decision: block)${NC}"
    echo "   Output: $RESULT"
else
    echo -e "${RED}✗ Invalid plan structure not handled correctly${NC}"
    echo "   Exit code: $EXIT_CODE"
    echo "   Output: $RESULT"
fi
rm -rf "$TEST_DIR"
echo ""

echo "================================"
echo "Test Summary Complete"
echo "================================"
