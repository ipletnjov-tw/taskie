# Complete Task with Review Cycle (TDD)

Execute full task completion using TDD: Implement → Self-Review → Fix → Verify. You MUST complete ONLY ONE task.

## Phase 1: Implementation

Execute action `.llm/actions/next-task-tdd.md`.

## Phase 2: Self-Review

Execute action `.llm/actions/code-review.md`.

If no issues, skip to Phase 4.

## Phase 3: Fix Issues

Execute action `.llm/actions/post-code-review.md`.

Return to Phase 2. Maximum 3 review-fix cycles. If issues remain, pause and request human input.

## Phase 4: Verification

Update subtask status to "completed" and task status to "done", then push to remote.

If you don't know `{current-plan-dir}`, use git history to find the most recently modified plan.

Remember, you MUST follow `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
