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
  "current_task": "3",
  "phase": "code-review",
  "phase_iteration": 2,
  "next_phase": "post-code-review",
  "review_model": "opus"
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `max_reviews` | number | Maximum review iterations per task per reviewable phase type (default 8). Applies globally to all tasks. `phase_iteration` resets to 1 when `current_task` changes. |
| `current_task` | string\|null | Current task ID (e.g. `"3"`), null during planning phases |
| `phase` | string | Current action/phase: `"new-plan"`, `"plan-review"`, `"post-plan-review"`, `"create-tasks"`, `"tasks-review"`, `"post-tasks-review"`, `"next-task"`, `"next-task-tdd"`, `"continue-task"`, `"code-review"`, `"post-code-review"`, `"all-code-review"`, `"post-all-code-review"`, `"complete"` |
| `phase_iteration` | number\|null | Review iteration number (1-based). Only set during review/post-review phases. Null otherwise. Resets to 1 when `current_task` changes. |
| `next_phase` | string\|null | The phase to transition to after the current one completes. Null when no automated follow-up is expected (e.g. standalone `next-task` without review automation, or `phase` is `"complete"`). |
| `review_model` | string | Model alias for the next review: `"opus"` or `"sonnet"`. Passed directly to the `claude` CLI as `--model opus` or `--model sonnet`, which resolve to the latest version of each model. Alternates after each review. Starts with `"opus"`. |

### Deriving the High-Level Stage

The high-level stage of the plan can be derived from `phase` — no separate field is needed:

| `phase` value | Derived stage |
|---------------|---------------|
| `new-plan` | Planning |
| `plan-review`, `post-plan-review` | Plan review |
| `create-tasks` | Task creation |
| `tasks-review`, `post-tasks-review` | Task review |
| `next-task`, `next-task-tdd`, `continue-task`, `code-review`, `post-code-review` | Implementation |
| `all-code-review`, `post-all-code-review` | Final review |
| `complete` | Complete |

### State Transitions

The state file follows these transition paths:

**Planning flow (triggered by `complete-task` or `complete-task-tdd`):**
```
new-plan → [STOP HOOK] plan-review (iter 1, opus) → [BLOCK] post-plan-review → [STOP HOOK] plan-review (iter 2, sonnet) → ... → create-tasks
```

**Task creation flow (continues automatically from planning):**
```
create-tasks → [STOP HOOK] tasks-review (iter 1, opus) → [BLOCK] post-tasks-review → [STOP HOOK] tasks-review (iter 2, sonnet) → ... → next-task
```

**Implementation flow (complete-task):**
```
next-task → [STOP HOOK] code-review (iter 1, opus) → [BLOCK] post-code-review → [STOP HOOK] code-review (iter 2, sonnet) → ... → next-task (next task, iter resets) → ... → complete
```

**Implementation flow (complete-task-tdd):**
```
next-task-tdd → [STOP HOOK] code-review (iter 1, opus) → [BLOCK] post-code-review → [STOP HOOK] code-review (iter 2, sonnet) → ... → next-task-tdd (next task, iter resets) → ... → complete
```

**Interrupted task resumption:**
```
continue-task → [same as next-task from this point: code-review → post-code-review → ...]
```

**Standalone commands (no hook automation):**
When invoked directly (not via `complete-task`/`complete-task-tdd`), these commands set `next_phase: null`:
- `next-task` / `next-task-tdd` — implements the task, then stops. No auto-review.
- `code-review` — performs review, then stops. No auto post-review.
- `plan-review` / `tasks-review` — performs review, then stops.

Only `complete-task` and `complete-task-tdd` set `next_phase` to review phases, enabling the hook automation loop.

**Review exit conditions** (transition out of review loop):
- All reviews pass (no issues found) → advance to next phase
- Max review iterations reached (`phase_iteration` >= `max_reviews`) → advance to next phase, main agent requests human input

**Model alternation**: `opus` → `sonnet` → `opus` → `sonnet` → ...

**Auto-advance boundaries:**
- After plan review passes → auto-advance to `create-tasks` (no user intervention needed)
- After tasks review passes → auto-advance to first `next-task` (no user intervention needed)
- After code review passes for a task → auto-advance to next task's implementation (no user intervention)
- After all tasks complete → set `phase: "complete"`, `next_phase: null`, agent stops

## Hook Design

### Single Unified Stop Hook

The existing `validate-ground-rules.sh` and the new auto-review logic will be combined into a single Stop hook (`hooks/stop-hook.sh`). This is necessary because Claude Code runs all hooks for the same event **in parallel** — there is no sequential ordering. A single hook avoids race conditions between parallel hooks and ensures validation runs only after the review decision is made.

