---
description: Start implementing the next task
argument-hint: [additional instructions]
---

# Start Next Task Implementation

Proceed to the next task in the implementation plan. You MUST implement ONLY ONE task, including ALL of the task's subtasks. You MUST NOT implement more than ONE task. You MUST run all must-run commands for EVERY subtask to verify completion.

After you're done, document your progress with a short summary in `.llm/plans/{current-plan-dir}/task-{next-task-id}.md` and update the status and git commit hash of the subtask(s). Update the task status in `.llm/plans/{current-plan-dir}/tasks.md`.

If you don't know what the `{current-plan-dir}` or `{next-task-id}` are, use git history to find out which plan and task was modified most recently.

Remember, you MUST follow the `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
