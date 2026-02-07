# Implement Post-Review Fixes

Address the issues surfaced by the latest code review in `.taskie/plans/{current-plan-dir}/task-{current-task-id}-review-{latest-review-id}.md`

If you don't know what the `{current-plan-dir}`, `{current-task-id}` or `{latest-review-id}` are, use git history to find out which plan, task and review file was modified most recently.

After you're done with your changes, create `.taskie/plans/{current-plan-dir}/task-{current-task-id}-post-review-{latest-review-id}.md` documenting:
- Summary of issues addressed from the review
- Changes made to fix each issue
- Update the status and git commit hash of the subtask(s)
- Any relevant notes or decisions made

Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`.

After implementing fixes, check the workflow context to determine how to update state:

1. Read `.taskie/plans/{current-plan-dir}/state.json`
2. Check the `phase_iteration` field:
   - **If `phase_iteration` is non-null (a number)**: This is AUTOMATED mode (part of a review cycle)
     - Update `state.json` with:
       - `phase`: `"post-code-review"`
       - `next_phase`: `"code-review"` (return to review for another iteration)
       - Preserve all other fields: `phase_iteration`, `max_reviews`, `review_model`, `consecutive_clean`, `current_task`, `tdd`
     - Write atomically (temp file + mv)
   - **If `phase_iteration` is null or doesn't exist**: This is STANDALONE mode (manual invocation)
     - Update `state.json` with:
       - `phase`: `"post-code-review"`
       - `next_phase`: `null` (standalone, no automation)
       - Preserve all other fields
     - Write atomically (temp file + mv)

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
