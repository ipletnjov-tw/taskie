# Complete Task with Review Cycle

Execute full task completion: Implement → Self-Review → Fix → Verify. You MUST complete ONLY ONE task.

## Phase 1: Implementation

1. Identify the next pending task from `.llm/plans/{current-plan-dir}/tasks.md`
2. Read task details from `.llm/plans/{current-plan-dir}/task-{current-task-id}.md`
3. For each subtask: implement, run must-run commands, commit, update status and git hash
4. Document progress with a short summary in the task file

## Phase 2: Self-Review

Critically review ALL code for this task. Look for: mistakes, inconsistencies, shortcuts, over-engineering. Create review file: `.llm/plans/{current-plan-dir}/task-{current-task-id}-review-{review-id}.md`. Mark issues as **Blocking** or **Advisory**.

## Phase 3: Fix Blocking Issues

Address each blocking issue. Run must-run commands. Commit fixes.

## Phase 4: Verification

Run all must-run commands. If any fail, return to Phase 3. If all pass, update task status to "awaiting-human-review" and push to remote.

Maximum 3 review-fix cycles. If issues remain, pause and request human input.

If you don't know `{current-plan-dir}` or `{current-task-id}`, use git history to find the most recently modified plan and task.

Remember, you MUST follow `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
