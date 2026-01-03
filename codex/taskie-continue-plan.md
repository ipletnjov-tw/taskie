---
description: Continue an existing implementation plan
argument-hint: [additional instructions]
---

**IMPORTANT:** Before proceeding, read and internalize all ground rules from `~/.codex/prompts/taskie-ground-rules.md`. You MUST follow these ground rules at ALL times throughout this task.

# Continue Existing Implementation Plan

You will need to continue an existing implementation plan. The plan, task list, design document and task files are in the `.taskie/plans/{current-plan-dir}` directory.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Figure out where you left off and continue from there: find the last changed task(s) from the task list, check the subtasks and reviews for each task. You may also use git history for more information.

Determine the next appropriate action based on the current state:

- **If the task is in-progress**: Continue implementing the task.
  - Document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{current-task-id}.md`
  - Update the status and git commit hash of the subtask(s)
  - Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`

- **If the task is completed but pending review**: Perform a code review.
  - Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering and other cruft
  - Don't let ANYTHING slip, write down even the most minor issues
  - Review ALL code that was created, changed or deleted as part of the task, NOT just the latest fixes
  - Double check ALL the must-run commands by running them and analyzing their results
  - Document the results in `.taskie/plans/{current-plan-dir}/task-{current-task-id}-review-{review-id}.md`
  - Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`

- **If the task's latest review is positive**: Start the next task.
  - Proceed to the next pending task in the implementation plan
  - Implement ONLY ONE task, including ALL of the task's subtasks
  - Run all must-run commands for EVERY subtask to verify completion
  - Document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{next-task-id}.md`
  - Update the status and git commit hash of the subtask(s)
  - Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`

- **If the task's latest review is negative**: Address review feedback.
  - Fix all identified issues from the latest review file `.taskie/plans/{current-plan-dir}/task-{current-task-id}-review-{latest-review-id}.md`
  - Document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{current-task-id}.md`
  - Update the status and git commit hash of the subtask(s)
  - Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`

Remember, you MUST follow the ground rules at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
