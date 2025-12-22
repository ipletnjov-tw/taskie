#!/bin/bash
# Taskie Ground Rules Validator
# Validates project structure against ground-rules.md using Haiku

set -euo pipefail

# Read hook input from stdin
EVENT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$EVENT" | jq -r '.stop_hook_active // false')

# Prevent infinite loops - always approve if already in continuation
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Get project directory
PROJECT_DIR=$(echo "$EVENT" | jq -r '.cwd // "."')

# Check if .taskie directory exists (skip validation if not using Taskie)
if [ ! -d "$PROJECT_DIR/.taskie" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Find the most recently modified plan directory using git
cd "$PROJECT_DIR"
RECENT_PLAN=$(git diff --name-only HEAD 2>/dev/null | grep "^\.taskie/plans/" | head -1 | cut -d'/' -f3)

# If no changes in current commit, check working tree
if [ -z "$RECENT_PLAN" ]; then
    RECENT_PLAN=$(git status --porcelain 2>/dev/null | grep "^ *[MAD] \.taskie/plans/" | head -1 | awk '{print $2}' | cut -d'/' -f3)
fi

# If still no plan found, approve (nothing to validate)
if [ -z "$RECENT_PLAN" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Get files only for this specific plan
PLAN_FILES=$(find ".taskie/plans/$RECENT_PLAN" -type f -name "*.md" 2>/dev/null | sort || echo "No files")

# Build validation prompt for Haiku
VALIDATION_PROMPT="You are validating Taskie project structure for plan: $RECENT_PLAN

Ground rules specify this structure:
.taskie/plans/{plan-id}/plan.md, tasks.md, task-*.md, etc.

Files in .taskie/plans/$RECENT_PLAN/:
$PLAN_FILES

Valid file types, reviews, and post-review files:
- plan.md → plan-review-{n}.md → plan-post-review-{n}.md
- design.md → design-review-{n}.md → design-post-review-{n}.md
- tasks.md → tasks-review-{n}.md → tasks-post-review-{n}.md
- task-{id}.md → task-{id}-review-{n}.md → task-{id}-post-review-{n}.md

Where {n} is a number (1, 2, 3...) and {id} is a task identifier.
Post-review files document fixes made after addressing review feedback.

Validate this plan directory ONLY:
1. Must be in .taskie/plans/$RECENT_PLAN/ (not nested deeper)
2. Must have plan.md (required)
3. design.md is optional
4. tasks.md is optional (comes later in workflow)
5. If task-{id}.md files exist, tasks.md should also exist
6. Review files must match their base file (e.g., plan-review-1.md only if plan.md exists)
7. Post-review files must match review files (e.g., plan-post-review-1.md only if plan-review-1.md exists)
8. No timeline estimates or dates in filenames

Return ONLY this JSON format (no markdown, no prose):
{\"valid\": true} if compliant
{\"valid\": false, \"issue\": \"brief description of what's wrong and where\"} if violations found"

# Define JSON schema for structured output
JSON_SCHEMA='{
  "type": "object",
  "properties": {
    "valid": {"type": "boolean"},
    "issue": {"type": "string"}
  },
  "required": ["valid"]
}'

# Call Haiku with structured output
RESPONSE=$(echo "$VALIDATION_PROMPT" | \
    claude --model haiku \
           --output-format json \
           --json-schema "$JSON_SCHEMA" \
    2>/dev/null || echo '{"valid": true}')

# Parse structured output (claude returns stream format with type: result)
VALID=$(echo "$RESPONSE" | jq -r 'if type == "array" then .[] | select(.type == "result") | .structured_output.valid else .valid end // true' 2>/dev/null)
ISSUE=$(echo "$RESPONSE" | jq -r 'if type == "array" then .[] | select(.type == "result") | .structured_output.issue else .issue end // ""' 2>/dev/null)

# Return decision
if [ "$VALID" = "true" ]; then
    echo '{"decision": "approve"}'
else
    jq -n --arg reason "Ground-rules violation: $ISSUE" '{
        "decision": "block",
        "reason": $reason
    }'
fi

exit 0
