---
description: TDD implementation with automatic review cycle
argument-hint: [additional instructions]
---

# Complete Task with TDD and Review Cycle

Execute full task completion using TDD: Next Task (TDD) → Code Review → Post-Code-Review → Complete. You MUST complete ONLY ONE task.

## Phase 1: Next Task / TDD Implementation

Execute action `.llm/actions/next-task-tdd.md`.

## Phase 2: Code Review

Execute action `.llm/actions/code-review.md`.

If no issues are identified, skip to Phase 4.

## Phase 3: Post-Code-Review

Execute action `.llm/actions/post-code-review.md`.

You MUST address ALL issues. Return to Phase 2 after addressing issues. Maximum of 3 code-review <-> post-code-review cycles per task.
If issues remain after 3 cycles, pause and request human input.

## Phase 4: Complete

Update subtask status to "completed" and task status to "done", then push to remote.

If you don't know the `{current-plan-dir}`, use git history to find the most recently modified plan.

Remember, you MUST follow `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
