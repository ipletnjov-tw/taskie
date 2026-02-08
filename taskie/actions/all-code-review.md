# Perform Complete Implementation Review

Perform a thorough review of ALL code implemented across ALL tasks (completed or in-progress) in the current implementation plan. Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering and other cruft. Don't let ANYTHING slip, write down even the most minor issues. You MUST review ALL code that was created, changed or deleted as part of the entire plan implementation, NOT just recent changes.

Double check ALL the must-run commands from all tasks by running them and analyzing their results.

Document the results of your review in `.taskie/plans/{current-plan-dir}/all-code-review-{iteration}.md`.

**Review file naming**:
- For AUTOMATED reviews (invoked by hook): use the `phase_iteration` value from state.json as the iteration number (e.g., `all-code-review-1.md`, `all-code-review-2.md`)
- For STANDALONE reviews (manual invocation): use max(existing iteration numbers) + 1 from existing review files in the directory

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

After completing the review, check the workflow context to determine if this is a standalone or automated review:

1. Read `.taskie/plans/{current-plan-dir}/state.json`
2. Check the `phase_iteration` field:
   - **If `phase_iteration` is null or doesn't exist**: This is a STANDALONE review (you invoked it manually)
     - Update `state.json` with:
       - `phase`: `"all-code-review"`
       - `next_phase`: `null` (standalone, no automation)
       - `phase_iteration`: `null` (marks standalone mode)
       - Preserve all other fields
     - Write atomically (temp file + mv)
   - **If `phase_iteration` is non-null (a number)**: This is an AUTOMATED review (hook-invoked)
     - DO NOT update `state.json` - the hook manages the state for automated reviews
     - Just push your changes

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
