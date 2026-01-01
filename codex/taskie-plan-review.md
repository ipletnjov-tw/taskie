---
description: Review and critique the current plan
argument-hint: [additional instructions]
---

# Ground Rules

Read and follow the ground rules defined in `~/.codex/prompts/taskie-ground-rules.md`


# Perform Implementation Plan Review

Perform a thorough review of the proposed implementation plan defined in `.llm/plans/{current-plan-dir}/plan.md`. Be very critical, look for mistakes, inconsistencies, misunderstandings, misconceptions, scope creep, over-engineering and other cruft.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Document the results of your review in `.llm/plans/{current-plan-dir}/plan-{review-id}.md`.

Remember, you MUST follow the ground rules above at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
