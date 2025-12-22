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

# Find recently modified plan directory using git
RECENT_PLAN=$(git diff --name-only HEAD 2>/dev/null | grep "^\.taskie/plans/" | head -1 | cut -d'/' -f3 2>/dev/null || true)

# If no changes in last commit, check working tree
if [ -z "$RECENT_PLAN" ]; then
    RECENT_PLAN=$(git status --porcelain 2>/dev/null | grep "\.taskie/plans/" | head -1 | awk '{print $2}' | cut -d'/' -f3 2>/dev/null || true)
fi

# If git fails or no plan found, skip validation
if [ -z "$RECENT_PLAN" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

PLAN_DIR=".taskie/plans/$RECENT_PLAN"

if [ ! -d "$PLAN_DIR" ]; then
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

    # Rule 6: Check for timeline/date patterns in filenames
    if find "$plan_dir" -type f -name "*.md" | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}|week|month|day|hour' >/dev/null 2>&1; then
        echo "Found timeline estimates or dates in filenames (forbidden)"
        return 1
    fi

    return 0
}

# Run validation
ERROR_MSG=$(validate_plan_structure "$PLAN_DIR" 2>&1)
VALIDATION_RESULT=$?

if [ $VALIDATION_RESULT -eq 0 ]; then
    echo '{"decision": "approve"}'
else
    jq -n --arg reason "$ERROR_MSG" '{
        "decision": "block",
        "reason": $reason
    }'
fi

exit 0
