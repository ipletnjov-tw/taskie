# Continue Existing Implementation Plan

You will need to continue an existing implementation plan. The plan, task list, design document and task files are in the `.llm/plans/{current-plan-dir}` directory.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Carefully read the `ground-rules.md` for extra context & further instructions. Figure out where you left off and continue from there: find the last changed task(s) from the task list, check the subtasks and reviews for each task. You may also use git history for more information.

If the task is in-progress, execute action `.llm/actions/continue-task.md`.

If the task is completed but pending review, execute action `.llm/actions/code-review.md`.

If the task's latest review is positive, execute action `.llm/actions/next-task.md`.

If the task's latest review is negative, execute action `.llm/actions/post-code-review.md`.

Remember, you MUST follow the `ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
