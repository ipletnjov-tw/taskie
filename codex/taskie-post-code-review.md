---
description: Apply code review feedback
argument-hint: [additional instructions]
---

**IMPORTANT:** Before proceeding, read and internalize all ground rules from `~/.codex/prompts/taskie-ground-rules.md`. You MUST follow these ground rules at ALL times throughout this task.


# Implement Post-Review Fixes

Address the issues surfaced by the latest code review in `.taskie/plans/{current-plan-dir}/task-{current-task-id}-review-{latest-review-id}.md`

If you don't know what the `{current-plan-dir}`, `{current-task-id}` or `{latest-review-id}` are, use git history to find out which plan, task and review file was modified most recently.

After you're done with your changes, document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{next-task-id}.md` and update the status and git commit hash of the subtask(s). Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`.

Do NOT forget to push your changes to remote.

$ARGUMENTS
