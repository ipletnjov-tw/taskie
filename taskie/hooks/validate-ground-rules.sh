#!/bin/bash
# Taskie Ground Rules Validator
# Validates project structure against ground-rules.md

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
cd "$PROJECT_DIR"

# Check if .taskie directory exists (skip validation if not using Taskie)
if [ ! -d ".taskie/plans" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Validation function
validate_plan_structure() {
    local plan_dir="$1"

    # Rule 1: plan.md must exist
    if [ ! -f "$plan_dir/plan.md" ]; then
        echo "Missing required file: plan.md"
        return 1
    fi

    # Rule 1.5: Validate file naming conventions
    for file in "$plan_dir"/*.md; do
        [ -e "$file" ] || continue
        local filename=$(basename "$file")

        # Valid patterns:
        # - plan.md, design.md, tasks.md
        # - task-{id}.md
        # - plan-review-{n}.md, design-review-{n}.md, tasks-review-{n}.md
        # - task-{id}-review-{n}.md
        # - plan-post-review-{n}.md, design-post-review-{n}.md, tasks-post-review-{n}.md
        # - task-{id}-post-review-{n}.md

        if [[ ! "$filename" =~ ^(plan|design|tasks)\.md$ ]] && \
           [[ ! "$filename" =~ ^task-[a-zA-Z0-9_-]+\.md$ ]] && \
           [[ ! "$filename" =~ ^(plan|design|tasks)-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^task-[a-zA-Z0-9_-]+-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^(plan|design|tasks)-post-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^task-[a-zA-Z0-9_-]+-post-review-[0-9]+\.md$ ]]; then
            echo "Invalid filename: $filename (doesn't match naming conventions)"
            return 1
        fi
    done

    # Rule 2: Check for nested directories (files should be directly in plan dir)
    if find "$plan_dir" -mindepth 2 -type f -name "*.md" 2>/dev/null | grep -q .; then
        echo "Files found in nested directories (must be directly in $plan_dir)"
        return 1
    fi

    # Rule 3: Review files need their base files
    for review_file in "$plan_dir"/*-review-[0-9]*.md; do
        [ -e "$review_file" ] || continue

        local base_name=$(basename "$review_file" | sed 's/-review-[0-9]*.md$//')

        if [ "$base_name" = "plan" ] || [ "$base_name" = "design" ] || [ "$base_name" = "tasks" ]; then
            if [ ! -f "$plan_dir/${base_name}.md" ]; then
                echo "Review file $(basename "$review_file") exists but ${base_name}.md does not"
                return 1
            fi
        fi
    done

    # Rule 4: Post-review files need their review files
    for post_review in "$plan_dir"/*-post-review-[0-9]*.md; do
        [ -e "$post_review" ] || continue

        local review_file=$(basename "$post_review" | sed 's/-post-review-/-review-/')

        if [ ! -f "$plan_dir/$review_file" ]; then
            echo "Post-review file $(basename "$post_review") exists but $review_file does not"
            return 1
        fi
    done

    # Rule 5: If task files exist, tasks.md should exist
    if ls "$plan_dir"/task-*.md 2>/dev/null | grep -v "review" | grep -q .; then
        if [ ! -f "$plan_dir/tasks.md" ]; then
            echo "Task files exist but tasks.md is missing"
            return 1
        fi
    fi

    # Rule 6: tasks.md must contain ONLY a markdown table
    if [ -f "$plan_dir/tasks.md" ]; then
        # Every non-empty line must start and end with |
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip empty lines
            [ -z "$line" ] && continue
            # Line must start with | and end with |
            if [[ ! "$line" =~ ^\|.*\|$ ]]; then
                echo "tasks.md must contain ONLY the tasks table (found non-table content)"
                return 1
            fi
        done < "$plan_dir/tasks.md"

        # Must have at least one table row
        if ! grep -q "^|" "$plan_dir/tasks.md"; then
            echo "tasks.md must contain a table (no table rows found)"
            return 1
        fi
    fi

    return 0
}

# Validate all plan directories
VALIDATION_ERRORS=""

for PLAN_DIR in .taskie/plans/*/; do
    [ -d "$PLAN_DIR" ] || continue

    # Run validation for this plan
    set +e
    PLAN_ERROR=$(validate_plan_structure "$PLAN_DIR" 2>&1)
    PLAN_RESULT=$?
    set -e

    if [ $PLAN_RESULT -ne 0 ]; then
        PLAN_NAME=$(basename "$PLAN_DIR")
        if [ -z "$VALIDATION_ERRORS" ]; then
            VALIDATION_ERRORS="Plan '$PLAN_NAME': $PLAN_ERROR"
        else
            VALIDATION_ERRORS="$VALIDATION_ERRORS; Plan '$PLAN_NAME': $PLAN_ERROR"
        fi
    fi
done

# Return result
if [ -z "$VALIDATION_ERRORS" ]; then
    echo '{"decision": "approve"}'
    exit 0
else
    jq -n --arg reason "$VALIDATION_ERRORS" '{
        "decision": "block",
        "reason": $reason
    }'
    exit 0
fi
