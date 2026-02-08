#!/bin/bash
# Taskie Test Runner
#
# Simple wrapper to run all tests in the project.
#
# Usage:
#   ./run-tests.sh                    # Run all tests
#   ./run-tests.sh all                # Run all tests
#   ./run-tests.sh hooks              # Run all hook tests
#   ./run-tests.sh state              # Run state/auto-review tests
#   ./run-tests.sh validation         # Run validation tests only
#   ./run-tests.sh tests/hooks/test-*.sh  # Run specific test file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       Taskie Test Suite Runner                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Parse arguments
TEST_SUITE="${1:-all}"

# If it looks like a file path, run that single file
if [[ "$TEST_SUITE" == *.sh ]]; then
    print_header
    echo "Running single test file: $TEST_SUITE"
    bash "$SCRIPT_DIR/$TEST_SUITE"
    exit $?
fi

print_header

case "$TEST_SUITE" in
    all|hooks)
        echo "Running all hook tests..."
        for test_file in "$SCRIPT_DIR"/tests/hooks/test-*.sh; do
            if [ -f "$test_file" ]; then
                echo "Running $(basename "$test_file")..."
                bash "$test_file" || exit 1
            fi
        done
        ;;
    state)
        echo "Running state/auto-review tests..."
        for test_file in test-stop-hook-auto-review.sh test-stop-hook-state-transitions.sh test-stop-hook-cli-invocation.sh test-stop-hook-edge-cases.sh; do
            if [ -f "$SCRIPT_DIR/tests/hooks/$test_file" ]; then
                echo "Running $test_file..."
                bash "$SCRIPT_DIR/tests/hooks/$test_file" || exit 1
            fi
        done
        ;;
    validation)
        echo "Running validation tests..."
        if [ -f "$SCRIPT_DIR/tests/hooks/test-stop-hook-validation.sh" ]; then
            bash "$SCRIPT_DIR/tests/hooks/test-stop-hook-validation.sh"
        elif [ -f "$SCRIPT_DIR/tests/hooks/test-validate-ground-rules.sh" ]; then
            bash "$SCRIPT_DIR/tests/hooks/test-validate-ground-rules.sh"
        else
            echo "Error: validation test file not found"
            exit 1
        fi
        ;;
    *)
        echo "Unknown test suite: $TEST_SUITE"
        echo ""
        echo "Usage:"
        echo "  ./run-tests.sh [all|hooks|state|validation|path/to/test.sh]"
        echo ""
        echo "Examples:"
        echo "  ./run-tests.sh                    # Run all tests"
        echo "  ./run-tests.sh hooks              # Run all hook tests"
        echo "  ./run-tests.sh state              # Run state/auto-review tests"
        echo "  ./run-tests.sh validation         # Run validation tests only"
        echo "  ./run-tests.sh tests/hooks/test-stop-hook-validation.sh  # Run specific file"
        exit 1
        ;;
esac
