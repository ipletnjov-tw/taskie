#!/bin/bash
# Taskie Unified Stop Hook
# Validates project structure and triggers automated reviews

set -euo pipefail

# Check for required dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Install it with: apt-get install jq" >&2
    exit 2
fi

# Resolve plugin root relative to hook location
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Read hook input from stdin
EVENT=$(cat)

# Validate JSON input
if ! echo "$EVENT" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON input from hook event" >&2
    exit 2
fi

STOP_HOOK_ACTIVE=$(echo "$EVENT" | jq -r '.stop_hook_active // false')

# Prevent infinite loops - always approve if already in continuation
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    echo '{"suppressOutput": true}'
    exit 0
fi

# Get project directory
CWD=$(echo "$EVENT" | jq -r '.cwd // "."')

# Change to project directory with error handling
if ! cd "$CWD" 2>/dev/null; then
    echo "Error: Cannot change to project directory: $CWD" >&2
    exit 2
fi

# Check if .taskie directory exists (skip validation if not using Taskie)
if [ ! -d ".taskie/plans" ]; then
    echo '{"suppressOutput": true}'
    exit 0
fi

# Find the most recently modified plan directory by file timestamp
# Include both .md and state.json files in modification time consideration
RECENT_PLAN=$(find .taskie/plans -mindepth 2 -maxdepth 2 -type f \( -name "*.md" -o -name "state.json" \) -printf '%T@ %h\n' 2>/dev/null | sort -rn | head -1 | awk '{print $2}')

# If no plan files found, approve
if [ -z "$RECENT_PLAN" ]; then
    echo '{"suppressOutput": true}'
    exit 0
fi

# Step 5: Auto-review logic
STATE_FILE="$RECENT_PLAN/state.json"
PLAN_ID=$(basename "$RECENT_PLAN")

