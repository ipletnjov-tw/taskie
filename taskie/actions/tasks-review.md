# Perform Task List and Task Files Review

Perform a thorough review of the proposed task list defined in `.taskie/plans/{current-plan-dir}/tasks.md` and the corresponding task files `.taskie/plans/{current-plan-dir}/task-{task-id}.md`. Be very critical, look for mistakes, inconsistencies, misunderstandings, misconceptions, scope creep, over-engineering and other cruft.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Document the results of your review in `.taskie/plans/{current-plan-dir}/tasks-review-{iteration}.md`.

**Review file naming**:
- For AUTOMATED reviews (invoked by hook): use the `phase_iteration` value from state.json as the iteration number (e.g., `tasks-review-1.md`, `tasks-review-2.md`)
- For STANDALONE reviews (manual invocation): use an incrementing number based on existing review files in the directory

After completing the review, check the workflow context to determine if this is a standalone or automated review:

1. Read `.taskie/plans/{current-plan-dir}/state.json`
2. Check the `phase_iteration` field:
   - **If `phase_iteration` is null or doesn't exist**: This is a STANDALONE review (you invoked it manually)
     - Update `state.json` with:
       - `phase`: `"tasks-review"`
       - `next_phase`: `null` (standalone, no automation)
       - `phase_iteration`: `null` (explicitly set to prevent stale values)
       - Preserve all other fields
     - Write atomically (temp file + mv)
   - **If `phase_iteration` is non-null (a number)**: This is an AUTOMATED review (hook-invoked)
     - DO NOT update `state.json` - the hook manages the state for automated reviews
     - Just push your changes

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.