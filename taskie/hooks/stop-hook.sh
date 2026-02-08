#!/bin/bash
# Taskie Unified Stop Hook
# Validates project structure and triggers automated reviews

set -euo pipefail

# Logging - each invocation gets its own file under .taskie/logs/
HOOK_LOG=""
log() {
    [ -n "$HOOK_LOG" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$HOOK_LOG" 2>/dev/null || true
}

# Check for required dependencies
log "Checking jq dependency"
if ! command -v jq &> /dev/null; then
    log "jq MISSING"
    echo "Error: jq is required but not installed. Install it with: apt-get install jq" >&2
    exit 2
fi
log "jq found"

# Resolve plugin root relative to hook location
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Read hook input from stdin
EVENT=$(cat)

# Validate JSON input
log "Parsing event JSON"
if ! echo "$EVENT" | jq empty 2>/dev/null; then
    log "Parse FAILED: invalid JSON input"
    echo "Error: Invalid JSON input from hook event" >&2
    exit 2
fi
log "Parse OK"

STOP_HOOK_ACTIVE=$(echo "$EVENT" | jq -r '.stop_hook_active // false')

# Prevent infinite loops - always approve if already in continuation
log "Checking stop_hook_active"
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    log "stop_hook_active=true -> approving (loop prevention)"
    echo '{"suppressOutput": true}'
    exit 0
fi
log "stop_hook_active=$STOP_HOOK_ACTIVE"

# Get project directory
CWD=$(echo "$EVENT" | jq -r '.cwd // "."')

# Change to project directory with error handling
log "Changing to CWD: $CWD"
if ! cd "$CWD" 2>/dev/null; then
    log "CWD FAILED: cannot change to $CWD"
    echo "Error: Cannot change to project directory: $CWD" >&2
    exit 2
fi
log "CWD=$CWD OK"

# Check if .taskie directory exists (skip validation if not using Taskie)
log "Checking .taskie/plans exists"
if [ ! -d ".taskie/plans" ]; then
    log "Not found, approving (non-Taskie project)"
    echo '{"suppressOutput": true}'
    exit 0
fi
log ".taskie/plans found"

# Initialize logging now that we know .taskie exists
mkdir -p .taskie/logs
HOOK_LOG=".taskie/logs/hook-$(date '+%Y-%m-%dT%H-%M-%S').log"
log "=== Hook invocation ==="
log "EVENT: $EVENT"
log "CWD: $CWD"
log "stop_hook_active: $STOP_HOOK_ACTIVE"

# Find the most recently modified plan directory by file timestamp (portable: works on Linux/macOS/BSD)
# Include both .md and state.json files in modification time consideration
log "Finding most recent plan"
RECENT_PLAN=$(find .taskie/plans -mindepth 2 -maxdepth 2 -type f \( -name "*.md" -o -name "state.json" \) -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1 | sed 's|\(\.taskie/plans/[^/]*\)/.*|\1|')

# If no plan files found, approve
if [ -z "$RECENT_PLAN" ]; then
    log "No plans found, approving"
    echo '{"suppressOutput": true}'
    exit 0
fi
log "RECENT_PLAN=$RECENT_PLAN"

# Step 5: Auto-review logic
STATE_FILE="$RECENT_PLAN/state.json"
PLAN_ID=$(basename "$RECENT_PLAN")
log "PLAN_ID=$PLAN_ID, STATE_FILE=$STATE_FILE"

# Step 5a: Read state.json if it exists
log "Checking state.json"
if [ -f "$STATE_FILE" ]; then
    log "state.json found at $STATE_FILE"
    # Validate JSON syntax
    log "Parsing state.json"
    if ! jq empty "$STATE_FILE" 2>/dev/null; then
        log "state.json invalid JSON, falling through to validation"
        echo "Warning: state.json contains invalid JSON, falling back to validation" >&2
    else
        log "state.json valid JSON"
        # Read all state fields with default operators for forward compatibility
        log "Reading state fields"
        MAX_REVIEWS=$(jq -r '(.max_reviews // 8)' "$STATE_FILE" 2>/dev/null)
        CURRENT_TASK=$(jq -r '(.current_task // null)' "$STATE_FILE" 2>/dev/null)
        PHASE=$(jq -r '(.phase // "")' "$STATE_FILE" 2>/dev/null)
        PHASE_ITERATION=$(jq -r '.phase_iteration' "$STATE_FILE" 2>/dev/null)
        NEXT_PHASE=$(jq -r '(.next_phase // "")' "$STATE_FILE" 2>/dev/null)
        REVIEW_MODEL=$(jq -r '(.review_model // "opus")' "$STATE_FILE" 2>/dev/null)
        CONSECUTIVE_CLEAN=$(jq -r '(.consecutive_clean // 0)' "$STATE_FILE" 2>/dev/null)
        TDD=$(jq -r '(.tdd // false)' "$STATE_FILE" 2>/dev/null)
        log "phase=$PHASE next_phase=$NEXT_PHASE max_reviews=$MAX_REVIEWS current_task=$CURRENT_TASK phase_iteration=$PHASE_ITERATION review_model=$REVIEW_MODEL consecutive_clean=$CONSECUTIVE_CLEAN tdd=$TDD"

        # Check if next_phase is a review phase
        log "Checking if next_phase is review"
        if [[ "$NEXT_PHASE" =~ ^(plan-review|tasks-review|code-review|all-code-review)$ ]]; then
            # Extract review type from next_phase
            REVIEW_TYPE="$NEXT_PHASE"
            log "YES: next_phase=$NEXT_PHASE is review, REVIEW_TYPE=$REVIEW_TYPE"

            # Step 5a: Check max_reviews == 0 (skip reviews) - validate numeric first
            log "Validating max_reviews is numeric"
            if [ "$MAX_REVIEWS" -eq "$MAX_REVIEWS" ] 2>/dev/null && [ "$MAX_REVIEWS" -eq 0 ]; then
                log "max_reviews=0: entering skip-review path"
                # Determine advance target based on review type
                log "Determining advance target for $REVIEW_TYPE"
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
                        # Check if more tasks remain (guard against missing tasks.md)
                        if [ -f "$RECENT_PLAN/tasks.md" ]; then
                            TASKS_REMAIN=$(grep '^|' "$RECENT_PLAN/tasks.md" 2>/dev/null | tail -n +3 | awk -F'|' -v cur="$CURRENT_TASK" '{gsub(/[[:space:]]/, "", $2); if ($2 != cur) print $3}' | grep -i 'pending' | wc -l)
                        else
                            TASKS_REMAIN=0
                        fi
                        log "TASKS_REMAIN=$TASKS_REMAIN"
                        if [ "$TASKS_REMAIN" -gt 0 ]; then
                            if [ "$TDD" = "true" ]; then
                                ADVANCE_TARGET="complete-task-tdd"
                            else
                                ADVANCE_TARGET="complete-task"
                            fi
                        else
                            ADVANCE_TARGET="all-code-review"
                            # Reset for fresh all-code-review cycle
                            RESET_FOR_ALL_CODE_REVIEW=true
                        fi
                        ;;
                    all-code-review)
                        ADVANCE_TARGET="complete"
                        ;;
                esac
                log "ADVANCE_TARGET=$ADVANCE_TARGET, RESET_FOR_ALL_CODE_REVIEW=${RESET_FOR_ALL_CODE_REVIEW:-false}"

                # Write state atomically with phase set to review type and next_phase to advance target
                log "Writing state (max_reviews=0 path)"
                TEMP_STATE=$(mktemp "${STATE_FILE}.XXXXXX")
                if [ "${RESET_FOR_ALL_CODE_REVIEW:-false}" = "true" ]; then
                    # Reset review_model and consecutive_clean for fresh all-code-review cycle
                    jq --arg phase "$REVIEW_TYPE" \
                       --arg next_phase "$ADVANCE_TARGET" \
                       --argjson phase_iteration 0 \
                       --arg review_model "opus" \
                       --argjson consecutive_clean 0 \
                       '.phase = $phase | .next_phase = $next_phase | .phase_iteration = $phase_iteration | .review_model = $review_model | .consecutive_clean = $consecutive_clean' \
                       "$STATE_FILE" > "$TEMP_STATE"
                else
                    jq --arg phase "$REVIEW_TYPE" \
                       --arg next_phase "$ADVANCE_TARGET" \
                       --argjson phase_iteration 0 \
                       '.phase = $phase | .next_phase = $next_phase | .phase_iteration = $phase_iteration' \
                       "$STATE_FILE" > "$TEMP_STATE"
                fi
                mv "$TEMP_STATE" "$STATE_FILE"
                log "State written: phase=$REVIEW_TYPE next_phase=$ADVANCE_TARGET"

                log "Exiting: max_reviews=0 auto-advance to $ADVANCE_TARGET"
                echo "{\"systemMessage\": \"Reviews disabled (max_reviews=0). Auto-advanced to $ADVANCE_TARGET. Run /taskie:continue-plan to proceed.\", \"suppressOutput\": true}"
                exit 0
            fi
            log "max_reviews=$MAX_REVIEWS (numeric check passed, not zero)"

            # Step 5b: Increment phase_iteration (standalone mode uses null, not 0)
            log "Calculating phase_iteration (was $PHASE_ITERATION)"
            if [ "$PHASE_ITERATION" = "null" ] || [ -z "$PHASE_ITERATION" ]; then
                PHASE_ITERATION=1
            else
                PHASE_ITERATION=$((PHASE_ITERATION + 1))
            fi
            log "phase_iteration=$PHASE_ITERATION"

            # Step 5c: Check if max_reviews exceeded (hard stop) - validate numeric first
            log "Checking phase_iteration($PHASE_ITERATION) > max_reviews($MAX_REVIEWS)"
            if [ "$MAX_REVIEWS" -eq "$MAX_REVIEWS" ] 2>/dev/null && [ "$PHASE_ITERATION" -gt "$MAX_REVIEWS" ]; then
                log "Exceeded: hard stop (phase_iteration=$PHASE_ITERATION > max_reviews=$MAX_REVIEWS)"
                echo "{\"systemMessage\": \"Max review limit ($MAX_REVIEWS) reached for $REVIEW_TYPE. Edit state.json to adjust max_reviews or set next_phase manually.\", \"suppressOutput\": true}"
                exit 0
            fi
            log "Within limit: continuing (phase_iteration=$PHASE_ITERATION <= max_reviews=$MAX_REVIEWS)"

            # Step 5d: Prepare for CLI invocation
            REVIEW_FILE="$RECENT_PLAN/${REVIEW_TYPE}-${PHASE_ITERATION}.md"
            LOG_FILE="$RECENT_PLAN/.review-${PHASE_ITERATION}.log"
            log "REVIEW_FILE=$REVIEW_FILE, LOG_FILE=$LOG_FILE"

            # Build task file list for tasks-review and all-code-review
            TASK_FILE_LIST=""
            if [[ "$REVIEW_TYPE" = "tasks-review" || "$REVIEW_TYPE" = "all-code-review" ]]; then
                log "Building task file list for $REVIEW_TYPE"
                if [ -f "$RECENT_PLAN/tasks.md" ]; then
                    # Build list and verify each file exists
                    RAW_LIST=$(grep '^|' "$RECENT_PLAN/tasks.md" | tail -n +3 | awk -F'|' -v plan="$PLAN_ID" '{gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9]+$/) printf ".taskie/plans/%s/task-%s.md ", plan, $2}')
                    for task_file in $RAW_LIST; do
                        if [ -f "$task_file" ]; then
                            TASK_FILE_LIST="$TASK_FILE_LIST $task_file"
                        fi
                    done
                    TASK_FILE_LIST=$(echo "$TASK_FILE_LIST" | xargs)  # Trim whitespace
                fi
                log "TASK_FILE_LIST=[$TASK_FILE_LIST] (count=$(echo "$TASK_FILE_LIST" | wc -w | xargs))"
                # Check for empty list
                if [ -z "$TASK_FILE_LIST" ]; then
                    log "Task file list empty: skipping review"
                    echo "Warning: No task files found for $REVIEW_TYPE, skipping review" >&2
                    echo '{"systemMessage": "No task files found, skipping review", "suppressOutput": true}'
                    exit 0
                fi
            fi

            # For code-review, check if task file exists
            if [ "$REVIEW_TYPE" = "code-review" ]; then
                TASK_FILE="$RECENT_PLAN/task-${CURRENT_TASK}.md"
                log "Checking task-${CURRENT_TASK}.md exists"
                if [ ! -f "$TASK_FILE" ]; then
                    log "Missing: task-${CURRENT_TASK}.md not found, skipping review"
                    echo "Warning: Task file task-${CURRENT_TASK}.md not found, skipping review" >&2
                    echo '{"systemMessage": "Task file not found, skipping review", "suppressOutput": true}'
                    exit 0
                fi
                log "Found: $TASK_FILE"
            fi

            # Build prompt based on review type
            log "Building prompt for $REVIEW_TYPE"
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
            log "PROMPT=${PROMPT:0:100}... FILES=$FILES_TO_REVIEW"

            # Invoke claude CLI
            CLI_OUTPUT=""
            log "Checking claude CLI available"
            if command -v claude &> /dev/null; then
                log "claude CLI found"
                log "Invoking: claude --model $REVIEW_MODEL --output-format json --dangerously-skip-permissions"
                set +e
                CLI_OUTPUT=$(claude --print \
                    --model "$REVIEW_MODEL" \
                    --output-format json \
                    --json-schema '{"type":"object","properties":{"verdict":{"type":"string","enum":["PASS","FAIL"]}},"required":["verdict"]}' \
                    --dangerously-skip-permissions \
                    "$PROMPT" 2>"$LOG_FILE")
                CLI_EXIT=$?
                set -e
                log "CLI exit=$CLI_EXIT, output_length=${#CLI_OUTPUT}, review_file_exists=$([ -f "$REVIEW_FILE" ] && echo true || echo false)"
                # Log last 50 lines of CLI output
                log "CLI_OUTPUT (last 50 lines):"
                echo "$CLI_OUTPUT" | tail -50 | while IFS= read -r line; do
                    log "  $line"
                done

                # Step 5e: Verify review file was written
                log "Checking review file written"
                if [ $CLI_EXIT -eq 0 ] && [ -f "$REVIEW_FILE" ]; then
                    log "YES: $REVIEW_FILE exists"
                    # Success - clean up log file
                    rm -f "$LOG_FILE"

                    # Step 5f: Extract verdict from CLI output
                    log "Extracting verdict from CLI output"
                    VERDICT=$(echo "$CLI_OUTPUT" | jq -r '.result.verdict' 2>/dev/null || echo "")
                    log "VERDICT=$VERDICT"

                    # Update consecutive_clean based on verdict
                    log "Updating consecutive_clean (was $CONSECUTIVE_CLEAN)"
                    if [ "$VERDICT" = "PASS" ]; then
                        CONSECUTIVE_CLEAN=$((CONSECUTIVE_CLEAN + 1))
                    else
                        # FAIL or parse error
                        CONSECUTIVE_CLEAN=0
                    fi
                    log "consecutive_clean=$CONSECUTIVE_CLEAN (verdict=$VERDICT)"

                    # Step 5g: Check for auto-advance (consecutive_clean >= 2)
                    log "Checking auto-advance: consecutive_clean=$CONSECUTIVE_CLEAN >= 2?"
                    if [ "$CONSECUTIVE_CLEAN" -ge 2 ]; then
                        log "YES: determining advance target"
                        # Determine advance target based on review type
                        log "Auto-advance target for $REVIEW_TYPE"
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
                                # Check if more tasks remain (handle missing tasks.md gracefully)
                                if [ -f "$RECENT_PLAN/tasks.md" ]; then
                                    TASKS_REMAIN=$(grep '^|' "$RECENT_PLAN/tasks.md" 2>/dev/null | tail -n +3 | awk -F'|' -v cur="$CURRENT_TASK" '{gsub(/[[:space:]]/, "", $2); if ($2 != cur) print $3}' | grep -i 'pending' 2>/dev/null | wc -l || echo 0)
                                else
                                    TASKS_REMAIN=0
                                fi
                                log "Counting remaining tasks for advance: TASKS_REMAIN=$TASKS_REMAIN"
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
                        log "ADVANCE_TARGET=$ADVANCE_TARGET"

                        # Write state atomically for auto-advance
                        log "Writing state (auto-advance)"
                        TEMP_STATE=$(mktemp "${STATE_FILE}.XXXXXX")
                        # Handle current_task as number or null (not string)
                        if [ "$CURRENT_TASK" = "null" ] || [ -z "$CURRENT_TASK" ]; then
                            CURRENT_TASK_JSON="null"
                        else
                            CURRENT_TASK_JSON="$CURRENT_TASK"
                        fi
                        jq --arg phase "$REVIEW_TYPE" \
                           --arg next_phase "$ADVANCE_TARGET" \
                           --argjson phase_iteration "$PHASE_ITERATION" \
                           --arg review_model "$REVIEW_MODEL" \
                           --argjson consecutive_clean "$CONSECUTIVE_CLEAN" \
                           --argjson max_reviews "$MAX_REVIEWS" \
                           --argjson current_task "$CURRENT_TASK_JSON" \
                           --argjson tdd "$TDD" \
                           '.phase = $phase | .next_phase = $next_phase | .phase_iteration = $phase_iteration | .review_model = $review_model | .consecutive_clean = $consecutive_clean | .max_reviews = $max_reviews | .current_task = $current_task | .tdd = $tdd' \
                           "$STATE_FILE" > "$TEMP_STATE"
                        mv "$TEMP_STATE" "$STATE_FILE"
                        log "State written: phase=$REVIEW_TYPE next_phase=$ADVANCE_TARGET cc=$CONSECUTIVE_CLEAN"

                        # Approve with message
                        log "Exiting: auto-advance to $ADVANCE_TARGET"
                        echo "{\"systemMessage\": \"${REVIEW_TYPE} passed. Run /taskie:continue-plan to proceed.\", \"suppressOutput\": true}"
                        exit 0
                    fi
                    log "NO: consecutive_clean=$CONSECUTIVE_CLEAN < 2, will block"

                    # Step 5h: Non-advance - update state and block
                    # Toggle review model
                    log "Toggling review model (was $REVIEW_MODEL)"
                    if [ "$REVIEW_MODEL" = "opus" ]; then
                        NEW_REVIEW_MODEL="sonnet"
                    else
                        NEW_REVIEW_MODEL="opus"
                    fi
                    log "NEW_REVIEW_MODEL=$NEW_REVIEW_MODEL"

                    # Determine post-review phase
                    POST_REVIEW_PHASE="post-${REVIEW_TYPE}"

                    # Write state atomically
                    log "Writing state (block path)"
                    TEMP_STATE=$(mktemp "${STATE_FILE}.XXXXXX")
                    # Handle current_task as number or null (not string)
                    if [ "$CURRENT_TASK" = "null" ] || [ -z "$CURRENT_TASK" ]; then
                        CURRENT_TASK_JSON="null"
                    else
                        CURRENT_TASK_JSON="$CURRENT_TASK"
                    fi
                    jq --arg phase "$REVIEW_TYPE" \
                       --arg next_phase "$POST_REVIEW_PHASE" \
                       --argjson phase_iteration "$PHASE_ITERATION" \
                       --arg review_model "$NEW_REVIEW_MODEL" \
                       --argjson consecutive_clean "$CONSECUTIVE_CLEAN" \
                       --argjson max_reviews "$MAX_REVIEWS" \
                       --argjson current_task "$CURRENT_TASK_JSON" \
                       --argjson tdd "$TDD" \
                       '.phase = $phase | .next_phase = $next_phase | .phase_iteration = $phase_iteration | .review_model = $review_model | .consecutive_clean = $consecutive_clean | .max_reviews = $max_reviews | .current_task = $current_task | .tdd = $tdd' \
                       "$STATE_FILE" > "$TEMP_STATE"
                    mv "$TEMP_STATE" "$STATE_FILE"
                    log "State written: phase=$REVIEW_TYPE next_phase=$POST_REVIEW_PHASE model=$NEW_REVIEW_MODEL cc=$CONSECUTIVE_CLEAN iter=$PHASE_ITERATION"

                    # Return block decision with template (message depends on verdict)
                    if [ "$VERDICT" = "PASS" ]; then
                        BLOCK_REASON="Review passed (need 2 consecutive for auto-advance). See ${REVIEW_FILE}. Run /taskie:${POST_REVIEW_PHASE} to continue. Escape hatch: update state.json using 'jq ... state.json > temp.json && mv temp.json state.json' to set next_phase manually."
                    else
                        BLOCK_REASON="Review found issues. See ${REVIEW_FILE}. Run /taskie:${POST_REVIEW_PHASE} to address them. Escape hatch: update state.json using 'jq ... state.json > temp.json && mv temp.json state.json' to set next_phase manually."
                    fi

                    log "DECISION: block"
                    log "reason=$BLOCK_REASON"
                    jq -n --arg reason "$BLOCK_REASON" '{
                        "decision": "block",
                        "reason": $reason
                    }'
                    log "Final exit: code=0 decision=block"
                    exit 0
                else
                    # CLI failed or review file missing
                    log "CLI failed or review not written: exit=$CLI_EXIT, review_exists=$([ -f "$REVIEW_FILE" ] && echo true || echo false)"
                    echo "Warning: Review failed (exit $CLI_EXIT) or review file not written" >&2
                    echo '{"systemMessage": "Review failed, proceeding without review", "suppressOutput": true}'
                    log "Final exit: code=0 decision=approve (review failed)"
                    exit 0
                fi
            else
                log "claude CLI NOT FOUND: skipping review"
                echo "Warning: claude CLI not found, skipping review" >&2
                echo '{"systemMessage": "claude CLI not available, skipping review", "suppressOutput": true}'
                log "Final exit: code=0 decision=approve (no CLI)"
                exit 0
            fi
        else
            log "NO: next_phase=$NEXT_PHASE is not a review phase, falling through to validation"
        fi
    fi
