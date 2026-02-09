# Implement Post-Review Fixes

Address the issues surfaced by the latest code review in `.taskie/plans/{current-plan-dir}/task-{current-task-id}-code-review-{iteration}.md`. The review file name follows the pattern `task-{task-id}-code-review-{iteration}.md` where iteration comes from `phase_iteration` in state.json for automated reviews.

If you don't know what the `{current-plan-dir}`, `{current-task-id}`, or `{iteration}` are, use git history to find out which plan and review file was modified most recently.

After you're done with your changes, create `.taskie/plans/{current-plan-dir}/task-{current-task-id}-code-post-review-{iteration}.md` documenting:
- Summary of issues addressed from the review
- Changes made to fix each issue
- Update the status and git commit hash of the subtask(s)
- Any relevant notes or decisions made

Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`.

**IMPORTANT: Do NOT update state.json manually.** The stop hook automatically detects when you create the post-review file and manages all state transitions. Just create the post-review file and stop.

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
