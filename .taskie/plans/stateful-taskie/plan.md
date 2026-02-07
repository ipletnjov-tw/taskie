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
| `max_reviews` | number | Maximum review iterations per task per reviewable phase type (default 8). Applies globally to all tasks. |
| `current_task` | string\|null | Current task ID (e.g. `"3"`), null during planning phases |
| `phase` | string | Current action/phase: `"new-plan"`, `"plan-review"`, `"post-plan-review"`, `"create-tasks"`, `"tasks-review"`, `"post-tasks-review"`, `"next-task"`, `"next-task-tdd"`, `"continue-task"`, `"code-review"`, `"post-code-review"`, `"all-code-review"`, `"post-all-code-review"`, `"complete"` |
| `phase_iteration` | number\|null | Review iteration counter (0-based). Initialized to 0 when entering a review cycle. The hook increments it BEFORE running each review (so the first review runs at iteration 1, written to `*-review-1.md`). The hook checks `phase_iteration < max_reviews` AFTER incrementing — if false, the review is skipped and the stop is allowed. This yields exactly `max_reviews` reviews. Null during non-review phases. Resets to 0 when `current_task` changes or a new review cycle begins. |
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

**Planning flow (auto-triggered after `new-plan`):**
```
new-plan → [STOP HOOK] plan-review (iter 1, opus) → [BLOCK] post-plan-review → [STOP HOOK] plan-review (iter 2, sonnet) → ... → create-tasks
```

**Task creation flow (auto-triggered after `create-tasks`):**
```
create-tasks → [STOP HOOK] tasks-review (iter 1, opus) → [BLOCK] post-tasks-review → [STOP HOOK] tasks-review (iter 2, sonnet) → ... → next-task
```

**Implementation flow (complete-task):**
```
next-task → [STOP HOOK] code-review (iter 1, opus) → [BLOCK] post-code-review → [STOP HOOK] code-review (iter 2, sonnet) → ... → next-task (next task, iter resets) → ... → [STOP HOOK] all-code-review (iter 1, opus) → [BLOCK] post-all-code-review → ... → complete
```

**Implementation flow (complete-task-tdd):**
```
next-task-tdd → [STOP HOOK] code-review (iter 1, opus) → [BLOCK] post-code-review → [STOP HOOK] code-review (iter 2, sonnet) → ... → next-task-tdd (next task, iter resets) → ... → [STOP HOOK] all-code-review (iter 1, opus) → [BLOCK] post-all-code-review → ... → complete
```

**Interrupted task resumption:**
```
continue-task → [same as next-task from this point: code-review → post-code-review → ...]
```

**Standalone commands (no hook automation):**
When invoked directly, these commands set `next_phase: null`:
- `next-task` / `next-task-tdd` — implements the task, then stops. No auto-review.
- `code-review` — performs review, then stops. No auto post-review.
- `plan-review` / `tasks-review` — performs review, then stops.

**Commands that ALWAYS auto-trigger reviews:**
- `new-plan` — always sets `next_phase: "plan-review"` (there's no scenario where a plan shouldn't be reviewed)
- `create-tasks` — always sets `next_phase: "tasks-review"` (same rationale)
- `complete-task` / `complete-task-tdd` — sets `next_phase: "code-review"` after implementation

The "standalone = null" rule only applies to implementation and review commands where the user might intentionally want to skip the automation loop.

**Review exit conditions** (transition out of review loop):
- All reviews pass (no issues found) → advance to next phase
- Max review iterations reached (`phase_iteration` >= `max_reviews`) → advance to next phase, main agent requests human input

**Model alternation**: `opus` → `sonnet` → `opus` → `sonnet` → ...

**Auto-advance boundaries:**
- After plan review passes → auto-advance to `create-tasks` (no user intervention needed)
- After tasks review passes → auto-advance to first `next-task` (no user intervention needed)
- After code review passes for a task → auto-advance to next task's implementation (no user intervention)
- After last task's code review passes → auto-advance to `all-code-review` (final cross-task review)
- After all-code-review passes → set `phase: "complete"`, `next_phase: null`, agent stops

