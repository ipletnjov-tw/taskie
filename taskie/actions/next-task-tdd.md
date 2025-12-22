# Start Next Task Implementation (TDD)

Proceed to the next task using strict Test-Driven Development. You MUST implement ONLY ONE task, including ALL of its subtasks. You MUST NOT implement more than ONE task. You MUST run all must-run commands for EVERY subtask to verify completion.

For EACH subtask, follow this cycle:

1. **RED**: Write ONE failing test based on acceptance criteria. Run tests to confirm failure. Do NOT write implementation yet.

2. **GREEN**: Write MINIMAL code to pass the test. Run tests to confirm success. Do NOT add extra functionality.

3. **REFACTOR**: Improve structure only when tests pass. Run tests after each change.

4. **REPEAT** until subtask is complete, then run all must-run commands and commit.

For untestable subtasks (docs, config), skip directly to implementation and note in commit why TDD was skipped.

After you're done, document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{current-task-id}.md` and update the status and git commit hash of the subtask(s). Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`.

If you don't know what the `{current-plan-dir}` or `{current-task-id}` are, use git history to find out which plan and task was modified most recently.

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
