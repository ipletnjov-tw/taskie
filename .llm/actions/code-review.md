# Perform Task Code Review

Perform a thorough review of the current task implementation and latest changes. Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering and other cruft. Don't let ANYTHING slip, write down even the most minor issues.

Double check the must-run actions. Document the results of your review in `.llm/plans/{current-plan-dir}/task-{current-task-id}-review-{review-id}.md` and update the task status in `.llm/plans/{current-plan-dir}/tasks.md` too.

If you don't know what the `{current-plan-dir}` or `{current-task-id}` are, use git history to find out which plan and task was modified most recently. 

Remember, you MUST follow the `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.