else
    log "state.json not found, falling through to validation"
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
           [[ ! "$filename" =~ ^code-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^all-code-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^task-[a-zA-Z0-9_-]+-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^(plan|design|tasks)-post-review-[0-9]+\.md$ ]] && \
           [[ ! "$filename" =~ ^code-post-review-[0-9]+\.md$ ]] && \
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

    # Rule 7: code-review-*.md files require at least one task file
    if ls "$plan_dir"/code-review-[0-9]*.md 2>/dev/null | grep -q .; then
        if ! ls "$plan_dir"/task-*.md 2>/dev/null | grep -v "review" | grep -q .; then
            add_error "code-review files exist but no task files found"
        fi
    fi

    # Rule 8: tasks.md must contain ONLY a markdown table
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
        else
            # Check for at least one data row (header + separator + data = 3 rows minimum)
            local row_count=$(grep "^|" "$plan_dir/tasks.md" | wc -l)
            if [ "$row_count" -lt 3 ]; then
                add_error "tasks.md has no task rows (header-only table)"
            fi
        fi
    fi

    # Rule 8: state.json validation (if exists)
    if [ -f "$plan_dir/state.json" ]; then
        # Validate JSON syntax
        if ! jq empty "$plan_dir/state.json" 2>/dev/null; then
            echo "Warning: state.json contains invalid JSON" >&2
        else
            # Validate required fields exist (null is a valid value for next_phase, current_task, phase_iteration)
            local missing_fields=""
            jq -r 'has("phase")' "$plan_dir/state.json" 2>/dev/null | grep -q "true" || missing_fields="${missing_fields}phase "
            jq -r 'has("next_phase")' "$plan_dir/state.json" 2>/dev/null | grep -q "true" || missing_fields="${missing_fields}next_phase "
            jq -r 'has("review_model")' "$plan_dir/state.json" 2>/dev/null | grep -q "true" || missing_fields="${missing_fields}review_model "
            jq -r 'has("max_reviews")' "$plan_dir/state.json" 2>/dev/null | grep -q "true" || missing_fields="${missing_fields}max_reviews "
            jq -r 'has("consecutive_clean")' "$plan_dir/state.json" 2>/dev/null | grep -q "true" || missing_fields="${missing_fields}consecutive_clean "
            jq -r 'has("tdd")' "$plan_dir/state.json" 2>/dev/null | grep -q "true" || missing_fields="${missing_fields}tdd "
            jq -r 'has("current_task")' "$plan_dir/state.json" 2>/dev/null | grep -q "true" || missing_fields="${missing_fields}current_task "
            jq -r 'has("phase_iteration")' "$plan_dir/state.json" 2>/dev/null | grep -q "true" || missing_fields="${missing_fields}phase_iteration "

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
log "Running validation on $RECENT_PLAN"
set +e
# Capture only stdout (errors), let stderr (warnings) pass through
PLAN_ERROR=$(validate_plan_structure "$RECENT_PLAN")
PLAN_RESULT=$?
set -e

if [ $PLAN_RESULT -eq 0 ]; then
    log "Validation PASS"
    log "Final exit: code=0 decision=approve"
    echo "{\"systemMessage\": \"Plan '$PLAN_NAME' structure validated successfully\", \"suppressOutput\": true}"
else
    log "Validation FAIL: $PLAN_ERROR"
    log "Final exit: code=0 decision=block"
    jq -n --arg reason "Plan '$PLAN_NAME': $PLAN_ERROR" '{
        "decision": "block",
        "reason": $reason
    }'
fi
exit 0