# Step 5a: Read state.json if it exists
if [ -f "$STATE_FILE" ]; then
    # Validate JSON syntax
    if ! jq empty "$STATE_FILE" 2>/dev/null; then
        echo "Warning: state.json contains invalid JSON, falling back to validation" >&2
    else
        # Read all state fields with default operators for forward compatibility
        MAX_REVIEWS=$(jq -r '(.max_reviews // 8)' "$STATE_FILE" 2>/dev/null)
        CURRENT_TASK=$(jq -r '(.current_task // null)' "$STATE_FILE" 2>/dev/null)
        PHASE=$(jq -r '(.phase // "")' "$STATE_FILE" 2>/dev/null)
        PHASE_ITERATION=$(jq -r '(.phase_iteration // 0)' "$STATE_FILE" 2>/dev/null)
        NEXT_PHASE=$(jq -r '(.next_phase // "")' "$STATE_FILE" 2>/dev/null)
        REVIEW_MODEL=$(jq -r '(.review_model // "opus")' "$STATE_FILE" 2>/dev/null)
        CONSECUTIVE_CLEAN=$(jq -r '(.consecutive_clean // 0)' "$STATE_FILE" 2>/dev/null)
        TDD=$(jq -r '(.tdd // false)' "$STATE_FILE" 2>/dev/null)

        # Check if next_phase is a review phase
        if [[ "$NEXT_PHASE" =~ ^(plan-review|tasks-review|code-review|all-code-review)$ ]]; then
            # Extract review type from next_phase
            REVIEW_TYPE="$NEXT_PHASE"

            # Step 5a: Check max_reviews == 0 (skip reviews)
            if [ "$MAX_REVIEWS" -eq 0 ]; then
                # Determine advance target based on review type
                case "$REVIEW_TYPE" in
                    plan-review)
                        ADVANCE_TARGET="create-tasks"
                        ;;
                    tasks-review)
                        if [ "$TDD" = "true" ]; then
                            ADVANCE_TARGET="complete-task-tdd"
                        else
                            ADVANCE_TARGET="complete-task"
                        fi
                        ;;
                    code-review)
                        # Check if more tasks remain
                        TASKS_REMAIN=$(grep '^|' "$RECENT_PLAN/tasks.md" 2>/dev/null | tail -n +3 | awk -F'|' -v cur="$CURRENT_TASK" '{gsub(/[[:space:]]/, "", $2); if ($2 != cur) print $3}' | grep -i 'pending' | wc -l)
                        if [ "$TASKS_REMAIN" -gt 0 ]; then
                            if [ "$TDD" = "true" ]; then
                                ADVANCE_TARGET="complete-task-tdd"
                            else
                                ADVANCE_TARGET="complete-task"
                            fi
                        else
                            ADVANCE_TARGET="all-code-review"
                        fi
                        ;;
                    all-code-review)
                        ADVANCE_TARGET="complete"
                        ;;
                esac

                # Write state atomically with phase set to review type and next_phase to advance target
                TEMP_STATE=$(mktemp)
                jq --arg phase "$REVIEW_TYPE" \
                   --arg next_phase "$ADVANCE_TARGET" \
                   --argjson phase_iteration 0 \
                   '.phase = $phase | .next_phase = $next_phase | .phase_iteration = $phase_iteration' \
                   "$STATE_FILE" > "$TEMP_STATE"
                mv "$TEMP_STATE" "$STATE_FILE"

                echo "{\"systemMessage\": \"Reviews disabled (max_reviews=0). Auto-advanced to $ADVANCE_TARGET. Run /taskie:continue-plan to proceed.\", \"suppressOutput\": true}"
                exit 0
            fi

            # Step 5b: Increment phase_iteration
            PHASE_ITERATION=$((PHASE_ITERATION + 1))

            # Step 5c: Check if max_reviews exceeded (hard stop)
            if [ "$PHASE_ITERATION" -gt "$MAX_REVIEWS" ]; then
                echo "{\"systemMessage\": \"Max review limit ($MAX_REVIEWS) reached for $REVIEW_TYPE. Edit state.json to adjust max_reviews or set next_phase manually.\", \"suppressOutput\": true}"
                exit 0
            fi

            # Step 5d: Prepare for CLI invocation
            REVIEW_FILE="$RECENT_PLAN/${REVIEW_TYPE}-${PHASE_ITERATION}.md"
            LOG_FILE="$RECENT_PLAN/.review-${PHASE_ITERATION}.log"

            # Build task file list for tasks-review and all-code-review
            TASK_FILE_LIST=""
            if [[ "$REVIEW_TYPE" = "tasks-review" || "$REVIEW_TYPE" = "all-code-review" ]]; then
                if [ -f "$RECENT_PLAN/tasks.md" ]; then
                    TASK_FILE_LIST=$(grep '^|' "$RECENT_PLAN/tasks.md" | tail -n +3 | awk -F'|' -v plan="$PLAN_ID" '{gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9]+$/) printf ".taskie/plans/%s/task-%s.md ", plan, $2}')
                fi
                # Check for empty list
                if [ -z "$TASK_FILE_LIST" ]; then
                    echo "Warning: No task files found for $REVIEW_TYPE, skipping review" >&2
                    echo '{"systemMessage": "No task files found, skipping review", "suppressOutput": true}'
                    exit 0
                fi
            fi

            # For code-review, check if task file exists
            if [ "$REVIEW_TYPE" = "code-review" ]; then
                TASK_FILE="$RECENT_PLAN/task-${CURRENT_TASK}.md"
                if [ ! -f "$TASK_FILE" ]; then
                    echo "Warning: Task file task-${CURRENT_TASK}.md not found, skipping review" >&2
                    echo '{"systemMessage": "Task file not found, skipping review", "suppressOutput": true}'
                    exit 0
                fi
            fi

            # Build prompt based on review type
            case "$REVIEW_TYPE" in
                plan-review)
                    PROMPT="Review the plan in .taskie/plans/${PLAN_ID}/plan.md. Be critical and thorough. Look for ambiguities, missing details, architectural issues, and potential problems. Output your review to .taskie/plans/${PLAN_ID}/${REVIEW_TYPE}-${PHASE_ITERATION}.md"
                    FILES_TO_REVIEW=".taskie/plans/${PLAN_ID}/plan.md"
                    ;;
                tasks-review)
                    PROMPT="Review the tasks in .taskie/plans/${PLAN_ID}/tasks.md and the task files: ${TASK_FILE_LIST}. Be critical and thorough. Look for missing subtasks, unclear acceptance criteria, incorrect estimates, and implementation issues. Output your review to .taskie/plans/${PLAN_ID}/${REVIEW_TYPE}-${PHASE_ITERATION}.md"
                    FILES_TO_REVIEW=".taskie/plans/${PLAN_ID}/tasks.md $TASK_FILE_LIST"
                    ;;
                code-review)
                    PROMPT="Review the implementation for task ${CURRENT_TASK} documented in .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}.md. Be very critical. Look for bugs, mistakes, incomplete implementations, security issues, and code quality problems. Output your review to .taskie/plans/${PLAN_ID}/${REVIEW_TYPE}-${PHASE_ITERATION}.md"
                    FILES_TO_REVIEW=".taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}.md"
                    ;;
                all-code-review)
                    PROMPT="Review ALL implementations across ALL tasks documented in .taskie/plans/${PLAN_ID}/tasks.md and task files: ${TASK_FILE_LIST}. Be extremely critical. Look for bugs, integration issues, incomplete features, and overall code quality. Output your review to .taskie/plans/${PLAN_ID}/${REVIEW_TYPE}-${PHASE_ITERATION}.md"
                    FILES_TO_REVIEW=".taskie/plans/${PLAN_ID}/tasks.md $TASK_FILE_LIST"
                    ;;
            esac

            # Invoke claude CLI
            CLI_OUTPUT=""
            if command -v claude &> /dev/null; then
                set +e
                CLI_OUTPUT=$(claude --print \
                    --model "$REVIEW_MODEL" \
                    --output-format json \
                    --json-schema '{"type":"object","properties":{"verdict":{"type":"string","enum":["PASS","FAIL"]}},"required":["verdict"]}' \
                    --dangerously-skip-permissions \
                    "$PROMPT" $FILES_TO_REVIEW 2>"$LOG_FILE")
                CLI_EXIT=$?
                set -e

                # Step 5e: Verify review file was written
                if [ $CLI_EXIT -eq 0 ] && [ -f "$REVIEW_FILE" ]; then
                    # Success - clean up log file
                    rm -f "$LOG_FILE"

                    # Step 5f: Extract verdict from CLI output
                    VERDICT=$(echo "$CLI_OUTPUT" | jq -r '.result.verdict' 2>/dev/null || echo "")

                    # Update consecutive_clean based on verdict
                    if [ "$VERDICT" = "PASS" ]; then
                        CONSECUTIVE_CLEAN=$((CONSECUTIVE_CLEAN + 1))
                    else
                        # FAIL or parse error
                        CONSECUTIVE_CLEAN=0
                    fi

                    # Step 5g: Check for auto-advance (consecutive_clean >= 2)
                    if [ "$CONSECUTIVE_CLEAN" -ge 2 ]; then
                        # Determine advance target based on review type
                        case "$REVIEW_TYPE" in
                            plan-review)
                                ADVANCE_TARGET="create-tasks"
                                ;;
                            tasks-review)
                                if [ "$TDD" = "true" ]; then
                                    ADVANCE_TARGET="complete-task-tdd"
                                else
                                    ADVANCE_TARGET="complete-task"
                                fi
                                ;;
                            code-review)
                                # Check if more tasks remain
                                TASKS_REMAIN=$(grep '^|' "$RECENT_PLAN/tasks.md" 2>/dev/null | tail -n +3 | awk -F'|' -v cur="$CURRENT_TASK" '{gsub(/[[:space:]]/, "", $2); if ($2 != cur) print $3}' | grep -i 'pending' | wc -l)
                                if [ "$TASKS_REMAIN" -gt 0 ]; then
                                    if [ "$TDD" = "true" ]; then
                                        ADVANCE_TARGET="complete-task-tdd"
                                    else
                                        ADVANCE_TARGET="complete-task"
                                    fi
                                else
                                    # No tasks remain, go to all-code-review with fresh cycle
                                    ADVANCE_TARGET="all-code-review"
                                    # Reset for fresh review cycle
                                    PHASE_ITERATION=0
                                    REVIEW_MODEL="opus"
                                    CONSECUTIVE_CLEAN=0
                                fi
                                ;;
                            all-code-review)
                                ADVANCE_TARGET="complete"
                                ;;
                        esac

                        # Write state atomically for auto-advance
                        TEMP_STATE=$(mktemp)
                        jq --arg phase "$REVIEW_TYPE" \
                           --arg next_phase "$ADVANCE_TARGET" \
                           --argjson phase_iteration "$PHASE_ITERATION" \
                           --arg review_model "$REVIEW_MODEL" \
                           --argjson consecutive_clean "$CONSECUTIVE_CLEAN" \
                           --argjson max_reviews "$MAX_REVIEWS" \
                           --arg current_task "$CURRENT_TASK" \
                           --argjson tdd "$TDD" \
                           '.phase = $phase | .next_phase = $next_phase | .phase_iteration = $phase_iteration | .review_model = $review_model | .consecutive_clean = $consecutive_clean | .max_reviews = $max_reviews | .current_task = $current_task | .tdd = $tdd' \
                           "$STATE_FILE" > "$TEMP_STATE"
                        mv "$TEMP_STATE" "$STATE_FILE"

                        # Approve with message
                        echo "{\"systemMessage\": \"${REVIEW_TYPE} passed. Run /taskie:continue-plan to proceed.\", \"suppressOutput\": true}"
                        exit 0
                    fi

                    # Step 5h: Non-advance - update state and block
                    # Toggle review model
                    if [ "$REVIEW_MODEL" = "opus" ]; then
                        NEW_REVIEW_MODEL="sonnet"
                    else
                        NEW_REVIEW_MODEL="opus"
                    fi

                    # Determine post-review phase
                    POST_REVIEW_PHASE="post-${REVIEW_TYPE}"

                    # Write state atomically
                    TEMP_STATE=$(mktemp)
                    jq --arg phase "$REVIEW_TYPE" \
                       --arg next_phase "$POST_REVIEW_PHASE" \
                       --argjson phase_iteration "$PHASE_ITERATION" \
                       --arg review_model "$NEW_REVIEW_MODEL" \
                       --argjson consecutive_clean "$CONSECUTIVE_CLEAN" \
                       --argjson max_reviews "$MAX_REVIEWS" \
                       --arg current_task "$CURRENT_TASK" \
                       --argjson tdd "$TDD" \
                       '.phase = $phase | .next_phase = $next_phase | .phase_iteration = $phase_iteration | .review_model = $review_model | .consecutive_clean = $consecutive_clean | .max_reviews = $max_reviews | .current_task = $current_task | .tdd = $tdd' \
                       "$STATE_FILE" > "$TEMP_STATE"
                    mv "$TEMP_STATE" "$STATE_FILE"

                    # Return block decision with template
                    BLOCK_REASON="Review found issues. See ${REVIEW_FILE}. Run /taskie:${POST_REVIEW_PHASE} to address them. Escape hatch: edit state.json to set next_phase manually if needed."

                    jq -n --arg reason "$BLOCK_REASON" '{
                        "decision": "block",
                        "reason": $reason
                    }'
                    exit 0
                else
                    # CLI failed or review file missing
                    echo "Warning: Review failed (exit $CLI_EXIT) or review file not written" >&2
                    echo '{"systemMessage": "Review failed, proceeding without review", "suppressOutput": true}'
                    exit 0
                fi
            else
                echo "Warning: claude CLI not found, skipping review" >&2
                echo '{"systemMessage": "claude CLI not available, skipping review", "suppressOutput": true}'
                exit 0
            fi
        fi
    fi
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

    # Rule 8: state.json validation (if exists)
    if [ -f "$plan_dir/state.json" ]; then
        # Validate JSON syntax
        if ! jq empty "$plan_dir/state.json" 2>/dev/null; then
            echo "Warning: state.json contains invalid JSON" >&2
        else
            # Validate required fields (with forward-compatible default operators)
            local phase=$(jq -r '(.phase // "")' "$plan_dir/state.json" 2>/dev/null)
            local next_phase=$(jq -r '(.next_phase // "")' "$plan_dir/state.json" 2>/dev/null)
            local review_model=$(jq -r '(.review_model // "")' "$plan_dir/state.json" 2>/dev/null)
            local max_reviews=$(jq -r '(.max_reviews // 0)' "$plan_dir/state.json" 2>/dev/null)
            local consecutive_clean=$(jq -r '(.consecutive_clean // 0)' "$plan_dir/state.json" 2>/dev/null)
            local tdd=$(jq -r '(.tdd // false)' "$plan_dir/state.json" 2>/dev/null)

            local missing_fields=""
            [ -z "$phase" ] && missing_fields="${missing_fields}phase "
            [ -z "$next_phase" ] && missing_fields="${missing_fields}next_phase "
            [ -z "$review_model" ] && missing_fields="${missing_fields}review_model "

            if [ -n "$missing_fields" ]; then
                echo "Warning: state.json missing required fields: ${missing_fields}" >&2
            fi
        fi
    fi

    if [ -n "$errors" ]; then
        echo "$errors"
        return 1
    fi
    return 0
}

# Validate only the most recently modified plan
PLAN_NAME=$(basename "$RECENT_PLAN")
set +e
# Capture only stdout (errors), let stderr (warnings) pass through
PLAN_ERROR=$(validate_plan_structure "$RECENT_PLAN")
PLAN_RESULT=$?
set -e

if [ $PLAN_RESULT -eq 0 ]; then
    echo "{\"systemMessage\": \"Plan '$PLAN_NAME' structure validated successfully\", \"suppressOutput\": true}"
else
    jq -n --arg reason "Plan '$PLAN_NAME': $PLAN_ERROR" '{
        "decision": "block",
        "reason": $reason
    }'
fi
exit 0
