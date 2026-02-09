# Perform Implementation Plan Review

Perform a thorough review of the proposed implementation plan defined in `.taskie/plans/{current-plan-dir}/plan.md`. Be very critical, look for mistakes, inconsistencies, misunderstandings, misconceptions, scope creep, over-engineering and other cruft.

**Your review must be a clean slate. Do not look at any prior review files.**

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Document the results of your review in `.taskie/plans/{current-plan-dir}/plan-review-{iteration}.md`.

**Review file naming**:
- For AUTOMATED reviews (invoked by hook): use the `phase_iteration` value from state.json as the iteration number (e.g., `plan-review-1.md`, `plan-review-2.md`)
- For STANDALONE reviews (manual invocation): use max(existing iteration numbers) + 1 from existing review files in the directory

After completing the review, check the workflow context to determine if this is a standalone or automated review:

1. Read `.taskie/plans/{current-plan-dir}/state.json`
2. Check the `phase_iteration` field:
   - **If `phase_iteration` is null or doesn't exist**: This is a STANDALONE review (you invoked it manually)
     - Update `state.json` with:
       - `phase`: `"plan-review"`
       - `next_phase`: `null` (standalone, no automation)
       - `phase_iteration`: `null` (marks standalone mode)
       - Preserve all other fields
     - Write atomically (temp file + mv)
   - **If `phase_iteration` is non-null (a number)**: This is an AUTOMATED review (hook-invoked)
     - DO NOT update `state.json` - the hook manages the state for automated reviews
     - Just push your changes

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.