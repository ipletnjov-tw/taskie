---
description: Critically review implemented code
argument-hint: [additional instructions]
---

**IMPORTANT:** Before proceeding, read and internalize all ground rules from `~/.codex/prompts/taskie-ground-rules.md`. You MUST follow these ground rules at ALL times throughout this task.

# Perform Task Code Review

Perform a thorough review of the current task implementation and latest changes. Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering and other cruft. Don't let ANYTHING slip, write down even the most minor issues. You MUST review ALL code that was created, changed or deleted as part of the task, NOT just the latest fixes.

Double check ALL the must-run commands by running them and analyzing their results.

**Your review must be a clean slate. Do not look at any prior review files.**

Document the results of your review in `.taskie/plans/{current-plan-dir}/code-review-{iteration}.md`.

**Review file naming (CRITICAL - ALWAYS create a NEW file, NEVER modify existing):**
- Find all existing `code-review-*.md` files in the plan directory
- Use `max(existing iteration numbers) + 1` as the iteration number
- Example: if `code-review-1.md` and `code-review-2.md` exist, create `code-review-3.md`
- If no review files exist, start with `code-review-1.md`
- **NEVER overwrite an existing review file**

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Remember, you MUST follow the ground rules at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
