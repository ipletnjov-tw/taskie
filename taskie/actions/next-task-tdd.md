# Start Next Task Implementation (TDD)

Proceed to the next task using strict Test-Driven Development. You MUST implement ONLY ONE task, including ALL of its subtasks. You MUST NOT implement more than ONE task. You MUST run all must-run commands for EVERY subtask to verify completion.

For EACH subtask, follow this cycle:

1. **RED**: Write ONE failing test based on acceptance criteria. Run tests to confirm failure. Do NOT write implementation yet.

2. **GREEN**: Write MINIMAL code to pass the test. Run tests to confirm success. Do NOT add extra functionality.

3. **REFACTOR**: Improve structure only when tests pass. Run tests after each change.

4. **REPEAT** until subtask is complete, then run all must-run commands and commit.

For untestable subtasks (docs, config), skip directly to implementation and note in commit why TDD was skipped.

After you're done, document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{current-task-id}.md` and update the status and git commit hash of the subtask(s). Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`.

After completing implementation, you MUST update the workflow state file at `.taskie/plans/{current-plan-dir}/state.json`:

1. Read the existing `state.json` file
2. Update the state with the following fields:
   - `phase`: `"next-task-tdd"`
   - `current_task`: `"{task-id}"` (the task ID you just implemented)
   - `next_phase`: `null` (standalone mode, no automated workflow)
   - `phase_iteration`: `null` (not in a review cycle)
   - Preserve all other fields: `max_reviews`, `review_model`, `consecutive_clean`, `tdd`
3. Write the updated state atomically using a temp file: write to a temporary file first, then `mv` to `state.json`

If you don't know what the `{current-plan-dir}` or `{current-task-id}` are, use git history to find out which plan and task was modified most recently.

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
