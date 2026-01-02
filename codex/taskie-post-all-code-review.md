---
description: Address the complete implementation review comments
argument-hint: [additional instructions]
---

**IMPORTANT:** Before proceeding, read and internalize all ground rules from `~/.codex/prompts/taskie-ground-rules.md`. You MUST follow these ground rules at ALL times throughout this task.


# Implement Post-Review Fixes

Address the issues surfaced by the latest complete implementation review in `.taskie/plans/{current-plan-dir}/all-code-review-{latest-review-id}.md`

If you don't know what the `{current-plan-dir}` or `{latest-review-id}` are, use git history to find out which plan and review file was modified most recently.

After you're done with your changes, create `.taskie/plans/{current-plan-dir}/all-code-post-review-{latest-review-id}.md` documenting:
- Summary of issues addressed from the review
- Changes made to fix each issue
- Update the status and git commit hash of any affected subtask(s) in their respective task files
- Any relevant notes or decisions made

Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md` if any tasks were modified.

Do NOT forget to push your changes to remote.

$ARGUMENTS
