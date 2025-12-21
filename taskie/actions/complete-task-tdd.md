# Complete Task with Review Cycle (TDD)

Execute full task completion using TDD: Implement → Self-Review → Fix → Verify. You MUST complete ONLY ONE task.

## Phase 1: Implementation

Execute action `@${CLAUDE_PLUGIN_ROOT}/actions/next-task-tdd.md`.

## Phase 2: Self-Review

Execute action `@${CLAUDE_PLUGIN_ROOT}/actions/code-review.md`.

If no blocking issues, skip to Phase 4.

## Phase 3: Fix Blocking Issues

Execute action `@${CLAUDE_PLUGIN_ROOT}/actions/post-code-review.md`.

Return to Phase 2. Maximum 3 review-fix cycles. If issues remain, pause and request human input.

## Phase 4: Verification

Update task status to "awaiting-human-review" and push to remote.

If you don't know `{current-plan-dir}`, use git history to find the most recently modified plan.

Remember, you MUST follow `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
