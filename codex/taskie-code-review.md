---
description: Critically review implemented code
argument-hint: [additional instructions]
---

**IMPORTANT:** Before proceeding, read and internalize all ground rules from `~/.codex/prompts/taskie-ground-rules.md`. You MUST follow these ground rules at ALL times throughout this task.

# Perform Task Code Review

Perform a thorough review of the current task implementation and latest changes. Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering and other cruft. Don't let ANYTHING slip, write down even the most minor issues. You MUST review ALL code that was created, changed or deleted as part of the task, NOT just the latest fixes.

Double check ALL the must-run commands by running them and analyzing their results.

**Your review must be a clean slate. Do not look at any prior review files.**

Document the results of your review in `.taskie/plans/{current-plan-dir}/task-{current-task-id}-review-{review-id}.md` and update the task status in `.taskie/plans/{current-plan-dir}/tasks.md` too. If you don't know what the `{current-plan-dir}` or `{current-task-id}` are, use git history to find out which plan and task was modified most recently.

Remember, you MUST follow the ground rules at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
