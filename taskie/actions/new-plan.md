# Create New Implementation Plan

You will need to create a new implementation plan according to the process, format and conventions defined in `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md`.

The implementation plan MUST have its own subdirectory under `.taskie/plans`.

The implementation plan MUST be written down into a Markdown file in the `.taskie/plans/{current-plan-dir}`. The file MUST be titled `plan.md`.

The implementation plan file MUST contain the original prompt that was presented to you.

**DO NOT** add any timeline estimates (hours, days, weeks) to any part of the plan, task list, task files or subtasks. Also **DO NOT** add any dates or timestamps to any part of the plan or task list.

After creating the `plan.md` file, you MUST initialize the workflow state file at `.taskie/plans/{current-plan-dir}/state.json` with the following content:

```json
{
  "max_reviews": 8,
  "current_task": null,
  "phase": "new-plan",
  "next_phase": "plan-review",
  "phase_iteration": 0,
  "review_model": "opus",
  "consecutive_clean": 0,
  "tdd": false
}
```

**Important**: This is the ONLY action that constructs `state.json` from scratch. All other actions read and modify the existing state. Use atomic writes (write to temp file, then `mv`) to prevent corruption.

**Note**: The automated review cycle begins immediately after the plan is created. The hook will trigger `plan-review` when you stop. If you need to escape the automated cycle, set `next_phase: null` in `state.json`.

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.