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

# Validation function - collects ALL violations
validate_plan_structure() {
    local plan_dir="$1"
    local errors=""

    add_error() {
        if [ -z "$errors" ]; then
            errors="$1"
        else
            errors="$errors; $1"
        fi
    }

    # Rule 1: plan.md must exist
    if [ ! -f "$plan_dir/plan.md" ]; then
        add_error "Missing required file: plan.md"
    fi

    # Rule 2: Validate file naming conventions
    for file in "$plan_dir"/*.md; do
        [ -e "$file" ] || continue
        local filename=$(basename "$file")

        # Valid patterns:
        # - plan.md, design.md, tasks.md
        # - task-{id}.md
        # - plan-review-{n}.md, design-review-{n}.md, tasks-review-{n}.md
        # - all-code-review-{n}.md
        # - task-{id}-review-{n}.md
        # - plan-post-review-{n}.md, design-post-review-{n}.md, tasks-post-review-{n}.md
        # - all-code-post-review-{n}.md
        # - task-{id}-post-review-{n}.md

        if [[ ! "$filename" =~ ^(plan|design|tasks)\.md$ ]] && \
           [[ ! "$filename" =~ ^task-[a-zA-Z0-9_-]+\.md$ ]] && \
           [[ ! "$filename" =~ ^(plan|design|tasks)-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^all-code-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^task-[a-zA-Z0-9_-]+-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^(plan|design|tasks)-post-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^all-code-post-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^task-[a-zA-Z0-9_-]+-post-review-[0-9]+\.md$ ]]; then
            add_error "Invalid filename: $filename"
        fi
    done

    # Rule 3: Check for nested directories (files should be directly in plan dir)
    if find "$plan_dir" -mindepth 2 -type f -name "*.md" 2>/dev/null | grep -q .; then
        add_error "Files found in nested directories"
    fi

    # Rule 4: Review files need their base files
    for review_file in "$plan_dir"/*-review-[0-9]*.md; do
        [ -e "$review_file" ] || continue

        local base_name=$(basename "$review_file" | sed 's/-review-[0-9]*.md$//')

        if [ "$base_name" = "plan" ] || [ "$base_name" = "design" ] || [ "$base_name" = "tasks" ]; then
            if [ ! -f "$plan_dir/${base_name}.md" ]; then
                add_error "$(basename "$review_file") requires ${base_name}.md"
            fi
        fi
    done

    # Rule 5: Post-review files need their review files
    for post_review in "$plan_dir"/*-post-review-[0-9]*.md; do
        [ -e "$post_review" ] || continue

        local review_file=$(basename "$post_review" | sed 's/-post-review-/-review-/')

        if [ ! -f "$plan_dir/$review_file" ]; then
            add_error "$(basename "$post_review") requires $review_file"
        fi
    done

    # Rule 6: If task files exist, tasks.md should exist
    if ls "$plan_dir"/task-*.md 2>/dev/null | grep -v "review" | grep -q .; then
        if [ ! -f "$plan_dir/tasks.md" ]; then
            add_error "Task files exist but tasks.md is missing"
        fi
    fi

    # Rule 7: tasks.md must contain ONLY a markdown table
    if [ -f "$plan_dir/tasks.md" ]; then
        local table_error=""
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            if [[ ! "$line" =~ ^\|.*\|$ ]]; then
                table_error="tasks.md contains non-table content"
                break
            fi
        done < "$plan_dir/tasks.md"

        if [ -n "$table_error" ]; then
            add_error "$table_error"
        elif ! grep -q "^|" "$plan_dir/tasks.md"; then
            add_error "tasks.md has no table rows"
        fi
    fi

    if [ -n "$errors" ]; then
        echo "$errors"
        return 1
    fi
    return 0
}

# Find the most recently modified plan directory by file timestamp
RECENT_PLAN=$(find .taskie/plans -mindepth 2 -maxdepth 2 -type f -name "*.md" -printf '%T@ %h\n' 2>/dev/null | sort -rn | head -1 | awk '{print $2}')

# If no plan files found, approve
if [ -z "$RECENT_PLAN" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Validate only the most recently modified plan
set +e
PLAN_ERROR=$(validate_plan_structure "$RECENT_PLAN" 2>&1)
PLAN_RESULT=$?
set -e

if [ $PLAN_RESULT -eq 0 ]; then
    echo '{"decision": "approve"}'
else
    PLAN_NAME=$(basename "$RECENT_PLAN")
    jq -n --arg reason "Plan '$PLAN_NAME': $PLAN_ERROR" '{
        "decision": "block",
        "reason": $reason
    }'
fi
exit 0
