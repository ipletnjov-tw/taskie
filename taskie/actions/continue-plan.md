# Continue Existing Implementation Plan

You will need to continue an existing implementation plan. The plan, task list, and task files are in the `.taskie/plans/{current-plan-dir}` directory.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

## Step 1: Read workflow state

First, check if `.taskie/plans/{current-plan-dir}/state.json` exists:

- **If it exists**: Read the state file and proceed to Step 2 (state-based routing)
- **If it exists but is CORRUPTED or invalid JSON**: Restore from git history (`git show HEAD:path/to/state.json`) or manually recreate with sane defaults. If unable to recover, fall back to Step 3 (git-based routing).
- **If it does NOT exist**: This is a plan created before the stateful workflow. Skip to Step 3 (git-based routing fallback)

## Step 2: State-based routing (primary path)

Read `state.json` and extract the `next_phase` and `phase` fields.

### 2.1: Route based on `next_phase` (when non-null)

If `next_phase` is **not null**, route as follows:

#### Post-review phases (highest priority)
- `"post-plan-review"` → Execute `@${CLAUDE_PLUGIN_ROOT}/actions/post-plan-review.md`
- `"post-tasks-review"` → Execute `@${CLAUDE_PLUGIN_ROOT}/actions/post-tasks-review.md`
- `"post-code-review"` → Execute `@${CLAUDE_PLUGIN_ROOT}/actions/post-code-review.md`
- `"post-all-code-review"` → Execute `@${CLAUDE_PLUGIN_ROOT}/actions/post-all-code-review.md`

#### Review phases (crash recovery with heuristic detection)
For review phases, use crash recovery to determine if the review was interrupted mid-execution.

**Important**: These heuristics are best-effort and may misclassify edge cases. If the recovery route seems incorrect, manually edit `state.json` to set the correct `next_phase`.

- `"plan-review"`:
  1. Check if `phase` field is `"post-plan-review"` → Stop and inform user they were addressing plan review feedback. Ask if they want to continue post-review or trigger a new review.
  2. Check if `plan.md` exists AND has at least 50 lines → Likely complete, execute `@${CLAUDE_PLUGIN_ROOT}/actions/plan-review.md`
  3. Otherwise → Plan likely incomplete or just started, execute `@${CLAUDE_PLUGIN_ROOT}/actions/new-plan.md`

- `"tasks-review"`:
  1. Check if `phase` field is `"post-tasks-review"` → Stop and inform user they were addressing tasks review feedback. Ask if they want to continue post-review or trigger a new review.
  2. Check if `tasks.md` exists and has at least 3 lines starting with `|` → Tasks likely complete (header + separator + at least one task), execute `@${CLAUDE_PLUGIN_ROOT}/actions/tasks-review.md`
  3. Otherwise → Tasks likely incomplete, execute `@${CLAUDE_PLUGIN_ROOT}/actions/create-tasks.md`

- `"code-review"`:
  1. Check if `phase` field is `"post-code-review"` → Stop and inform user they were addressing code review feedback. Ask if they want to continue post-review or trigger a new review.
  2. Read `current_task` from state.json. If `task-{current_task}.md` doesn't exist, inform user and ask what to do.
  3. If task file exists, count subtasks with status "completed" vs total subtasks. If >50% complete, assume task implementation was in progress but incomplete → execute `@${CLAUDE_PLUGIN_ROOT}/actions/continue-task.md`. If ≥90% complete, assume task is done → execute `@${CLAUDE_PLUGIN_ROOT}/actions/code-review.md`.
  4. If ambiguous, inform user and ask whether to continue implementation or start review.

- `"all-code-review"`:
  1. Check if `phase` field is `"post-all-code-review"` → Stop and inform user they were addressing all-code review feedback. Ask if they want to continue post-review or trigger a new review.
  2. Count tasks in `tasks.md` with status "done" vs total tasks. If ≥90% done, assume ready for review → execute `@${CLAUDE_PLUGIN_ROOT}/actions/all-code-review.md`. Otherwise, inform user and ask what to do (continue implementation or force review anyway).

#### Advance targets (action execution)
- `"create-tasks"` → Execute `@${CLAUDE_PLUGIN_ROOT}/actions/create-tasks.md`
- `"complete-task"` → Execute `@${CLAUDE_PLUGIN_ROOT}/actions/complete-task.md` (it will determine the next pending task from `tasks.md`)
- `"complete-task-tdd"` → Execute `@${CLAUDE_PLUGIN_ROOT}/actions/complete-task-tdd.md` (it will determine the next pending task from `tasks.md`)
- `"complete"` → Implementation is complete. Set `phase: "complete"`, `next_phase: null` in state.json. Inform the user that all tasks are done and suggest next steps:
  - Review the final implementation
  - Run final integration tests
  - Create a pull request if working in a feature branch
  - Deploy if ready for production

### 2.2: Route based on `phase` (when `next_phase` is null)

If `next_phase` is **null**, the workflow is in standalone mode (interrupted or manual). Route based on `phase`:

#### Implementation phases
- `"implementation"`, `"next-task"`, `"next-task-tdd"`, `"complete-task"`, `"complete-task-tdd"`, `"continue-task"` → Execute `@${CLAUDE_PLUGIN_ROOT}/actions/continue-task.md`

#### Review/post-review phases or other phases
- For any review phase (`"plan-review"`, `"tasks-review"`, `"code-review"`, `"all-code-review"`) or post-review phase when `next_phase` is null → Inform user of current phase, ask what they want to do next
- For `"new-plan"`, `"create-tasks"` → Inform user they were creating artifacts, ask what they want to do
- For `"complete"` → Inform user all tasks are complete

## Step 3: Git-based routing fallback (backwards compatibility)

**Only reach this step if `state.json` does NOT exist.**

This preserves the old behavior for plans created before the stateful workflow:

Carefully read the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` for extra context & further instructions. Figure out where you left off and continue from there: find the last changed task(s) from the task list, check the subtasks and reviews for each task. You may also use git history for more information.

If the task is in-progress, execute action `@${CLAUDE_PLUGIN_ROOT}/actions/continue-task.md`.

If the task is completed but pending review, execute action `@${CLAUDE_PLUGIN_ROOT}/actions/code-review.md`.

If the task's latest review is positive, execute action `@${CLAUDE_PLUGIN_ROOT}/actions/next-task.md`.

If the task's latest review is negative, execute action `@${CLAUDE_PLUGIN_ROOT}/actions/post-code-review.md`.

---

Remember, you MUST follow the `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
