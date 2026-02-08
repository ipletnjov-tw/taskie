---
description: Continue an existing implementation plan
argument-hint: [additional instructions]
---

**IMPORTANT:** Before proceeding, read and internalize all ground rules from `~/.codex/prompts/taskie-ground-rules.md`. You MUST follow these ground rules at ALL times throughout this task.

# Continue Existing Implementation Plan

You will need to continue an existing implementation plan. The plan, task list, design document and task files are in the `.taskie/plans/{current-plan-dir}` directory.

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

## Step 1: State-first approach

**CRITICAL**: The `state.json` file is the authoritative source for workflow state. If it exists, use it to determine the next action. Only fall back to git history analysis if `state.json` doesn't exist.

1. Check if `.taskie/plans/{current-plan-dir}/state.json` exists
2. If it exists, read the `next_phase` and `phase` fields and proceed to Step 2
3. If it doesn't exist, proceed to Step 3 (git-based fallback)

## Step 2: State-based routing (primary path)

Read `state.json` and extract the `next_phase` and `phase` fields.

### 2.1: Route based on `next_phase` (when non-null)

If `next_phase` is **not null**, route as follows:

#### Post-review phases (highest priority)
- `"post-plan-review"` → Address plan review feedback
- `"post-tasks-review"` → Address tasks review feedback
- `"post-code-review"` → Address code review feedback
- `"post-all-code-review"` → Address all-code review feedback

#### Review phases (crash recovery with heuristic detection)
For review phases, use crash recovery to determine if the review was interrupted mid-execution.

**Important**: These heuristics are best-effort and may misclassify edge cases. If the recovery route seems incorrect, manually edit `state.json` to set the correct `next_phase`.

- `"plan-review"`:
  1. Check if `phase` field is `"post-plan-review"` → Stop and inform user they were addressing plan review feedback. Ask if they want to continue post-review or trigger a new review.
  2. Check if `plan.md` exists AND (has `## Overview` heading OR ≥50 lines) → Likely complete, perform plan review
  3. Otherwise → Plan likely incomplete or just started, continue creating the plan

- `"tasks-review"`:
  1. Check if `phase` field is `"post-tasks-review"` → Stop and inform user they were addressing tasks review feedback. Ask if they want to continue post-review or trigger a new review.
  2. Check if `tasks.md` exists and has at least 3 lines starting with `|` → Tasks likely complete (header + separator + at least one task), perform tasks review
  3. Otherwise → Tasks likely incomplete, continue creating tasks

- `"code-review"`:
  1. Check if `phase` field is `"post-code-review"` → Stop and inform user they were addressing code review feedback. Ask if they want to continue post-review or trigger a new review.
  2. Read `current_task` from state.json. If `current_task` is null or `task-{current_task}.md` doesn't exist, inform user that current task is invalid and ask which task to work on.
  3. If task file exists, count subtasks: completed_count = subtasks with status exactly "completed"; total_count = all subtasks regardless of status. Calculate completion_pct = (completed_count / total_count) * 100.
  4. Route based on completion percentage:
     - If completion_pct ≥ 90% → Assume task is done, perform code review
     - If 50% < completion_pct < 90% → Assume task in progress, continue implementing the task
     - If completion_pct ≤ 50% OR calculation is ambiguous (e.g., 0 total subtasks) → INFORM USER of the ambiguity and ASK whether to continue implementation or start review

- `"all-code-review"`:
  1. Check if `phase` field is `"post-all-code-review"` → Stop and inform user they were addressing all-code review feedback. Ask if they want to continue post-review or trigger a new review.
  2. Count tasks in `tasks.md`: done_count = tasks with status exactly "done"; active_count = tasks with status "pending" or "done" (exclude "cancelled", "postponed"). Calculate done_pct = (done_count / active_count) * 100.
  3. Route based on done percentage:
     - If done_pct ≥ 90% → Assume ready for review, perform all-code review
     - If done_pct < 90% OR calculation is ambiguous → INFORM USER that X out of Y tasks are done and ASK whether to continue implementation or start review anyway

#### Advance targets (action execution)
- `"create-tasks"` → Continue creating tasks from the plan
- `"complete-task"` → Implement the next pending task (determine from `tasks.md`)
- `"complete-task-tdd"` → Implement the next pending task using TDD (determine from `tasks.md`)
- `"complete"` → Implementation is complete. Set `phase: "complete"`, `next_phase: null` in state.json. Inform the user that all tasks are done and suggest next steps:
  - Review the final implementation
  - Run final integration tests
  - Create a pull request if working in a feature branch
  - Deploy if ready for production

### 2.2: Route based on `phase` (when `next_phase` is null)

If `next_phase` is **null**, the workflow is in standalone mode (interrupted or manual). Route based on `phase`:

#### Implementation phases
- `"implementation"`, `"next-task"`, `"next-task-tdd"`, `"complete-task"`, `"complete-task-tdd"`, `"continue-task"` → Continue implementing the current task

#### Review/post-review phases or other phases
- For any review phase (`"plan-review"`, `"tasks-review"`, `"code-review"`, `"all-code-review"`) or post-review phase when `next_phase` is null → Inform user of current phase, ask what they want to do next
- For `"new-plan"`, `"create-tasks"` → Inform user they were creating artifacts, ask what they want to do
- For `"complete"` → Inform user all tasks are complete

## Step 3: Git-based routing fallback (backwards compatibility)

If `state.json` doesn't exist, fall back to git history analysis:

Figure out where you left off and continue from there: find the last changed task(s) from the task list, check the subtasks and reviews for each task. You may also use git history for more information.

Determine the next appropriate action based on the current state:

- **If the task is in-progress**: Continue implementing the task.
  - Document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{current-task-id}.md`
  - Update the status and git commit hash of the subtask(s)
  - Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`

- **If the task is completed but pending review**: Perform a code review.
  - Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering and other cruft
  - Don't let ANYTHING slip, write down even the most minor issues
  - Review ALL code that was created, changed or deleted as part of the task, NOT just the latest fixes
  - Double check ALL the must-run commands by running them and analyzing their results
  - Document the results in `.taskie/plans/{current-plan-dir}/task-{current-task-id}-review-{review-id}.md`
  - Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`

- **If the task's latest review is positive**: Start the next task.
  - Proceed to the next pending task in the implementation plan
  - Implement ONLY ONE task, including ALL of the task's subtasks
  - Run all must-run commands for EVERY subtask to verify completion
  - Document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{next-task-id}.md`
  - Update the status and git commit hash of the subtask(s)
  - Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`

- **If the task's latest review is negative**: Address review feedback.
  - Fix all identified issues from the latest review file `.taskie/plans/{current-plan-dir}/task-{current-task-id}-review-{latest-review-id}.md`
  - Document your progress with a short summary in `.taskie/plans/{current-plan-dir}/task-{current-task-id}.md`
  - Update the status and git commit hash of the subtask(s)
  - Update the task status in `.taskie/plans/{current-plan-dir}/tasks.md`

Remember, you MUST follow the ground rules at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
