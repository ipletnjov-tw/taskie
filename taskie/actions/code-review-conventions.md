# Perform Task Code Review (Conventions Focus)

Perform a thorough review of the current task implementation and latest changes. Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering and other cruft. Don't let ANYTHING slip, write down even the most minor issues. You MUST review ALL code that was created, changed or deleted as part of the task, NOT just the latest fixes.

In this review, focus on whether the code follows existing project conventions. Are we accidentally breaking patterns and introducing code constructs (Service classes, DTOs, etc) that look completely different from existing constructs in the codebase? Are we adding too many verbose comments and JavaDoc blocks? Are we violating the existing layered architecture of the codebase? Are we following the instructions and conventions documented in the CLAUDE.md?

Double check ALL the must-run commands by running them and analyzing their results.

Document the results of your review in `.taskie/plans/{current-plan-dir}/task-{current-task-id}-review-{review-id}.md` and update the task status in `.taskie/plans/{current-plan-dir}/tasks.md` too. If you don't know what the `{current-plan-dir}` or `{current-task-id}` are, use git history to find out which plan and task was modified most recently.

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
