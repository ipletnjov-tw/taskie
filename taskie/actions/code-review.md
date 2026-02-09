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

If you don't know what the `{current-plan-dir}` or `{current-task-id}` are, use git history to find out which plan and task was modified most recently.

After completing the review, check the workflow context to determine if this is a standalone or automated review:

1. Read `.taskie/plans/{current-plan-dir}/state.json`
2. Check the `phase_iteration` field:
   - **If `phase_iteration` is null or doesn't exist**: This is a STANDALONE review (you invoked it manually)
     - Update `state.json` with:
       - `phase`: `"code-review"`
       - `next_phase`: `null` (standalone, no automation)
       - `phase_iteration`: `null` (marks standalone mode)
       - Preserve all other fields
     - Write atomically (temp file + mv)
   - **If `phase_iteration` is non-null (a number)**: This is an AUTOMATED review (hook-invoked)
     - DO NOT update `state.json` - the hook manages the state for automated reviews
     - Just push your changes

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
