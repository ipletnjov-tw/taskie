#!/usr/bin/env bash
# Mock claude CLI for testing
# Simulates the real CLI based on environment variables:
#   MOCK_CLAUDE_EXIT_CODE — exit code to return (default: 0)
#   MOCK_CLAUDE_VERDICT — verdict to return: "PASS" or "FAIL" (default: "FAIL")
#   MOCK_CLAUDE_REVIEW_DIR — directory to write review file
#   MOCK_CLAUDE_REVIEW_FILE — filename of the review file to write
#   MOCK_CLAUDE_DELAY — seconds to sleep before responding (for timeout tests)
#   MOCK_CLAUDE_LOG — file to append invocation args to (for verifying correct flags)

# Log the invocation for verification (one line per invocation)
if [ -n "${MOCK_CLAUDE_LOG:-}" ]; then
    # Collapse multi-line args to single line so each invocation = 1 line
    echo "$*" | tr '\n' ' ' >> "$MOCK_CLAUDE_LOG"
    echo "" >> "$MOCK_CLAUDE_LOG"
fi

# Simulate delay if requested
if [ -n "${MOCK_CLAUDE_DELAY:-}" ]; then
    sleep "$MOCK_CLAUDE_DELAY"
fi

# Write a review file if configured
if [ -n "${MOCK_CLAUDE_REVIEW_DIR:-}" ] && [ -n "${MOCK_CLAUDE_REVIEW_FILE:-}" ]; then
    # Ensure directory exists
    mkdir -p "${MOCK_CLAUDE_REVIEW_DIR}"

    VERDICT="${MOCK_CLAUDE_VERDICT:-FAIL}"
    if [ "$VERDICT" = "PASS" ]; then
        cat > "${MOCK_CLAUDE_REVIEW_DIR}/${MOCK_CLAUDE_REVIEW_FILE}" << 'EOF'
# Review
No issues found. The implementation looks good.
EOF
    else
        cat > "${MOCK_CLAUDE_REVIEW_DIR}/${MOCK_CLAUDE_REVIEW_FILE}" << 'EOF'
# Review
## Issues Found
1. Example issue description
EOF
    fi
fi

# Return structured JSON on stdout matching --output-format json format
VERDICT="${MOCK_CLAUDE_VERDICT:-FAIL}"
cat << EOF
{
  "result": {"verdict": "$VERDICT"},
  "session_id": "mock-session",
  "cost": {"input_tokens": 100, "output_tokens": 50},
  "usage": {"requests": 1}
}
EOF

# Exit with configured exit code
exit ${MOCK_CLAUDE_EXIT_CODE:-0}