## Hook Design

### Single Unified Stop Hook

The existing `validate-ground-rules.sh` and the new auto-review logic will be combined into a single Stop hook (`hooks/stop-hook.sh`). This is necessary because Claude Code runs all hooks for the same event **in parallel** — there is no sequential ordering. A single hook avoids race conditions between parallel hooks and ensures validation runs only after the review decision is made.

The hook resolves the plugin root relative to its own location:
```bash
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```
This works because the hook is at `hooks/stop-hook.sh` and actions/ground-rules are one directory up. The resolved absolute path is used in the `claude` CLI prompt strings.

The unified hook follows this logic:

1. Check `stop_hook_active` — if true, approve immediately (prevent infinite loops)
2. Check if `.taskie/plans` exists — if not, approve (not using Taskie)
3. Find the most recently modified plan directory
4. Read `state.json` — if missing or malformed, fall through to validation only
5. Check if `next_phase` is a review phase (`plan-review`, `tasks-review`, `code-review`, `all-code-review`):
   a. Increment `phase_iteration` (from 0 to 1 for the first review)
   b. Check if `phase_iteration` <= `max_reviews` — if NOT, skip to step 6 (limit reached)
   c. Invoke `claude` CLI to perform the review (see CLI invocation below). The review file is named `*-review-${phase_iteration}.md`.
   d. Verify the review file was written to disk. If not (CLI failure), log warning and skip to step 6.
   e. Update `state.json`: set `phase` to the review phase, write the incremented `phase_iteration`, toggle `review_model`, set `next_phase` to the corresponding post-review phase
   f. Return a **block** decision with a precise instruction message (see block message template below)
6. If `next_phase` is NOT a review phase, or `phase_iteration` > `max_reviews`, or `next_phase` is null:
   a. Run the existing plan structure validation (rules 1-7 from the current `validate-ground-rules.sh`)
   b. If validation passes, approve the stop
   c. If validation fails, block with the validation error

### Claude CLI Invocation

The hook script invokes the `claude` CLI like this:

```bash
claude --print \
       --model "${REVIEW_MODEL}" \
       --dangerously-skip-permissions \
       "Read the ground rules in ${PLUGIN_ROOT}/ground-rules.md, then read the plan in .taskie/plans/${PLAN_ID}/plan.md, then read .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}.md. Now perform the code review action described in ${PLUGIN_ROOT}/actions/code-review.md for this task. Write your review to .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}-review-${ITERATION}.md. Be very critical." \
       > /dev/null 2>&1
```

Key flags:
- `--print` / `-p`: Non-interactive mode. The CLI performs the review using tools and exits.
- `--model "${REVIEW_MODEL}"`: Uses `opus` or `sonnet` alias, which the CLI resolves to the latest version automatically. No manual model ID updates needed.
- `--dangerously-skip-permissions`: Required because the subprocess needs to read files, write the review file, and run must-run commands without interactive permission prompts. All tools are available. **Security note**: the subprocess can run arbitrary commands — this is acceptable because it runs in the same project directory as the main agent with the same trust level.
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

Commands fall into two categories:

**Always auto-trigger reviews** (set `next_phase` to a review phase):
- `/taskie:new-plan` → creates plan, then auto plan-review loop via hook
- `/taskie:create-tasks` → creates tasks, then auto tasks-review loop via hook
- `/taskie:complete-task` → implements one task, then auto code-review loop via hook
- `/taskie:complete-task-tdd` → same as above but with TDD

**Standalone commands** (set `next_phase: null`, no hook automation):
- `/taskie:next-task` / `/taskie:next-task-tdd` → implements one task, stops. No auto-review.
- `/taskie:code-review` → performs one review, stops. No auto post-review.
- `/taskie:plan-review` / `/taskie:tasks-review` → performs one review, stops.

### Modified Actions

