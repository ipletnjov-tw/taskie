# Stateful Taskie

## Original Prompt

> We will need to significantly change the Taskie plugin by making it STATEFUL. State will be managed via a short simple JSON file in each Taskie plan directory. The state file will tell us what task (& subtask) we're currently working on and what PHASE (new term) of the task we're currently in, and what phase comes next after the current one. Phases are equivalent to actions, e.g. complete-task-tdd is a phase, and code-review is also a phase. Review phases must have iterations showing which review iteration we're currently at (e.g. code-review-1, code-review-2, etc). Creating & reviewing a plan, creating & reviewing tasks must also be captured in the state file. The state file should only reflect the CURRENT state, not any previous state. The state file should significantly change the current instructions in the continue-plan.md action, as continuing should now be done by looking at the state file's current task and current + next phase to understand where to continue. The state file will allow us to significantly alter how this plugin works: we will add a new set of hooks that will AUTOMATICALLY perform code review (or plan review or tasks review) and post-code-review actions on every single complete-task and complete-task-tdd action. Code review will be performed by calling the `claude` CLI manually with a Taskie prompt, each review will be a clean slate with no prior context. The code review hook will need to alternate between the latest Sonnet and latest Opus model, and this also needs to be codified in the state file. The hook will need to know when to stop, i.e. after each code review hook execution, the main Claude process needs to perform a post-code-review, and only once that's complete and the state file is updated can we proceed to the next code review phase iteration. There should be a limit on maximum code reviews per task, let's default it to 8. Does this make sense? Any questions?

## Clarifications

