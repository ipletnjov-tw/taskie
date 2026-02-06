#!/bin/bash
# Taskie Test Runner
#
# Simple wrapper to run all tests in the project.
#
# Usage:
#   ./run-tests.sh              # Run all tests
#   ./run-tests.sh --verbose    # Run tests with verbose output
#   ./run-tests.sh hooks        # Run only hook tests

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

print_header

# Parse arguments
TEST_SUITE="${1:-all}"
VERBOSE_FLAG=""

if [[ "${1:-}" == "--verbose" ]] || [[ "${2:-}" == "--verbose" ]]; then
    VERBOSE_FLAG="--verbose"
fi

case "$TEST_SUITE" in
    all|hooks)
        echo "Running hook tests..."
        bash "$SCRIPT_DIR/tests/hooks/test-validate-ground-rules.sh" $VERBOSE_FLAG
        ;;
    *)
        echo "Unknown test suite: $TEST_SUITE"
        echo ""
        echo "Usage:"
        echo "  ./run-tests.sh [all|hooks] [--verbose]"
        echo ""
        echo "Examples:"
        echo "  ./run-tests.sh              # Run all tests"
        echo "  ./run-tests.sh --verbose    # Run with verbose output"
        echo "  ./run-tests.sh hooks        # Run only hook tests"
        exit 1
        ;;
esac