1. **`continue-plan.md`** — Major rewrite. Instead of inspecting git history and task file status, it now reads `state.json` and routes based on `next_phase` first (what should happen next), falling back to `phase` (what was last done) only when `next_phase` is null:

   **When `next_phase` is non-null** (interrupted automated workflow — this is the primary routing path):
   - `next_phase` = `"post-code-review"` → execute `post-code-review.md` (review file already on disk)
   - `next_phase` = `"post-plan-review"` → execute `post-plan-review.md`
   - `next_phase` = `"post-tasks-review"` → execute `post-tasks-review.md`
   - `next_phase` = `"post-all-code-review"` → execute `post-all-code-review.md`
   - `next_phase` = `"code-review"` / `"plan-review"` / `"tasks-review"` / `"all-code-review"` → the hook will handle this on the next stop, so execute `continue-task.md` or inform the agent to complete its current work and stop
   - `next_phase` = `"next-task"` / `"next-task-tdd"` → execute the next task
   - `next_phase` = `"create-tasks"` → execute `create-tasks.md`

   **When `next_phase` is null** (standalone command was interrupted):
   - `phase` = `"continue-task"` or `"next-task"` or `"next-task-tdd"` → execute `continue-task.md`
   - `phase` = `"complete"` → inform user all tasks are done

   **Falls back to git history** only if `state.json` doesn't exist (backwards compatibility with pre-stateful plans).

2. **`new-plan.md`** — After creating `plan.md`, initializes `state.json` with `phase: "new-plan"`, `next_phase: "plan-review"`, `phase_iteration: 0`, `review_model: "opus"`. Always auto-triggers plan review — there's no scenario where a plan shouldn't be reviewed.

3. **`create-tasks.md`** — After creating tasks, updates `state.json` with `phase: "create-tasks"`, `next_phase: "tasks-review"`, `phase_iteration: 0`, `review_model: "opus"`. Always auto-triggers tasks review. Also adds `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` reference (currently missing from this action).

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

### Test Infrastructure Changes

#### File Organization

The current test tree has a single file. The new structure:

```
tests/
├── README.md                                    # Updated with new test descriptions
├── hooks/
│   ├── test-validate-ground-rules.sh            # RENAMED: test-stop-hook-validation.sh
│   ├── test-stop-hook-auto-review.sh            # NEW: auto-review logic tests
│   ├── test-stop-hook-state-transitions.sh      # NEW: state.json transition tests
│   ├── test-stop-hook-cli-invocation.sh         # NEW: claude CLI mocking tests
│   └── helpers/
│       ├── mock-claude.sh                       # NEW: mock claude CLI
│       └── test-utils.sh                        # NEW: shared test helpers
```

#### Test Runner Updates

`run-tests.sh` must be updated to:
- Accept a new test suite argument: `./run-tests.sh state` for state-related tests only
- Run all test files in `tests/hooks/` matching `test-*.sh` when `hooks` or `all` is specified
- Support running a single test file: `./run-tests.sh tests/hooks/test-stop-hook-auto-review.sh`

`Makefile` gets new targets:
- `make test-state` — run only state/auto-review tests
- `make test-validation` — run only validation rule tests (the existing ones)

#### Shared Test Helpers (`tests/hooks/helpers/test-utils.sh`)

Extract common patterns from `test-validate-ground-rules.sh` into a shared helper:

```bash
# Shared functions:
# - pass(message)           — log green checkmark, increment counter
# - fail(message)           — log red X, increment counter
# - create_test_plan(dir)   — create a minimal valid plan directory with plan.md + tasks.md
# - create_state_json(dir, json_content) — write state.json to a plan dir
# - run_hook(json_input)    — pipe JSON to the hook script, capture stdout+stderr+exit code
# - assert_approved(result) — verify hook approved the stop (exit 0, no block decision)
# - assert_blocked(result, reason_pattern) — verify hook blocked with matching reason
# - print_results()         — print pass/fail summary, exit 1 if any failures
```