1. **Hook trigger**: The automatic review hook will use the **Stop** event, same as the existing validation hook. It blocks the stop, runs a `claude` CLI review in a subprocess, then lets the main agent continue with post-review.
2. **Review output**: The `claude` CLI subprocess writes standard review files to disk (e.g. `task-1-review-2.md`). The main agent reads them during post-review, same as the current manual flow.
3. **Review scope**: Plan review, tasks review, AND code review are all automated via hooks during their respective workflows, with model alternation.
4. **Auto-advance**: After a task is fully complete (implementation + all review cycles passed), the state file automatically advances to the next task's implementation phase so `continue-plan` picks it up seamlessly.
5. **Model alternation**: Review 1 = Opus, Review 2 = Sonnet, Review 3 = Opus, etc. Strongest model first.
6. **Review limit**: A global `max_reviews` field in the state file (default 8), applies to all tasks. Can be changed mid-plan.
7. **Scope**: `.llm/` directory is skipped (legacy/separate). Codex prompts are updated where possible (state file read/write, but no hook automation since Codex doesn't support hooks or `claude` CLI).

## Overview

Transform Taskie from a stateless prompt framework into a stateful one by introducing a `state.json` file in each plan directory. This state file tracks the current phase of work (plan creation, review, task implementation, code review, etc.), enabling automated review cycles via Claude Code hooks and seamless session continuation.

The key architectural change is that review phases (code review, plan review, tasks review) become **automatic** during `complete-task` and `complete-task-tdd` workflows. A Stop hook detects when the main agent finishes an implementation or post-review phase, spawns a `claude` CLI subprocess to perform the review (writing review files to disk), then resumes the main agent for post-review. This loop continues until either all reviews pass or the max review limit is reached.

## State File Design

The state file lives at `.taskie/plans/{plan-id}/state.json` and reflects ONLY the current state. It is the single source of truth for where we are in the workflow.

### Schema

```json
{
  "max_reviews": 8,
  "plan_phase": "implementation",
  "current_task": "3",
  "current_subtask": "3.2",
  "phase": "code-review",
  "phase_iteration": 2,
  "next_phase": "post-code-review",
  "review_model": "opus"
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `max_reviews` | number | Maximum review iterations per reviewable phase (default 8) |
| `plan_phase` | string | High-level stage: `"planning"`, `"plan-review"`, `"task-creation"`, `"task-review"`, `"implementation"`, `"complete"` |
| `current_task` | string\|null | Current task ID (e.g. `"3"`), null during planning phases |
| `current_subtask` | string\|null | Current subtask ID (e.g. `"3.2"`), null when not applicable |
| `phase` | string | Current action/phase: `"new-plan"`, `"plan-review"`, `"post-plan-review"`, `"create-tasks"`, `"tasks-review"`, `"post-tasks-review"`, `"next-task"`, `"next-task-tdd"`, `"code-review"`, `"post-code-review"`, `"all-code-review"`, `"post-all-code-review"`, `"complete"` |
| `phase_iteration` | number\|null | Review iteration number (1-based). Only set during review/post-review phases. Null otherwise. |
| `next_phase` | string\|null | The phase to transition to after the current one completes. Null when `phase` is `"complete"`. |
| `review_model` | string | Model for the next review: `"opus"` or `"sonnet"`. Alternates after each review. Starts with `"opus"`. |

### State Transitions

The state file follows these transition paths:

**Planning flow:**
```
new-plan → plan-review (iter 1, model opus) → post-plan-review → plan-review (iter 2, model sonnet) → ... → create-tasks
```

**Task creation flow:**
```
create-tasks → tasks-review (iter 1, model opus) → post-tasks-review → tasks-review (iter 2, model sonnet) → ... → next-task
```

**Implementation flow (complete-task):**
```
next-task → code-review (iter 1, model opus) → post-code-review → code-review (iter 2, model sonnet) → ... → next-task (next task) → ... → complete
```

**Implementation flow (complete-task-tdd):**
```
next-task-tdd → code-review (iter 1, model opus) → post-code-review → code-review (iter 2, model sonnet) → ... → next-task-tdd (next task) → ... → complete
```

**Review exit conditions** (transition out of review loop):
- All reviews pass (no issues found) → advance to next phase
- Max review iterations reached → advance to next phase (main agent requests human input)

**Model alternation**: `opus` → `sonnet` → `opus` → `sonnet` → ...

## Hook Design

### Automatic Review Hook

A new Stop hook (`hooks/auto-review.sh`) handles the automated review cycle:

1. Read `state.json` from the most recently modified plan directory
2. Check if `next_phase` is a review phase (`plan-review`, `tasks-review`, `code-review`, `all-code-review`)
3. If yes:
   a. Invoke `claude` CLI with the appropriate review prompt, using the model from `review_model`
   b. The `claude` CLI writes the review file to disk
   c. Update `state.json`: set `phase` to the review phase, advance `phase_iteration`, toggle `review_model`, set `next_phase` to the corresponding post-review phase
   d. Return a **block** decision with a message telling the main agent to perform post-review
4. If `next_phase` is NOT a review phase, or `phase_iteration` >= `max_reviews`, allow the stop (pass through to validation hook)

### Hook Ordering

The hooks execute in order:
1. `auto-review.sh` — checks state and potentially runs review + blocks
2. `validate-ground-rules.sh` — validates plan structure (existing hook, runs only when auto-review allows the stop through)

### Claude CLI Invocation

The hook script invokes the `claude` CLI like this:
```bash
claude --model claude-sonnet-4-5-20250929 \
       --print \
       --no-input \
       "Perform the action described in ${PLUGIN_ROOT}/actions/code-review.md for plan directory .taskie/plans/${PLAN_ID}/ and task ${CURRENT_TASK}. Write your review to .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}-review-${ITERATION}.md"
```

The `--print` flag ensures output goes to the review file. The `--no-input` flag prevents interactive prompts. The model flag alternates between Opus and Sonnet based on `review_model`.

## Action File Changes

### Modified Actions

1. **`continue-plan.md`** — Major rewrite. Instead of inspecting git history and task file status, it now reads `state.json` and routes directly to the current/next phase. Falls back to git history only if `state.json` doesn't exist.

2. **`new-plan.md`** — After creating `plan.md`, initializes `state.json` with `plan_phase: "planning"`, `phase: "new-plan"`, `next_phase: "plan-review"`.

3. **`create-tasks.md`** — After creating tasks, updates `state.json` with `plan_phase: "task-creation"`, `phase: "create-tasks"`, `next_phase: "tasks-review"`.

4. **`next-task.md`** / **`next-task-tdd.md`** — After implementation, updates `state.json` with `phase: "next-task"`, `next_phase: "code-review"`, sets `current_task` and `current_subtask`.

5. **`code-review.md`** — After writing review, updates `state.json` phase_iteration and sets `next_phase: "post-code-review"`.

6. **`post-code-review.md`** — After applying fixes, updates `state.json`: if issues remain, sets `next_phase: "code-review"` (next iteration); if clean, sets `next_phase: "next-task"` (auto-advance to next task).

7. **`plan-review.md`** / **`post-plan-review.md`** — Same pattern: update `state.json` after each action.

8. **`tasks-review.md`** / **`post-tasks-review.md`** — Same pattern.

9. **`complete-task.md`** / **`complete-task-tdd.md`** — Simplified. The action now only handles the implementation phase. The hook handles review automation. The action sets `next_phase: "code-review"` when implementation completes, and the Stop hook takes over from there.

10. **`all-code-review.md`** / **`post-all-code-review.md`** — Update `state.json` with appropriate phase transitions.

11. **`add-task.md`** — Updates `state.json` to reflect the newly added task if it changes the current workflow.

### New Actions

None needed. The existing action set covers all phases. The hook orchestrates them.

## Ground Rules Changes

`ground-rules.md` needs updates:

1. Add `state.json` to the documented directory structure
2. Document that `state.json` must be updated after every phase transition
3. Add the state file schema reference
4. Note that `state.json` is the authoritative source for "where we are" — not git history, not task file status

## Codex CLI Updates

Codex prompts will be updated to read/write `state.json` where possible:
- `taskie-new-plan.md` — initialize state.json after plan creation
- `taskie-create-tasks.md` — update state.json after task creation
- `taskie-next-task.md` / `taskie-next-task-tdd.md` — update state.json after implementation
- `taskie-continue-plan.md` — read state.json for continuation routing
- All review/post-review prompts — update state.json after execution

No hook automation (Codex doesn't support hooks), but the state file enables manual continuation workflows.

## Validation Hook Updates

The existing `validate-ground-rules.sh` needs to:
1. Recognize `state.json` as a valid file in plan directories (it's not `.md` so the filename regex won't reject it, but we should explicitly allow it)
2. Optionally validate `state.json` schema (valid JSON, required fields present)

## Testing

Existing tests in `tests/hooks/test-validate-ground-rules.sh` need expansion:
- Test that `state.json` is accepted as a valid file in plan directories
- New test suite for `auto-review.sh` hook: state transitions, model alternation, max review limit, review file creation
- Test state.json schema validation
- Test the interaction between auto-review and validate-ground-rules hooks

## Risk Assessment

1. **Hook timeout**: The `claude` CLI review subprocess could take a long time. The current 30s timeout for the validation hook is too short for a full code review. The auto-review hook needs a much longer timeout (300-600s).
2. **Claude CLI availability**: The hook assumes `claude` is on PATH. Need a graceful fallback if it's not available.
3. **Concurrent state writes**: If both the main agent and the hook try to write `state.json` simultaneously, we could get corruption. Mitigation: only the hook writes during review phases, only the main agent writes during other phases.
4. **Infinite loops**: If the post-review keeps finding issues and the review keeps confirming them, we loop until max_reviews. The 8-iteration default provides a safety valve.
5. **State file corruption**: If the process crashes mid-write, `state.json` could be corrupt. The continue-plan action should handle malformed JSON gracefully by falling back to git history.
