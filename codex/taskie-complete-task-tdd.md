---
description: TDD implementation with automatic review cycle
argument-hint: [additional instructions]
---

**IMPORTANT:** Before proceeding, read and internalize all ground rules from `~/.codex/prompts/taskie-ground-rules.md`. You MUST follow these ground rules at ALL times throughout this task.

# Complete Task with TDD and Review Cycle

Execute full task completion using TDD: Next Task (TDD) → Code Review → Post-Code-Review → Complete. You MUST complete ONLY ONE task.

## Phase 1: Next Task / TDD Implementation

Implement the next task using strict Test-Driven Development:
- Proceed to the next pending task in the implementation plan
- Implement ONLY ONE task, including ALL of its subtasks
- For EACH subtask, follow the red-green-refactor cycle:
  1. RED: Write ONE failing test based on acceptance criteria. Run tests to confirm failure.
  2. GREEN: Write MINIMAL code to pass the test. Run tests to confirm success.
  3. REFACTOR: Improve structure only when tests pass. Run tests after each change.
  4. REPEAT until subtask is complete
- For untestable subtasks (docs, config), skip directly to implementation and note why TDD was skipped
- Run all must-run commands for EVERY subtask to verify completion
- Document progress and update subtask status and git commit hashes
- Update task status in tasks.md

## Phase 2: Code Review

Perform a thorough code review of the TDD implementation:
- Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering
- Review ALL code that was created, changed or deleted as part of the task
- Double check ALL must-run commands by running them and analyzing results
- Verify TDD process was followed correctly
- Document results in task-{task-id}-review-{review-id}.md
- Update task status in tasks.md

If no issues are identified, skip to Phase 4.

## Phase 3: Post-Code-Review

Address the issues surfaced by the code review:
- Fix all identified issues from the latest review file
- Maintain TDD discipline when making fixes
- Document progress with a short summary in the task file
- Update subtask status and git commit hashes
- Update task status in tasks.md

You MUST address ALL issues. Return to Phase 2 after addressing issues. Maximum of 3 code-review <-> post-code-review cycles per task.
If issues remain after 3 cycles, pause and request human input.

## Phase 4: Complete

Update subtask status to "completed" and task status to "done", then push to remote.

If you don't know the `{current-plan-dir}`, use git history to find the most recently modified plan.

Remember, you MUST follow the ground rules at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
