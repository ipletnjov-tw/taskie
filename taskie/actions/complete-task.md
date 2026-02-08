# Complete Task with Automated Review Cycle

Execute full task completion with automated review: implementation → automated code review loop → completion.

You MUST follow `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times.

## Step 1: Select next task

Read `.taskie/plans/{current-plan-dir}/tasks.md` and identify the first task with status "pending". This is the task you will implement.

**If no pending tasks exist**: Inform the user that all tasks are complete. Set `phase: "complete"` and `next_phase: null` in state.json, then stop. Do not attempt to implement a non-existent task.

If you don't know the `{current-plan-dir}`, use git history to find the most recently modified plan.

## Step 2: Implement the task

Implement the selected task, including ALL of its subtasks. You MUST NOT implement more than ONE task. You MUST run all must-run commands for EVERY subtask to verify completion.

1. Read the task file `.taskie/plans/{current-plan-dir}/task-{task-id}.md` to understand the task requirements and subtasks
2. Implement each subtask according to its acceptance criteria
3. Run all must-run commands specified in each subtask
4. Document your progress with a short summary in the task file
5. Update the status and git commit hash of each subtask
6. Update the task status in `tasks.md` to "done"
7. Commit your changes with an appropriate commit message
8. Push to remote

## Step 3: Initialize automated review cycle

After completing implementation, you MUST update the workflow state file at `.taskie/plans/{current-plan-dir}/state.json`:

1. Read the existing `state.json` file to preserve `max_reviews`
2. Update the state with the following fields:
   - `phase`: `"complete-task"`
   - `current_task`: `"{task-id}"` (the task ID you just implemented)
   - `next_phase`: `"code-review"` (trigger automated code review)
   - `phase_iteration`: `0` (start fresh review cycle)
   - `review_model`: `"opus"` (reset to default for new cycle)
   - `consecutive_clean`: `0` (reset counter for new cycle)
   - `tdd`: `false` (this is the non-TDD variant)
   - `max_reviews`: preserve from existing state
3. Write the updated state atomically using a temp file: write to a temporary file first, then `mv` to `state.json`

Example bash command for atomic write. In this example, task ID is "3" - replace with your actual task ID:
```bash
TASK_ID="3"  # Replace with actual task ID from Step 1
TEMP_STATE=$(mktemp)
MAX_REVIEWS=$(jq -r '.max_reviews // 8' state.json)
jq --arg phase "complete-task" \
   --arg current_task "$TASK_ID" \
   --arg next_phase "code-review" \
   --argjson phase_iteration 0 \
   --arg review_model "opus" \
   --argjson consecutive_clean 0 \
   --argjson tdd false \
   --argjson max_reviews "$MAX_REVIEWS" \
   '.phase = $phase | .current_task = $current_task | .next_phase = $next_phase | .phase_iteration = $phase_iteration | .review_model = $review_model | .consecutive_clean = $consecutive_clean | .tdd = $tdd | .max_reviews = $max_reviews' \
   state.json > "$TEMP_STATE"
mv "$TEMP_STATE" state.json
```

## Step 4: Stop and let automation take over

After writing `state.json`, STOP. The automated review cycle will begin when you stop:

1. The hook will trigger `code-review` automatically
2. Reviews will alternate between opus and sonnet models
3. If reviews pass (2 consecutive clean reviews), the workflow auto-advances to the next task
4. If reviews fail, you'll be prompted to execute `post-code-review` to fix issues
5. The review cycle continues until quality standards are met or max_reviews is reached

To escape the automated cycle at any point, set `next_phase: null` in `state.json`.

Do NOT forget to push your changes to remote.