The existing `test-validate-ground-rules.sh` will be refactored to use these helpers (reducing duplication) and renamed to `test-stop-hook-validation.sh` since the hook script it tests is now `stop-hook.sh`.

#### Mock Claude CLI (`tests/hooks/helpers/mock-claude.sh`)

A shell script placed on PATH during tests that simulates the `claude` CLI:

```bash
#!/bin/bash
# Mock claude CLI for testing
# Behavior is controlled by environment variables:
#   MOCK_CLAUDE_EXIT_CODE — exit code to return (default: 0)
#   MOCK_CLAUDE_REVIEW_DIR — directory to write the review file to
#   MOCK_CLAUDE_REVIEW_FILE — filename of the review file to write
#   MOCK_CLAUDE_DELAY — seconds to sleep before responding (for timeout tests)
#   MOCK_CLAUDE_LOG — file to append invocation args to (for verifying correct flags)

# Log the invocation for verification
echo "$@" >> "${MOCK_CLAUDE_LOG:-/dev/null}"

# Simulate delay if requested
if [ -n "${MOCK_CLAUDE_DELAY:-}" ]; then
    sleep "$MOCK_CLAUDE_DELAY"
fi

# Write a dummy review file if configured
if [ -n "${MOCK_CLAUDE_REVIEW_DIR:-}" ] && [ -n "${MOCK_CLAUDE_REVIEW_FILE:-}" ]; then
    cat > "${MOCK_CLAUDE_REVIEW_DIR}/${MOCK_CLAUDE_REVIEW_FILE}" << 'REVIEW'
# Review
## Issues Found
1. Minor: variable naming inconsistency
REVIEW
fi

exit "${MOCK_CLAUDE_EXIT_CODE:-0}"
```

Tests prepend the mock directory to PATH so `command -v claude` finds the mock instead of the real CLI:

```bash
MOCK_DIR=$(mktemp -d)
cp "$HELPERS_DIR/mock-claude.sh" "$MOCK_DIR/claude"
chmod +x "$MOCK_DIR/claude"
export PATH="$MOCK_DIR:$PATH"
```

### Test Suite 1: Validation Rules (test-stop-hook-validation.sh)

These are the existing 13 tests, ported to test `stop-hook.sh` instead of `validate-ground-rules.sh`. All expected behaviors remain identical — the validation logic is preserved unchanged within the unified hook.

| # | Test | Input | Expected |
|---|------|-------|----------|
| 1 | jq dependency check | N/A | pass if jq installed |
| 2 | Invalid JSON input | `"invalid json"` | exit 2, stderr mentions "Invalid JSON" |
| 3 | Invalid directory | `{"cwd": "/nonexistent"}` | exit 2, stderr mentions "Cannot change" |
| 4 | stop_hook_active | `{"stop_hook_active": true}` | exit 0, suppressOutput |
| 5 | No .taskie directory | valid cwd, no `.taskie/plans` | exit 0, suppressOutput |
| 6 | Valid plan structure | plan.md + tasks.md (table) | exit 0, systemMessage "validated" |
| 7 | Missing plan.md + invalid filename | only `invalid-file.md` | exit 0, decision: block |
| 8 | Nested directories | plan.md + nested/extra.md | exit 0, decision: block, "nested" |
| 9 | Review without base file | plan.md + design-review-1.md (no design.md) | exit 0, decision: block |
| 10 | Post-review without review | plan.md + plan-post-review-1.md (no plan-review-1.md) | exit 0, decision: block |
| 11 | Task files without tasks.md | plan.md + task-1.md (no tasks.md) | exit 0, decision: block |
| 12 | Non-table tasks.md | plan.md + tasks.md with prose | exit 0, decision: block, "non-table" |
| 13 | Empty tasks.md | plan.md + empty tasks.md | exit 0, decision: block, "no table rows" |

**Additional validation test for state.json:**

