# Implement Post-Review Fixes

Address the issues surfaced by the latest code review in `.taskie/plans/{current-plan-dir}/task-{current-task-id}-review-{latest-review-id}.md`

If you don't know what the `{current-plan-dir}`, `{current-task-id}` or `{latest-review-id}` are, use git history to find out which plan, task and review file was modified most recently.

After you're done with your changes, create `.taskie/plans/{current-plan-dir}/task-{current-task-id}-post-review-{latest-review-id}.md` documenting:
- Summary of issues addressed from the review
- Changes made to fix each issue
- Update the status and git commit hash of the subtask(s)
- Any relevant notes or decisions made

Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`.

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
