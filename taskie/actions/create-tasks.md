# Create Task List and Task Files

You MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times.

Compile a step-by-step table of tasks into a separate Markdown file named `.taskie/plans/{current-plan-dir}/tasks.md`. Each task in the table represents a high-level goal that we want to achieve according to the `.taskie/plans/{current-plan-dir}/plan.md`.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Each task in the table MUST have the following fields:
* Id (simple autoincrementing integer)
* Status (pending / done / cancelled / postponed)
* Priority (low / medium / high)
* Description
* Test strategy

For each task, you MUST create a separate Markdown file named `.taskie/plans/{current-plan-dir}/task-{task-id}.md`. For each task, you MUST create a list of subtasks into the task file. Each subtask must have a separate section in the task file.

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

After creating all task files, you MUST update the workflow state file at `.taskie/plans/{current-plan-dir}/state.json`:

1. Read the existing `state.json` file to preserve `max_reviews` and `tdd` values
2. Update the state with the following fields:
   - `phase`: `"create-tasks"`
   - `current_task`: `null` (no task is active yet)
   - `next_phase`: `"tasks-review"` (auto-trigger tasks review)
   - `phase_iteration`: `0` (reset for fresh review cycle)
   - `review_model`: `"opus"` (reset to default)
   - `consecutive_clean`: `0` (reset counter)
   - `max_reviews`: preserve from existing state
   - `tdd`: preserve from existing state
3. Write the updated state atomically using a temp file: write to a temporary file first, then `mv` to `state.json`

Example bash command for atomic write (note: max_reviews and tdd are preserved automatically by jq since they're not listed in the pipeline):
```bash
TEMP_STATE=$(mktemp ".taskie/plans/{current-plan-dir}/state.json.XXXXXX")
jq --arg phase "create-tasks" \
   --argjson current_task null \
   --arg next_phase "tasks-review" \
   --argjson phase_iteration 0 \
   --arg review_model "opus" \
   --argjson consecutive_clean 0 \
   '.phase = $phase | .current_task = $current_task | .next_phase = $next_phase | .phase_iteration = $phase_iteration | .review_model = $review_model | .consecutive_clean = $consecutive_clean' \
   state.json > "$TEMP_STATE"
mv "$TEMP_STATE" state.json
```

**Note**: The automated tasks review cycle begins immediately when you stop. The hook will trigger `tasks-review` automatically.