| # | Test | Input | Expected |
|---|------|-------|----------|
| 14 | state.json is not rejected by filename validation | plan.md + state.json | exit 0, validated (state.json is not `.md`, so it's ignored by rule 2) |
| 15 | Invalid state.json produces warning | plan.md + state.json with `"not valid json"` | exit 0, validated (warning logged but not blocking) |
| 16 | state.json missing required fields | plan.md + state.json `{"phase": "new-plan"}` (missing other fields) | exit 0, validated (warning logged but not blocking) |
| 17 | Valid state.json passes schema validation | plan.md + complete valid state.json | exit 0, validated (no warning) |

### Test Suite 2: Auto-Review Logic (test-stop-hook-auto-review.sh)

Tests the core auto-review decision logic in `stop-hook.sh`. All tests use the mock `claude` CLI.

| # | Test | state.json content | Expected |
|---|------|-------------------|----------|
| 1 | Trigger code review | `{phase: "next-task", next_phase: "code-review", phase_iteration: 0, max_reviews: 8, review_model: "opus", current_task: "1"}` | block, reason contains "task-1-review-1.md", mock claude invoked |
| 2 | Trigger plan review | `{phase: "new-plan", next_phase: "plan-review", phase_iteration: 0, max_reviews: 8, review_model: "opus", current_task: null}` | block, reason contains "plan-review-1.md", mock claude invoked |
| 3 | Trigger tasks review | `{phase: "create-tasks", next_phase: "tasks-review", phase_iteration: 0, max_reviews: 8, review_model: "opus", current_task: null}` | block, reason contains "tasks-review-1.md", mock claude invoked |
| 4 | next_phase is null (standalone) | `{phase: "next-task", next_phase: null, ...}` | approve (falls through to validation), mock claude NOT invoked |
| 5 | next_phase is post-code-review (not a review phase) | `{phase: "code-review", next_phase: "post-code-review", ...}` | approve (post-review is done by the main agent, not the hook) |
| 6 | Max reviews reached | `{phase: "post-code-review", next_phase: "code-review", phase_iteration: 8, max_reviews: 8, ...}` | approve (falls through to validation), mock claude NOT invoked |
| 7 | Max reviews with custom limit | `{..., phase_iteration: 3, max_reviews: 3, ...}` | approve (limit reached) |
| 8 | state.json missing | no state.json file | approve (falls through to validation only) |
| 9 | state.json malformed | `"not json"` | approve (falls through to validation only), warning logged |
| 10 | next_phase is "next-task" (auto-advance, not review) | `{phase: "post-code-review", next_phase: "next-task", ...}` | approve (not a review phase) |
| 11 | next_phase is "create-tasks" (auto-advance, not review) | `{phase: "post-plan-review", next_phase: "create-tasks", ...}` | approve (not a review phase) |
| 12 | Trigger all-code-review | `{phase: "post-code-review", next_phase: "all-code-review", phase_iteration: 0, ...}` | block, reason contains "all-code-review-1.md" |

### Test Suite 3: State Transitions (test-stop-hook-state-transitions.sh)

Tests that the hook correctly updates `state.json` after running a review. All tests use the mock `claude` CLI.

| # | Test | Initial state.json | Expected state.json after hook |
|---|------|--------------------|---------------------------------|
| 1 | Code review: phase updated | `{phase: "next-task", next_phase: "code-review", phase_iteration: 0, review_model: "opus", current_task: "1"}` | `{phase: "code-review", next_phase: "post-code-review", phase_iteration: 1, review_model: "sonnet", current_task: "1"}` |
| 2 | Plan review: phase updated | `{phase: "new-plan", next_phase: "plan-review", phase_iteration: 0, review_model: "opus", current_task: null}` | `{phase: "plan-review", next_phase: "post-plan-review", phase_iteration: 1, review_model: "sonnet", current_task: null}` |
| 3 | Tasks review: phase updated | `{phase: "create-tasks", next_phase: "tasks-review", phase_iteration: 0, review_model: "opus"}` | `{phase: "tasks-review", next_phase: "post-tasks-review", phase_iteration: 1, review_model: "sonnet"}` |
| 4 | Model alternation opus→sonnet | `{..., review_model: "opus", phase_iteration: 0}` | `{..., review_model: "sonnet", phase_iteration: 1}` |
| 5 | Model alternation sonnet→opus | `{..., review_model: "sonnet", phase_iteration: 1, next_phase: "code-review"}` | `{..., review_model: "opus", phase_iteration: 2}` |
| 6 | Iteration increment | `{..., phase_iteration: 4, next_phase: "code-review"}` | `{..., phase_iteration: 5}` |
| 7 | max_reviews preserved | `{..., max_reviews: 5}` | `{..., max_reviews: 5}` (unchanged) |
| 8 | current_task preserved | `{..., current_task: "3"}` | `{..., current_task: "3"}` (unchanged) |

### Test Suite 4: CLI Invocation (test-stop-hook-cli-invocation.sh)

Tests that the hook invokes the `claude` CLI with the correct flags and arguments. Uses `MOCK_CLAUDE_LOG` to capture invocation args.

| # | Test | Scenario | Verify in MOCK_CLAUDE_LOG |
|---|------|----------|---------------------------|
| 1 | Model flag: opus | `review_model: "opus"` | `--model opus` appears in args |
| 2 | Model flag: sonnet | `review_model: "sonnet"` | `--model sonnet` appears in args |
| 3 | Permissions bypass | any review trigger | `--dangerously-skip-permissions` in args |
| 4 | Print flag | any review trigger | `--print` in args |
| 5 | Code review prompt contains task reference | code review for task 3 | prompt contains `task-3.md` and `task-3-review-` |
| 6 | Plan review prompt contains plan reference | plan review | prompt contains `plan.md` and `plan-review-` |
| 7 | Tasks review prompt contains tasks reference | tasks review | prompt contains `tasks.md` and `tasks-review-` |
| 8 | Review file written to correct path | code review for task 2, iteration 3 | file `task-2-review-3.md` exists in plan directory |
| 9 | Claude CLI not on PATH | remove mock from PATH | hook approves (falls through to validation), warning logged to stderr |
| 10 | Claude CLI fails (exit 1) | `MOCK_CLAUDE_EXIT_CODE=1` | hook approves (falls through to validation), warning logged |
| 11 | Claude CLI fails to write review file | `MOCK_CLAUDE_REVIEW_DIR` not set (mock writes nothing) | hook approves (falls through to validation), warning logged |
| 12 | Claude CLI timeout | `MOCK_CLAUDE_DELAY=5` with hook timeout shorter | hook approves (falls through), warning logged |

### Test Suite 5: Block Message Templates (part of test-stop-hook-auto-review.sh)

Tests that the `reason` in the block decision contains the correct information for each review type.

| # | Test | Review type | Verify in reason field |
|---|------|-------------|----------------------|
| 1 | Code review block message | code-review, task 2, iter 3 | contains `task-2-review-3.md`, `post-code-review`, `state.json` |
| 2 | Plan review block message | plan-review, iter 1 | contains `plan-review-1.md`, `post-plan-review`, `plan.md` |
| 3 | Tasks review block message | tasks-review, iter 2 | contains `tasks-review-2.md`, `post-tasks-review`, `tasks.md` |
| 4 | All-code-review block message | all-code-review, iter 1 | contains `all-code-review-1.md`, `post-all-code-review` |
| 5 | Block message includes plan directory | any review | contains the actual plan directory name (not a placeholder) |
| 6 | Block message is valid JSON | any review | `jq` can parse the full hook output, `.decision` = `"block"` |

### Test Suite 6: Edge Cases & Integration

| # | Test | Scenario | Expected |
|---|------|----------|----------|
| 1 | Multiple plan directories | two plan dirs, one more recently modified | hook validates/reviews only the most recent plan |
| 2 | state.json with extra unknown fields | `{phase: "next-task", ..., "custom_field": 42}` | hook works normally, ignores unknown fields |
| 3 | Phase iteration is null (non-review phase, standalone) | `{phase: "next-task", phase_iteration: null, next_phase: null}` | approve (standalone, no review) |
| 4 | review_model is unexpected value | `{..., review_model: "haiku"}` | hook passes it to `--model haiku` (CLI handles validation) |
| 5 | Concurrent plan creation | state.json exists but plan.md doesn't (user just initialized) | validation blocks for missing plan.md (rule 1) |
| 6 | Auto-review takes precedence over validation | `next_phase: "code-review"` but plan dir has nested files | hook runs review and blocks for post-review (validation is NOT reached — it only runs when the hook falls through to step 6). Nested files would be caught on a subsequent stop when `next_phase` is no longer a review phase. |
| 7 | Empty plan directory | `.taskie/plans/` exists but no plan subdirectories | approve (no plan to validate) |
| 8 | max_reviews is 0 | `{..., max_reviews: 0, phase_iteration: 0, next_phase: "code-review"}` | approve immediately (0 means no reviews) |
| 9 | Backwards compatibility: no state.json, valid plan | plan.md + tasks.md, no state.json | approve (validation only, no auto-review) |

### Expected Test Counts

| Test suite | Count |
|------------|-------|
| Validation rules (ported + new) | 17 |
| Auto-review logic | 12 |
| State transitions | 8 |
| CLI invocation | 13 |
| Block message templates | 6 |
| Edge cases & integration | 9 |
| **Total** | **65** |

### Test Execution

All tests must pass with `make test` before any commit. Tests are exempt from versioning (per CLAUDE.md).

Tests that invoke the mock `claude` CLI must clean up the mock from PATH after each test case to avoid polluting subsequent tests. Each test creates its own `mktemp -d` and cleans it in a trap.

No real API calls are ever made during testing. The mock `claude` script is the only "CLI" that runs.

## Risk Assessment

1. **Hook timeout**: The unified Stop hook timeout is set to 600 seconds (10 minutes). If the `claude` CLI subprocess exceeds this, the hook logs a warning and allows the stop rather than blocking indefinitely.

2. **Claude CLI availability**: The hook checks `command -v claude` before attempting to invoke it. If `claude` is not on PATH, the hook skips the review, logs a warning, and falls through to validation only.

3. **Concurrent state writes**: The hook and the main agent never write `state.json` at the same time because the hook runs synchronously during the Stop event — the main agent is paused while the hook executes. The sequence is: main agent writes → tries to stop → hook fires (agent paused) → hook writes → hook returns → agent resumes → agent writes. No overlap.

4. **Infinite loops**: The `stop_hook_active` flag prevents the hook from firing recursively. The `max_reviews` limit (default 8) caps the review loop. The hook always allows the stop when `phase_iteration >= max_reviews`.

5. **State file corruption recovery**: If `state.json` is missing or contains invalid JSON, the `continue-plan` action falls back to git history analysis (pre-stateful behavior). The hook also handles this gracefully — if it can't read `state.json`, it skips the review and runs validation only.

6. **Crash between hook block and agent post-review**: If the main agent crashes after the hook blocks the stop but before the agent completes post-review, `state.json` will show `phase: "<review-type>"` with `next_phase: "post-<review-type>"`. When the user resumes with `continue-plan`, it reads this state and routes to the post-review action. The review file is already on disk (written by the hook's subprocess), so the agent can pick up where it left off. This is a safe recovery path.

7. **Destructive reviews**: There is no rollback mechanism if a review suggests destructive changes. The `max_reviews` limit is the safety valve — after 8 iterations, the agent stops and requests human input. Each subtask completion is committed to git, so `git revert` or `git reset` can undo damage. The post-review action should be instructed to exercise judgment and skip suggestions that would remove working functionality.

8. **User escape hatch**: To break the auto-review loop mid-workflow, the user can edit `state.json` and set `"next_phase": null`. The hook will see null and allow the stop on the next attempt. Alternatively, setting `"max_reviews": 0` disables all reviews. These options should be mentioned in the block message template as a brief note, e.g.: `"(To stop the review loop, set next_phase to null in state.json.)"`