The unified hook follows this logic:

1. Check `stop_hook_active` — if true, approve immediately (prevent infinite loops)
2. Check if `.taskie/plans` exists — if not, approve (not using Taskie)
3. Find the most recently modified plan directory
4. Read `state.json` — if missing or malformed, fall through to validation only
5. Check if `next_phase` is a review phase (`plan-review`, `tasks-review`, `code-review`, `all-code-review`) AND `phase_iteration` < `max_reviews`:
   a. Invoke `claude` CLI to perform the review (see CLI invocation below)
   b. Verify the review file was written to disk
   c. Update `state.json`: set `phase` to the review phase, increment `phase_iteration`, toggle `review_model`, set `next_phase` to the corresponding post-review phase
   d. Return a **block** decision with a precise instruction message (see block message template below)
6. If `next_phase` is NOT a review phase, or `phase_iteration` >= `max_reviews`, or `next_phase` is null:
   a. Run the existing plan structure validation (rules 1-7 from the current `validate-ground-rules.sh`)
   b. If validation passes, approve the stop
   c. If validation fails, block with the validation error

### Claude CLI Invocation

The hook script invokes the `claude` CLI like this:

```bash
claude --print \
       --model "${REVIEW_MODEL}" \
       --dangerously-skip-permissions \
       --allowedTools "Read Grep Glob Write Bash" \
       "Read the ground rules in ${PLUGIN_ROOT}/ground-rules.md, then read the plan in .taskie/plans/${PLAN_ID}/plan.md, then read .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}.md. Now perform the code review action described in ${PLUGIN_ROOT}/actions/code-review.md for this task. Write your review to .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}-review-${ITERATION}.md. Be very critical." \
       > /dev/null 2>&1
```

Key flags:
- `--print` / `-p`: Non-interactive mode. The CLI performs the review using tools and exits.
- `--model "${REVIEW_MODEL}"`: Uses `opus` or `sonnet` alias, which the CLI resolves to the latest version automatically. No manual model ID updates needed.
- `--dangerously-skip-permissions`: Required because the subprocess needs to read files, write the review file, and run must-run commands without interactive permission prompts. **Security note**: the subprocess can run arbitrary commands — this is acceptable because it runs in the same project directory as the main agent with the same trust level.
- `--allowedTools "Read Grep Glob Write Bash"`: Limits available tools to what's needed for a review.
- Stdout redirected to `/dev/null` because the CLI writes the review file to disk via its Write tool (not stdout).

The prompt instructs the CLI to read the ground rules, plan, and task file before reviewing — this provides the context that a fresh session lacks.

For **plan reviews**, the prompt is adapted:
```bash
"Read the ground rules in ${PLUGIN_ROOT}/ground-rules.md, then read .taskie/plans/${PLAN_ID}/plan.md. Perform the plan review action described in ${PLUGIN_ROOT}/actions/plan-review.md. Write your review to .taskie/plans/${PLAN_ID}/plan-review-${ITERATION}.md. Be very critical."
```

For **tasks reviews**, similarly adapted to read `tasks.md` and all `task-*.md` files.

### Block Message Template

When the hook blocks the stop to trigger post-review, the `reason` field must be precise enough for the main agent to know exactly what to do:

**For code review:**
```
A code review (iteration ${ITERATION}) has been written to .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}-review-${ITERATION}.md by an independent reviewer. Read this review file and perform the post-code-review action: address all issues, update the code, then create .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}-post-review-${ITERATION}.md documenting your fixes. Update state.json when complete: set phase to "post-code-review" and next_phase to "code-review" if issues remain, or next_phase to "next-task" if all issues are resolved. Update tasks.md and push to remote.
```

**For plan review:**
```
A plan review (iteration ${ITERATION}) has been written to .taskie/plans/${PLAN_ID}/plan-review-${ITERATION}.md by an independent reviewer. Read this review file and perform the post-plan-review action: address all issues in plan.md, then create .taskie/plans/${PLAN_ID}/plan-post-review-${ITERATION}.md documenting your fixes. Update state.json when complete: set phase to "post-plan-review" and next_phase to "plan-review" if issues remain, or next_phase to "create-tasks" if all issues are resolved. Push to remote.
```

**For tasks review:**
```
A tasks review (iteration ${ITERATION}) has been written to .taskie/plans/${PLAN_ID}/tasks-review-${ITERATION}.md by an independent reviewer. Read this review file and perform the post-tasks-review action: address all issues in tasks.md and task files, then create .taskie/plans/${PLAN_ID}/tasks-post-review-${ITERATION}.md documenting your fixes. Update state.json when complete: set phase to "post-tasks-review" and next_phase to "tasks-review" if issues remain, or next_phase to "next-task" if all issues are resolved. Push to remote.
```

