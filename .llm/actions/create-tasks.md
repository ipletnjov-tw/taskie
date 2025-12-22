# Create Task List and Task Files

Compile a step-by-step table of tasks into a separate Markdown file named `.llm/plans/{current-plan-dir}/tasks.md`. Each task in the table represents a high-level goal that we want to achieve according to the `.llm/plans/{current-plan-dir}/plan.md`.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Each task in the table MUST have the following fields:
* Id (simple autoincrementing integer)
* Status (pending / done / cancelled / postponed)
* Priority (low / medium / high)
* Description
* Test strategy

The `tasks.md` file MUST NOT contain anything other than the tasks table. You MUST add a disclaimer below the table that forbids adding anything else to the file.

For each task, you MUST create a separate Markdown file named `.llm/plans/{current-plan-dir}/task-{task-id}.md`. For each task, you MUST create a list of subtasks into the task file. Each subtask must have a separate section in the task file.

Each subtask MUST have the following fields:
```md
### Subtask 1.1: Sample Subtask
- **Short description**:
- **Status**: (pending / awaiting-review / review-changes-requested / completed / postponed)
- **Sample git commit message**: 
- **Git commit hash**: (To be filled in after subtask completion)
- **Priority**: (low / medium / high)
- **Complexity**: (1 - 10)
- **Test approach**:
- **Must-run commands**: (For completion verification, e.g. `npm test`, `npm run lint`, etc)
- **Acceptance criteria**: (Specific, testable conditions that define "done")
```
