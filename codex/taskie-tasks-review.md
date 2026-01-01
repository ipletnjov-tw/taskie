---
description: Review the task list and task files
argument-hint: [additional instructions]
---

# Ground Rules

Read and follow the ground rules defined in `~/.codex/prompts/taskie-ground-rules.md`


# Perform Task List Review

Perform a thorough review of the task list in `.llm/plans/{current-plan-dir}/tasks.md` and all task files. Be very critical, look for mistakes, inconsistencies, misunderstandings, gaps in the task breakdown, over-engineering and other cruft.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Document the results of your review in `.llm/plans/{current-plan-dir}/tasks-review-{review-id}.md`.

Remember, you MUST follow the ground rules above at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