### Hook Timeout

The auto-review hook timeout must be significantly longer than the validation-only hook:
- Set to **600 seconds** (10 minutes) to allow the `claude` CLI subprocess to complete a full review
- If the subprocess times out, the hook should treat it as a failed review: log a warning, skip the review, and allow the stop through to avoid blocking the user indefinitely

## Action File Changes

### Automation Boundary Rule

The critical distinction between standalone commands and automated workflows:

- **`complete-task`** and **`complete-task-tdd`** are the ONLY entry points that enable hook automation. They set `next_phase` to review phases, which the Stop hook detects and acts on.
- **All other commands** (`next-task`, `code-review`, `plan-review`, etc.) when invoked standalone set `next_phase: null`. The hook sees null and allows the stop — no automation.

This means:
- `/taskie:next-task` → implements one task, stops. No auto-review.
- `/taskie:complete-task` → implements one task, then auto-review loop kicks in via hook.
- `/taskie:code-review` → performs one review, stops. No auto post-review.

### Modified Actions

1. **`continue-plan.md`** — Major rewrite. Instead of inspecting git history and task file status, it now reads `state.json` and routes directly based on `phase`:
   - `phase` = `"continue-task"` → execute `continue-task.md`
   - `phase` = `"post-code-review"` → execute `post-code-review.md`
   - `phase` = `"post-plan-review"` → execute `post-plan-review.md`
   - `phase` = `"post-tasks-review"` → execute `post-tasks-review.md`
   - `phase` = `"next-task"` or `"next-task-tdd"` with task completed → execute next task
   - `phase` = `"code-review"` → execute `code-review.md`
   - `phase` = `"complete"` → inform user all tasks are done
   - Falls back to git history only if `state.json` doesn't exist (backwards compatibility with pre-stateful plans).

2. **`new-plan.md`** — After creating `plan.md`, initializes `state.json` with `phase: "new-plan"`, `next_phase: null` (standalone) or `next_phase: "plan-review"` (only when invoked via `complete-task` workflow).

3. **`create-tasks.md`** — After creating tasks, updates `state.json` with `phase: "create-tasks"`. Sets `next_phase: "tasks-review"` if in an automated workflow, `null` otherwise. Also adds `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` reference (currently missing from this action).

4. **`next-task.md`** / **`next-task-tdd.md`** — After implementation, updates `state.json` with `phase: "next-task"` (or `"next-task-tdd"`), sets `current_task`, sets `next_phase: null`. These are standalone commands — they do NOT trigger auto-review.

5. **`complete-task.md`** / **`complete-task-tdd.md`** — These are the automation entry points. After the implementation phase (delegating to `next-task.md` / `next-task-tdd.md` internally), they update `state.json` with `next_phase: "code-review"`, `phase_iteration: 0`, `review_model: "opus"`. When the main agent then tries to stop, the hook takes over and runs the review loop. The action itself no longer contains a Phase 2/3/4 loop — the hook handles it.

