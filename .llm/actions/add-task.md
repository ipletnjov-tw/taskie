# Add New Task to Implementation Plan

Add a new task to the existing task list in `.llm/plans/{current-plan-dir}/tasks.md`. The new task represents a high-level goal that extends the current implementation plan.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Read the existing `tasks.md` to determine the next task ID (highest existing ID + 1). The new task MUST have the following fields:
* Id (next available autoincrementing integer)
* Status (pending)
* Priority (low / medium / high)
* Description
* Test strategy

You MUST create a separate Markdown file named `.llm/plans/{current-plan-dir}/task-{task-id}.md` with a list of subtasks. Each subtask must have a separate section in the task file.

Each subtask MUST have the following fields:
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

Remember, you MUST follow the `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
