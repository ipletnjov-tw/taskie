# Continue Task Implementation

You will need to continue working on a task in the implementation plan. 

After you're done implementing it, document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{next-task-id}.md` and update the status and git commit hash of the subtask(s). Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`.

After making progress, you MUST update the workflow state file at `.taskie/plans/{current-plan-dir}/state.json`:

1. Read the existing `state.json` file
2. Update ONLY the `phase` field:
   - `phase`: `"continue-task"`
   - **IMPORTANT**: Preserve `next_phase` from the existing state (do NOT change it)
   - Preserve all other fields unchanged: `current_task`, `phase_iteration`, `max_reviews`, `review_model`, `consecutive_clean`, `tdd`
3. Write the updated state atomically using a temp file: write to a temporary file first, then `mv` to `state.json`

This action is transparent - it preserves the workflow state. Whether you're in an automated review cycle (`next_phase` is a review phase) or standalone mode (`next_phase` is null), the state remains unchanged except for marking that you continued the task.

If you don't know what the `{current-plan-dir}` or `{current-task-id}` are, use git history to find out which plan and task was modified most recently.

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
