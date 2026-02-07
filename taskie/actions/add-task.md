# Add New Task to Implementation Plan

Add a new task to the existing task list in `.taskie/plans/{current-plan-dir}/tasks.md`. The new task represents a high-level goal that extends the current implementation plan.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Read the existing `tasks.md` to determine the next task ID (highest existing ID + 1). The new task MUST have the following fields:
* Id (next available autoincrementing integer)
* Status (pending)
* Priority (low / medium / high)
* Description
* Test strategy

You MUST create a separate Markdown file named `.taskie/plans/{current-plan-dir}/task-{task-id}.md` with a list of subtasks. Each subtask must have a separate section in the task file.

Each subtask MUST have the following fields:
```md
### Subtask 1.1: Sample Subtask
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

After creating the new task and task file, update the workflow state file at `.taskie/plans/{current-plan-dir}/state.json`:

1. Read the existing `state.json` file
2. Check the `current_task` field:
   - **If `current_task` is null**: Set `current_task` to the new task ID (no task was in progress, this is the new current task)
   - **If `current_task` is non-null**: Preserve the existing value (a task is already in progress, don't change it)
3. Preserve all other fields unchanged: `phase`, `next_phase`, `phase_iteration`, `max_reviews`, `review_model`, `consecutive_clean`, `tdd`
4. Write the updated state atomically using a temp file: write to a temporary file first, then `mv` to `state.json`

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
