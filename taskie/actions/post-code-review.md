# Implement Post-Review Fixes

Address the issues surfaced by the latest code review in `.llm/plans/{current-plan-dir}/task-{current-task-id}-review-{latest-review-id}.md`

If you don't know what the `{current-plan-dir}`, `{current-task-id}` or `{latest-review-id}` are, use git history to find out which plan, task and review file was modified most recently.

After you're done with your changes, document your progress with a short summary in `.llm/plans/{current-plan-dir}/task-{next-task-id}.md` and update the status and git commit hash of the subtask(s). Update the task status in `.llm/plans/{current-plan-dir}/tasks.md`.

Remember, you MUST follow the `ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
