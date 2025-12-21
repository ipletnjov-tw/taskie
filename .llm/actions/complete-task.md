# Complete Task with Review Cycle

Execute full task completion: Implement → Review → Fix → Verify. You MUST complete ONLY ONE task.

## Phase 1: Implementation

Execute action `.llm/actions/next-task.md`.

## Phase 2: Code Review

Execute action `.llm/actions/code-review.md`.

If no issues are identified, skip to Phase 4.

## Phase 3: Post-Review Fixes

Execute action `.llm/actions/post-code-review.md`.

You MUST address ALL issues. Return to Phase 2. Maximum 3 review-fix cycles. If issues remain, pause and request human input.

## Phase 4: Verification

Update subtask status to "completed" and task status to "done", then push to remote.

If you don't know `{current-plan-dir}`, use git history to find the most recently modified plan.

Remember, you MUST follow `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