6. **`code-review.md`** — When invoked standalone, writes review and sets `next_phase: null`. When invoked by the hook, the hook manages the state transitions (the action itself doesn't need to update `state.json` since the hook does it).

7. **`post-code-review.md`** — After applying fixes: if issues remain, sets `next_phase: "code-review"`; if all issues resolved, sets `next_phase: "next-task"` (auto-advance) or `next_phase: null` (standalone). The determination of standalone vs. automated is based on whether `phase_iteration` is non-null in `state.json`.

8. **`plan-review.md`** / **`post-plan-review.md`** — Same pattern. Standalone sets `next_phase: null`. When in automated flow, `post-plan-review` sets `next_phase: "plan-review"` (if issues remain) or `next_phase: "create-tasks"` (if resolved).

9. **`tasks-review.md`** / **`post-tasks-review.md`** — Same pattern. `post-tasks-review` sets `next_phase: "tasks-review"` (issues remain) or `next_phase: "next-task"` (resolved).

10. **`continue-task.md`** — Updates `state.json` with `phase: "continue-task"`. After completion, follows the same `next_phase` logic as `next-task` (null for standalone, `"code-review"` if in automated workflow).

11. **`all-code-review.md`** / **`post-all-code-review.md`** — Update `state.json` with appropriate phase transitions.

12. **`add-task.md`** — Updates `state.json` to set `current_task` to the new task if no task is currently in progress.

### New Actions

None needed. The existing action set covers all phases. The hook orchestrates the automated workflow.

## Ground Rules Changes

`ground-rules.md` needs updates:

1. Add `state.json` to the documented directory structure
2. Document that `state.json` must be updated after every phase transition
3. Add the state file schema reference
4. Note that `state.json` is the authoritative source for "where we are" — not git history, not task file status

## Codex CLI Updates

Codex prompts will be updated with a limited scope — only where state file interaction is practical without hook automation:

- `taskie-new-plan.md` — initialize `state.json` after plan creation
- `taskie-continue-plan.md` — read `state.json` for continuation routing (the primary benefit)

Other Codex prompts are NOT updated for state file writes. Without hooks to enforce state updates, making every prompt manually update `state.json` is fragile and adds complexity for uncertain benefit. The Codex workflow remains largely manual.

## Validation Hook Updates

The existing `validate-ground-rules.sh` is being absorbed into the unified `stop-hook.sh`. The validation logic (rules 1-7) is preserved unchanged within the new hook.

The `state.json` file does NOT need special handling for filename validation — the existing validation only iterates over `*.md` files, so `state.json` is already ignored by rule 2.

A new validation rule (rule 8) is added: if `state.json` exists, validate that it is valid JSON and contains the required fields (`phase`, `next_phase`, `review_model`, `max_reviews`). If validation fails, log a warning but do NOT block the stop — a corrupt state file should not prevent the user from stopping.

## Testing

### Existing tests
The existing tests in `tests/hooks/test-validate-ground-rules.sh` must continue to pass — the validation rules 1-7 are preserved in the unified hook.

### New tests needed
- **State file validation**: Test that `state.json` is accepted (not rejected) as a file in plan directories. Test that invalid JSON in `state.json` produces a warning but does not block the stop.
- **Unified stop hook**: Test the full logic of `stop-hook.sh`:
  - When `stop_hook_active` is true → approve immediately
  - When `.taskie/plans` doesn't exist → approve
  - When `state.json` is missing → fall through to validation only
  - When `next_phase` is a review phase and `phase_iteration` < `max_reviews` → block (mock `claude` CLI)
  - When `next_phase` is null → validate and approve
  - When `phase_iteration` >= `max_reviews` → validate and approve
  - Model alternation: verify `review_model` toggles correctly
  - `phase_iteration` reset when `current_task` changes
- **Claude CLI mocking**: Tests for the hook must mock the `claude` CLI (e.g. a shell script that creates a dummy review file) to avoid actual API calls. Test that the hook handles CLI failures gracefully (non-zero exit, timeout).
- **Block message templates**: Verify the `reason` field contains the expected file paths and instructions for each review type (code, plan, tasks).

## Risk Assessment

1. **Hook timeout**: The unified Stop hook timeout is set to 600 seconds (10 minutes). If the `claude` CLI subprocess exceeds this, the hook logs a warning and allows the stop rather than blocking indefinitely.

2. **Claude CLI availability**: The hook checks `command -v claude` before attempting to invoke it. If `claude` is not on PATH, the hook skips the review, logs a warning, and falls through to validation only.

3. **Concurrent state writes**: The hook and the main agent never write `state.json` at the same time because the hook runs synchronously during the Stop event — the main agent is paused while the hook executes. The sequence is: main agent writes → tries to stop → hook fires (agent paused) → hook writes → hook returns → agent resumes → agent writes. No overlap.

4. **Infinite loops**: The `stop_hook_active` flag prevents the hook from firing recursively. The `max_reviews` limit (default 8) caps the review loop. The hook always allows the stop when `phase_iteration >= max_reviews`.

5. **State file corruption recovery**: If `state.json` is missing or contains invalid JSON, the `continue-plan` action falls back to git history analysis (pre-stateful behavior). The hook also handles this gracefully — if it can't read `state.json`, it skips the review and runs validation only.

6. **Crash between hook block and agent post-review**: If the main agent crashes after the hook blocks the stop but before the agent completes post-review, `state.json` will show `phase: "<review-type>"` with `next_phase: "post-<review-type>"`. When the user resumes with `continue-plan`, it reads this state and routes to the post-review action. The review file is already on disk (written by the hook's subprocess), so the agent can pick up where it left off. This is a safe recovery path.

7. **Destructive reviews**: There is no rollback mechanism if a review suggests destructive changes. The `max_reviews` limit is the safety valve — after 8 iterations, the agent stops and requests human input. Each subtask completion is committed to git, so `git revert` or `git reset` can undo damage. The post-review action should be instructed to exercise judgment and skip suggestions that would remove working functionality.
