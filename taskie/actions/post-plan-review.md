# Implement Post-Review Fixes

Address the issues surfaced by the latest plan review in `.taskie/plans/{current-plan-dir}/plan-review-{latest-review-id}.md`

If you don't know what the `{current-plan-dir}` or `{latest-review-id}` are, use git history to find out which plan and review file was modified most recently.

The review file name follows the pattern `plan-review-{iteration}.md` where iteration comes from `phase_iteration` in state.json for automated reviews.

After implementing the fixes, create `.taskie/plans/{current-plan-dir}/plan-post-review-{iteration}.md` documenting:
- Summary of issues addressed from the review
- Changes made to fix each issue
- Any relevant notes or decisions made

**IMPORTANT: Do NOT update state.json manually.** The stop hook automatically detects when you create the post-review file and manages all state transitions. Just create the post-review file and stop.

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
