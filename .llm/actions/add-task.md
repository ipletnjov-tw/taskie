# Add New Task to Implementation Plan

Add a new task to an existing implementation plan. This action allows you to expand the task list when new requirements are discovered during implementation or when the scope needs to be extended.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

## Steps

1. **Read existing task list**: Read `.llm/plans/{current-plan-dir}/tasks.md` to determine the next available task ID.

2. **Determine next task ID**: Find the highest task ID in the tasks table and increment by 1.

3. **Gather task information**: Collect the following information for the new task:
   - Description (concise summary of the task goal)
   - Priority (low / medium / high)
   - Test strategy (how this task will be tested)

4. **Create task file**: Create `.llm/plans/{current-plan-dir}/task-{new-task-id}.md` with subtasks. Each subtask MUST have the following fields:
```md
### Subtask {task-id}.{subtask-number}: Sample Subtask
- **Short description**:
- **Status**: pending
- **Sample git commit message**:
- **Git commit hash**: (To be filled in after subtask completion)
- **Priority**: (low / medium / high)
- **Complexity**: (1 - 10)
- **Test approach**:
- **Must-run commands**: (For completion verification, e.g. `npm test`, `npm run lint`, etc)
- **Acceptance criteria**: (Specific, testable conditions that define "done")
```

5. **Update tasks table**: Add a new row to `.llm/plans/{current-plan-dir}/tasks.md` with the new task. The status MUST be set to `pending`. Maintain the table structure and ensure ONLY the table and disclaimer exist in the file.

Remember, you MUST follow the `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
