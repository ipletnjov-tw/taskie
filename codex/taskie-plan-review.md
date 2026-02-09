---
description: Review and critique the current plan
argument-hint: [additional instructions]
---

**IMPORTANT:** Before proceeding, read and internalize all ground rules from `~/.codex/prompts/taskie-ground-rules.md`. You MUST follow these ground rules at ALL times throughout this task.

# Perform Implementation Plan Review

Perform a thorough review of the proposed implementation plan defined in `.taskie/plans/{current-plan-dir}/plan.md`. Be very critical, look for mistakes, inconsistencies, misunderstandings, misconceptions, scope creep, over-engineering and other cruft.

**Your review must be a clean slate. Do not look at any prior review files.**

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Document the results of your review in `.taskie/plans/{current-plan-dir}/plan-review-{iteration}.md`.

**Review file naming (CRITICAL - ALWAYS create a NEW file, NEVER modify existing):**
- Find all existing `plan-review-*.md` files in the plan directory
- Use `max(existing iteration numbers) + 1` as the iteration number
- Example: if `plan-review-1.md` and `plan-review-2.md` exist, create `plan-review-3.md`
- If no review files exist, start with `plan-review-1.md`
- **NEVER overwrite an existing review file**

Remember, you MUST follow the ground rules at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
