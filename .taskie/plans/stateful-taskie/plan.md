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

The key architectural change is that review phases (code review, plan review, tasks review) become **automatic** during `complete-task` and `complete-task-tdd` workflows. A Stop hook detects when the main agent finishes an implementation or post-review phase, spawns a `claude` CLI subprocess to perform the review (writing review files to disk), then resumes the main agent for post-review. This loop continues until two consecutive reviews find no issues, or the max review limit is reached (in which case the agent waits for user input).

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
  "review_model": "opus",
  "consecutive_clean": 0,
  "tdd": false
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `max_reviews` | number | Maximum review iterations per review cycle (default 8). Each review cycle (plan-review, tasks-review, code-review per task, all-code-review) independently tracks iterations against this limit. For example, `max_reviews: 4` allows up to 4 plan reviews AND 4 tasks reviews AND 4 code reviews per task AND 4 all-code-reviews. Applies globally to all tasks. |
| `current_task` | string\|null | Current task ID (e.g. `"3"`), null during planning phases |
| `phase` | string | Current action/phase: `"new-plan"`, `"plan-review"`, `"post-plan-review"`, `"create-tasks"`, `"tasks-review"`, `"post-tasks-review"`, `"next-task"`, `"next-task-tdd"`, `"complete-task"`, `"complete-task-tdd"`, `"continue-task"`, `"code-review"`, `"post-code-review"`, `"all-code-review"`, `"post-all-code-review"`, `"complete"` |
| `phase_iteration` | number\|null | Review iteration counter (0-based). Initialized to 0 when entering a review cycle. The hook increments it BEFORE running each review (so the first review runs at iteration 1, written to `*-review-1.md`). The hook then checks `incremented_value <= max_reviews` — if false, the review is skipped and the stop is allowed. This yields exactly `max_reviews` reviews. Null during non-review phases. Resets to 0 when `current_task` changes or a new review cycle begins. |
| `next_phase` | string\|null | The phase to transition to after the current one completes. Null when no automated follow-up is expected (e.g. standalone `next-task` without review automation, or `phase` is `"complete"`). |
| `review_model` | string | Model alias for the next review: `"opus"` or `"sonnet"`. Passed directly to the `claude` CLI as `--model opus` or `--model sonnet`, which resolve to the latest version of each model. Alternates after each review. Starts with `"opus"`. |
| `consecutive_clean` | number | Count of consecutive clean reviews (no issues found). Resets to 0 whenever a review finds issues. When this reaches 2, the hook auto-advances to the next phase instead of blocking for another post-review. Initialized to 0 when entering a review cycle. |
| `tdd` | boolean | Whether the workflow uses TDD (red-green-refactor). Set to `true` by `complete-task-tdd`, `false` by `complete-task`. The hook uses this to auto-advance to `"complete-task-tdd"` or `"complete-task"` after code review passes — ensuring the same workflow variant is used for all tasks in the plan. Default `false`. |

### Deriving the High-Level Stage

The high-level stage of the plan can be derived from `phase` — no separate field is needed:

| `phase` value | Derived stage |
|---------------|---------------|
| `new-plan` | Planning |
| `plan-review`, `post-plan-review` | Plan review |
| `create-tasks` | Task creation |
| `tasks-review`, `post-tasks-review` | Task review |
| `next-task`, `next-task-tdd`, `complete-task`, `complete-task-tdd`, `continue-task`, `code-review`, `post-code-review` | Implementation |
| `all-code-review`, `post-all-code-review` | Final review |
| `complete` | Complete |

### State Transitions

The state file follows these transition paths:

**Planning flow (auto-triggered after `new-plan`):**
```
new-plan → [STOP HOOK] plan-review (iter 1, opus) → [BLOCK] post-plan-review → [STOP HOOK] plan-review (iter 2, sonnet) → ... → [USER STOP] → create-tasks
```

**Task creation flow (auto-triggered after `create-tasks`):**
```
create-tasks → [STOP HOOK] tasks-review (iter 1, opus) → [BLOCK] post-tasks-review → [STOP HOOK] tasks-review (iter 2, sonnet) → ... → [USER STOP] → complete-task
```

**Implementation flow (complete-task):**
```
complete-task → [STOP HOOK] code-review (iter 1, opus) → [BLOCK] post-code-review → [STOP HOOK] code-review (iter 2, sonnet) → ... → [USER STOP] → complete-task (next task, iter resets) → ... → [STOP HOOK] all-code-review (iter 1, opus) → [BLOCK] post-all-code-review → ... → complete
```

**Implementation flow (complete-task-tdd):**
```
complete-task-tdd → [STOP HOOK] code-review (iter 1, opus) → [BLOCK] post-code-review → [STOP HOOK] code-review (iter 2, sonnet) → ... → [USER STOP] → complete-task-tdd (next task, iter resets) → ... → [STOP HOOK] all-code-review (iter 1, opus) → [BLOCK] post-all-code-review → ... → complete
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
- **Two consecutive clean reviews**: The last two review iterations must BOTH pass (find no issues) before the agent advances to the next phase. A single clean review is not sufficient — two in a row are required. The post-review action always sets `next_phase` back to the review phase (e.g. `"code-review"`), letting the reviewer make the determination. The reviewer decides whether there are issues, not the agent that implemented the code.
- **Max review iterations reached** (`phase_iteration > max_reviews` and `max_reviews > 0`): The agent performs a **hard stop** and waits for user input before proceeding. It does NOT auto-advance to the next phase. The user must explicitly decide what to do next.
- **`max_reviews: 0`** (skip all reviews): The hook detects this in step 5a as an early-return — it sets `next_phase` to the advance target, writes state, and approves immediately. No reviews are run, no hard stop occurs, and the workflow proceeds normally to the next stage.

**Model alternation**: `opus` → `sonnet` → `opus` → `sonnet` → ... Model always resets to `opus` at the start of each new review cycle (strongest model first). Each action that enters a review cycle (`new-plan`, `create-tasks`, `complete-task`, `complete-task-tdd`) initializes `review_model: "opus"`.

**Auto-advance boundaries** (require two consecutive clean reviews):
- After plan review passes (2 clean) → **user stop**. The hook sets `next_phase: "create-tasks"` and approves the stop. The agent stops and waits for the user to review the plan and run `continue-plan` (which routes to `create-tasks`). The user gets a chance to read the plan before tasks are created.
- After tasks review passes (2 clean) → **user stop**. The hook sets `next_phase` to the `complete-task` variant (based on `tdd` field) and approves the stop. The user gets a chance to review the tasks before implementation begins.
- After code review passes for a task (2 clean) → **user stop**. The hook sets `next_phase` to the `complete-task` variant and approves the stop. The user gets a chance to review the implemented code before the next task starts. If no tasks remain, the hook sets `next_phase: "all-code-review"` instead.
- After all-code-review passes (2 clean) → set `phase: "complete"`, `next_phase: null`, agent stops.

In all user-stop cases, the agent approves the stop (no block), the user sees the agent stop, reviews the work, and runs `continue-plan` when ready. The `continue-plan` action reads `next_phase` from state and routes to the correct next step.

**Skipping all-code-review for small plans**: For 1-2 task plans where each task was already thoroughly reviewed, the all-code-review cycle may be redundant. To skip it, the user can edit `state.json` after the last task's code review completes and set `phase: "complete"`, `next_phase: null`. This is left as a manual choice rather than automatic to avoid silently skipping reviews for plans that happen to be small but still benefit from cross-task review.

**How the hook detects "clean review":** The CLI is invoked with `--output-format json` and `--json-schema` to return a structured verdict. The schema constrains the output to `{"verdict": "PASS"}` or `{"verdict": "FAIL"}`. The hook extracts the verdict from stdout via `jq -r '.result.verdict'` — no grepping of markdown files, no fragile text matching. The review content itself is still written to disk by the CLI's Write tool (the structured output is separate from the review file). The hook tracks the consecutive clean review count in `state.json` via a `consecutive_clean` field (see schema). When `consecutive_clean >= 2`, the hook advances to the next phase instead of blocking for another post-review.

## Hook Design

### Single Unified Stop Hook

The existing `validate-ground-rules.sh` and the new auto-review logic will be combined into a single Stop hook (`hooks/stop-hook.sh`). This is necessary because Claude Code runs all hooks for the same event **in parallel** — there is no sequential ordering. A single hook avoids race conditions between parallel hooks and ensures validation runs only after the review decision is made.

The hook resolves the plugin root relative to its own location:
```bash
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```
This works because the hook is at `hooks/stop-hook.sh` and actions/ground-rules are one directory up. The resolved absolute path is used in the `claude` CLI prompt strings.

### Hook Input/Output Protocol

The hook receives a JSON payload on **stdin** containing at least:
- `cwd` (string): The working directory of the Claude Code session. The hook `cd`s into this directory before doing anything.
- `stop_hook_active` (boolean): Set to `true` by Claude Code when the stop is triggered by the agent resuming from a hook block (i.e., the hook blocked a previous stop, the agent acted on the block message, and is now trying to stop again). This is a documented Claude Code hook event field — the existing `validate-ground-rules.sh` relies on it (line 22). If this field is `true`, approve immediately to prevent infinite loops.

**Loop detection safety nets**: Two independent mechanisms prevent infinite loops: (1) `stop_hook_active` — the primary defense, provided by Claude Code's hook system; (2) `max_reviews` — the secondary cap, enforced by the hook itself. Together these provide sufficient protection without additional lock-file mechanisms. A lock file was considered but adds complexity (race conditions, cleanup on crash, arbitrary timeouts) without meaningful additional safety given that both existing mechanisms are reliable.

The hook outputs a JSON decision on **stdout** (exit 0 in all cases):
- **Approve (silent):** no output, or `{"suppressOutput": true}` to hide from verbose logs. Exit 0.
- **Approve (with user warning):** `{"systemMessage": "...", "suppressOutput": true}` — exit 0. The `systemMessage` is shown to the **user** in the terminal as a warning. Claude does NOT see it.
- **Block:** `{"decision": "block", "reason": "..."}` — exit 0. The `reason` string is shown to **Claude** as instructions for what to do next. This is the only way to prevent Claude from stopping.
- **Critical failure:** `{"continue": false, "stopReason": "..."}` — exit 0. Stops Claude entirely. `stopReason` is shown to the user, not Claude. Use for unrecoverable errors.

Exit codes:
- **0**: Success. JSON output determines approve/block behavior.
- **2**: Non-blocking error. Stderr shown to user. **Stop hooks cannot block via exit code 2** — only `decision: "block"` with exit 0 can block. We use exit 2 for input validation failures (invalid JSON, bad cwd) where we want the stop to proceed despite the error.
- **Other**: Non-blocking error, shown in verbose mode only.

### Hook Logic

The unified hook follows this logic:

1. Check `stop_hook_active` — if true, approve immediately (prevent infinite loops).
2. Check if `.taskie/plans` exists — if not, approve (not using Taskie)
3. Find the most recently modified plan directory. The heuristic uses `find` with `\( -name "*.md" -o -name "state.json" \) -printf '%T@ %h\n'` to consider both Markdown files and `state.json` modification times. Without including `state.json`, writes to the state file alone (e.g. during automated review cycles) wouldn't update which plan the hook identifies as most recent.
4. Read `state.json` — if missing or malformed, fall through to validation only
5. Check if `next_phase` is a review phase (`plan-review`, `tasks-review`, `code-review`, `all-code-review`):
   a. **Special case: `max_reviews == 0`** — skip all reviews. Set `next_phase` to the advance target (same mapping as step 5g: `"create-tasks"` for plan review, `"complete-task"` or `"complete-task-tdd"` (based on `tdd` field) for tasks/code review, `"complete"` for all-code-review). Set `phase` to the review phase. Write state atomically and **approve** the stop. Do NOT increment `phase_iteration`, do NOT invoke `claude`. This is the "no reviews" escape hatch.
   b. Increment `phase_iteration` (from 0 to 1 for the first review)
   c. Check if incremented `phase_iteration` <= `max_reviews` — if NOT, skip to step 6 (limit reached, hard stop)
   d. Invoke `claude` CLI to perform the review (see CLI invocation below). The review file is named `*-review-${phase_iteration}.md`.
   e. Verify the review file was written to disk. If not (CLI failure), log warning and skip to step 6.
   f. Determine if the review is "clean" (no issues found). The hook extracts the verdict from the CLI's structured JSON output (captured in step 5d): `VERDICT=$(echo "$CLI_OUTPUT" | jq -r '.result.verdict')`. If `VERDICT` is `"PASS"`, the review is clean — increment `consecutive_clean`. If `"FAIL"` or any other value (including parse failure), the review has issues — reset `consecutive_clean` to 0.
   g. If `consecutive_clean >= 2`: auto-advance. Update `state.json` atomically with ALL modified fields: set `phase` to the review phase, `next_phase` to the advance target, `phase_iteration` (incremented), `review_model` (toggled), `consecutive_clean` (incremented). The advance target mapping is: `"create-tasks"` for plan review, `"complete"` for all-code-review. **For tasks review and code review:** the hook reads the `tdd` field from `state.json` to determine the variant — `"complete-task-tdd"` if `tdd` is true, `"complete-task"` if false. For tasks review, this is the advance target directly. **For code review:** the hook also checks `tasks.md` for remaining pending tasks. If tasks remain, `next_phase` is the `complete-task` variant. If no tasks remain, `next_phase: "all-code-review"` with `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0` (entering a new review cycle). This check is done by the hook (not the action file) because the hook is programmatic shell code where `grep`/`awk` reliably determines remaining tasks, whereas the action file is a prompt where detection is fragile. Then **approve** the stop (no block).
   h. If `consecutive_clean < 2`: Update `state.json` atomically (see Atomic State Updates below): set `phase` to the review phase, write the incremented `phase_iteration`, toggle `review_model`, write `consecutive_clean`, set `next_phase` to the corresponding post-review phase. Return a **block** decision with a precise instruction message (see block message template below).
6. If `next_phase` is NOT a review phase, or `phase_iteration > max_reviews`, or `next_phase` is null:
   a. If `phase_iteration > max_reviews AND max_reviews > 0`: this is a **hard stop**. The agent must wait for user input before proceeding. Do NOT auto-advance to the next phase. (Note: `max_reviews == 0` is handled in step 5a as an early-return — it never reaches step 6.)
   b. Run the existing plan structure validation (rules 1-7 from the current `validate-ground-rules.sh`)
   c. If validation passes, approve the stop
   d. If validation fails, block with the validation error

### Claude CLI Invocation

The hook script invokes the `claude` CLI like this:

```bash
REVIEW_LOG=".taskie/plans/${PLAN_ID}/.review-${ITERATION}.log"
VERDICT_SCHEMA='{"type":"object","properties":{"verdict":{"type":"string","enum":["PASS","FAIL"]}},"required":["verdict"]}'

CLI_OUTPUT=$(claude --print \
       --model "${REVIEW_MODEL}" \
       --output-format json \
       --json-schema "$VERDICT_SCHEMA" \
       --dangerously-skip-permissions \
       "Read the ground rules in ${PLUGIN_ROOT}/ground-rules.md, then read the plan in .taskie/plans/${PLAN_ID}/plan.md, then read .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}.md. Now perform the code review action described in ${PLUGIN_ROOT}/actions/code-review.md for this task. Write your review to .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}-review-${ITERATION}.md. Be very critical." \
       2>"$REVIEW_LOG")
```

Key flags:
- `--print` / `-p`: Non-interactive mode. The CLI performs the review using tools and exits.
- `--model "${REVIEW_MODEL}"`: Uses `opus` or `sonnet` alias, which the CLI resolves to the latest version automatically. No manual model ID updates needed.
- `--output-format json`: Returns structured JSON on stdout containing `result`, `session_id`, `cost`, and `usage` fields.
- `--json-schema`: Constrains the CLI's final output to match the verdict schema. The `result` field will contain `{"verdict": "PASS"}` or `{"verdict": "FAIL"}`. This is validated by the CLI — the model cannot return an invalid verdict.
- `--dangerously-skip-permissions`: Required because the subprocess needs to read files, write the review file, and run must-run commands without interactive permission prompts. All tools are available. **Security note**: the subprocess can run arbitrary commands — this is acceptable because it runs in the same project directory as the main agent with the same trust level.
- Stdout is captured to `CLI_OUTPUT` for verdict extraction via `jq`. Stderr is captured to `.review-${ITERATION}.log` (dotfile, hidden by default) for debugging if the CLI subprocess fails. The review content is written to disk via the CLI's Write tool (separate from the JSON on stdout). The log file is cleaned up by the hook after a successful review. On failure, the log persists so the user can inspect it.

**Note:** The `claude` CLI subprocess invoked by the hook does NOT trigger Stop hooks because it runs in `--print` mode (non-interactive). It simply executes tools, produces output, and exits. The `stop_hook_active` field is only relevant for the main agent's session.

The prompt instructs the CLI to read the ground rules, plan, and task file before reviewing — this provides the context that a fresh session lacks.

For **plan reviews**, the prompt is adapted:
```bash
"Read the ground rules in ${PLUGIN_ROOT}/ground-rules.md, then read .taskie/plans/${PLAN_ID}/plan.md. Perform the plan review action described in ${PLUGIN_ROOT}/actions/plan-review.md. Write your review to .taskie/plans/${PLAN_ID}/plan-review-${ITERATION}.md. Be very critical."
```

For **tasks reviews**:
```bash
"Read the ground rules in ${PLUGIN_ROOT}/ground-rules.md, then read .taskie/plans/${PLAN_ID}/tasks.md and the task files: ${TASK_FILE_LIST}. Perform the tasks review action described in ${PLUGIN_ROOT}/actions/tasks-review.md. Write your review to .taskie/plans/${PLAN_ID}/tasks-review-${ITERATION}.md. Be very critical."
```

For **all-code-reviews**:
```bash
"Read the ground rules in ${PLUGIN_ROOT}/ground-rules.md, then read .taskie/plans/${PLAN_ID}/plan.md, .taskie/plans/${PLAN_ID}/tasks.md, and the task files: ${TASK_FILE_LIST}. Perform the all-code-review action described in ${PLUGIN_ROOT}/actions/all-code-review.md. Write your review to .taskie/plans/${PLAN_ID}/all-code-review-${ITERATION}.md. Be very critical."
```

All four prompts use the same `--output-format json --json-schema "$VERDICT_SCHEMA"` flags. The verdict is returned as structured JSON on stdout — the prompt no longer needs to instruct the model to include a VERDICT line in the markdown. The `--json-schema` flag constrains the model's final response to `{"verdict": "PASS"}` or `{"verdict": "FAIL"}`, which is schema-validated by the CLI itself.

**Note:** `TASK_FILE_LIST` is constructed by the hook from `tasks.md` — it extracts numeric task IDs from the Id column (column 2) of the table and expands them to `.taskie/plans/${PLAN_ID}/task-{N}.md` paths. This avoids the `task-*.md` glob which would also match review and post-review files (e.g. `task-1-review-2.md`, `task-1-post-review-1.md`), potentially overloading the CLI subprocess context window. The hook builds this list with:
```bash
TASK_FILE_LIST=$(grep '^|' ".taskie/plans/${PLAN_ID}/tasks.md" | tail -n +3 | awk -F'|' '{gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9]+$/) printf ".taskie/plans/'${PLAN_ID}'/task-%s.md ", $2}')
```

The `grep '^|'` restricts to table rows only (lines starting with `|`). The `tail -n +3` skips the header and separator rows. The `awk` command splits on `|`, extracts column 2 (the Id column), strips whitespace, validates it's numeric, and constructs the full file path. This approach works with the current `tasks.md` format where task IDs are numeric values in the Id column, not literal filename strings.

**Empty list handling**: If `TASK_FILE_LIST` is empty (e.g. `tasks.md` doesn't exist, is empty, or has no task references), the hook logs a warning and skips the review (approves the stop). For **code-review** of a single task, the hook uses `current_task` from `state.json` directly to construct the file path (`task-${current_task}.md`) rather than parsing `tasks.md` — the task ID is already known. `TASK_FILE_LIST` is only needed for tasks-review and all-code-review prompts.

### Block Message Template

When the hook blocks the stop to trigger post-review, the `reason` field must be precise enough for the main agent to know exactly what to do:

**For code review:**
```
A code review (iteration ${ITERATION}) has been written to .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}-review-${ITERATION}.md by an independent reviewer. Read this review file and perform the post-code-review action: address all issues, update the code, then create .taskie/plans/${PLAN_ID}/task-${CURRENT_TASK}-post-review-${ITERATION}.md documenting your fixes. AFTER completing all post-review work and writing the post-review file, update state.json atomically (read current file, modify only phase and next_phase, write complete JSON back): set phase to "post-code-review", set next_phase to "code-review". Keep all other fields (max_reviews, current_task, phase_iteration, review_model, consecutive_clean) unchanged. Write via temp file then mv to prevent corruption. Update tasks.md and push to remote. (To stop the review loop, set next_phase to null in state.json.)
```

**For plan review:**
```
A plan review (iteration ${ITERATION}) has been written to .taskie/plans/${PLAN_ID}/plan-review-${ITERATION}.md by an independent reviewer. Read this review file and perform the post-plan-review action: address all issues in plan.md, then create .taskie/plans/${PLAN_ID}/plan-post-review-${ITERATION}.md documenting your fixes. AFTER completing all post-review work and writing the post-review file, update state.json atomically (read current file, modify only phase and next_phase, write complete JSON back): set phase to "post-plan-review", set next_phase to "plan-review". Keep all other fields (max_reviews, current_task, phase_iteration, review_model, consecutive_clean) unchanged. Write via temp file then mv to prevent corruption. Push to remote. (To stop the review loop, set next_phase to null in state.json.)
```

**For tasks review:**
```
A tasks review (iteration ${ITERATION}) has been written to .taskie/plans/${PLAN_ID}/tasks-review-${ITERATION}.md by an independent reviewer. Read this review file and perform the post-tasks-review action: address all issues in tasks.md and task files, then create .taskie/plans/${PLAN_ID}/tasks-post-review-${ITERATION}.md documenting your fixes. AFTER completing all post-review work and writing the post-review file, update state.json atomically (read current file, modify only phase and next_phase, write complete JSON back): set phase to "post-tasks-review", set next_phase to "tasks-review". Keep all other fields (max_reviews, current_task, phase_iteration, review_model, consecutive_clean) unchanged. Write via temp file then mv to prevent corruption. Push to remote. (To stop the review loop, set next_phase to null in state.json.)
```

**For all-code-review:**
```
An all-code review (iteration ${ITERATION}) has been written to .taskie/plans/${PLAN_ID}/all-code-review-${ITERATION}.md by an independent reviewer. Read this review file and perform the post-all-code-review action: address all issues across all tasks, then create .taskie/plans/${PLAN_ID}/all-code-post-review-${ITERATION}.md documenting your fixes. AFTER completing all post-review work and writing the post-review file, update state.json atomically (read current file, modify only phase and next_phase, write complete JSON back): set phase to "post-all-code-review", set next_phase to "all-code-review". Keep all other fields (max_reviews, current_task, phase_iteration, review_model, consecutive_clean) unchanged. Write via temp file then mv to prevent corruption. Update tasks.md and push to remote. (To stop the review loop, set next_phase to null in state.json.)
```

### Atomic State Updates

All writes to `state.json` MUST be atomic to prevent corruption from crashes or interrupts. The pattern:

```bash
# Read current state
STATE=$(cat ".taskie/plans/${PLAN_ID}/state.json")

# Modify fields using jq
NEW_STATE=$(echo "$STATE" | jq '.phase = "code-review" | .next_phase = "post-code-review" | .phase_iteration = 1')

# Write to temp file and atomically rename
TMPFILE=$(mktemp ".taskie/plans/${PLAN_ID}/.state.json.XXXXXX")
echo "$NEW_STATE" > "$TMPFILE"
mv "$TMPFILE" ".taskie/plans/${PLAN_ID}/state.json"
```

Key properties:
- **`mv` is atomic on POSIX filesystems** — the file is either fully replaced or not at all. No partial writes.
- **Temp file is in the same directory** — ensures `mv` is a rename (same filesystem), not a copy.
- **Always read-modify-write** — never construct a new JSON from scratch. Read the current state, modify only the fields that need changing, write all fields back. This prevents field clobbering.

This pattern applies to BOTH the hook script and the main agent. The main agent should use `jq` or equivalent JSON manipulation to update specific fields without overwriting others. The block message templates instruct the agent to follow this pattern.

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
   - `next_phase` = `"code-review"` / `"plan-review"` / `"tasks-review"` / `"all-code-review"` → the hook will handle this on the next stop. The agent uses a two-level heuristic to determine if there is outstanding work:
     1. **Check `phase`**: if `phase` is a post-review value (`"post-code-review"`, `"post-plan-review"`, `"post-tasks-review"`, `"post-all-code-review"`), the post-review was completed and the agent should simply stop to trigger the hook.
     2. **Check artifact completeness** (when `phase` is NOT a post-review value): the check depends on the review type:
        - **For code-review/all-code-review**: read the current task file (`task-{current_task}.md`) and check whether all subtasks are marked complete. If all complete, implementation finished normally — simply stop. If incomplete, agent crashed mid-implementation — execute `continue-task.md`.
        - **For plan-review**: verify `plan.md` exists and appears complete (contains an `## Overview` heading or is > 50 lines). If incomplete or missing, the plan was half-written when the agent crashed — execute `new-plan.md` with a note to continue the existing plan content. If complete, simply stop to trigger the hook.
        - **For tasks-review**: verify `tasks.md` exists and contains actual table rows (at least one `|` line after the header). If incomplete or missing, execute `create-tasks.md` to finish. If complete, simply stop.
   - `next_phase` = `"complete-task"` / `"complete-task-tdd"` → execute the next task with the automation entry point (which writes `next_phase: "code-review"` after implementation, keeping the loop going)
   - `next_phase` = `"create-tasks"` → execute `create-tasks.md`
   - `next_phase` = `"complete"` → set `phase: "complete"`, `next_phase: null`, inform user all tasks are done

   **When `next_phase` is null** (standalone command was interrupted):
   - `phase` = `"continue-task"` or `"next-task"` or `"next-task-tdd"` or `"complete-task"` or `"complete-task-tdd"` → execute `continue-task.md`
   - `phase` = `"complete"` → inform user all tasks are done
   - **Catch-all**: any other `phase` value (e.g. `"code-review"`, `"plan-review"`, `"post-code-review"`) with `next_phase: null` → inform the user of the current state and ask what to do next. These are standalone commands that were interrupted mid-execution. Since there's no automated follow-up intended (`next_phase` is null), the agent should display the current `phase` and `current_task` values and let the user decide whether to re-run the interrupted command, move to a different phase, or take another action. Git history fallback would produce confusing results here since the state file exists but the automation intent is ambiguous.

   **Falls back to git history** only if `state.json` doesn't exist (backwards compatibility with pre-stateful plans).

2. **`new-plan.md`** — After creating `plan.md`, initializes `state.json` with all 8 fields: `max_reviews: 8`, `current_task: null`, `phase: "new-plan"`, `next_phase: "plan-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`, `tdd: false`. This is the only action that constructs `state.json` from scratch (all other actions read-modify-write). Always auto-triggers plan review — there's no scenario where a plan shouldn't be reviewed. **Note to users:** After running `/taskie:new-plan`, an automated review cycle begins immediately. To break out early, set `next_phase: null` in `state.json`.

3. **`create-tasks.md`** — After creating tasks, updates `state.json` (read-modify-write): set `phase: "create-tasks"`, `current_task: null`, `next_phase: "tasks-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`. Preserve `max_reviews` from existing state. Always auto-triggers tasks review. Also adds `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` reference (currently missing from this action).

4. **`next-task.md`** / **`next-task-tdd.md`** — After implementation, writes `state.json` with `phase: "next-task"` (or `"next-task-tdd"`), sets `current_task`, sets `next_phase: null`. These are standalone commands — they do NOT trigger auto-review and contain NO conditional logic. They always set `next_phase: null`. The transition to `all-code-review` when no tasks remain is handled by the hook (see step 5g), not by the action file. This keeps `next-task.md` simple and avoids dual code paths within a single action.

5. **`complete-task.md`** / **`complete-task-tdd.md`** — These are the automation entry points. They contain their OWN implementation instructions (inlining the relevant parts of `next-task.md` / `next-task-tdd.md`) rather than delegating. This eliminates the fragile cross-prompt conditional where `next-task.md` would need to detect whether it was invoked standalone or as a delegate. The duplication is small (~10 lines of implementation instructions) and the reliability gain is significant. `complete-task` writes `state.json` ONCE after implementation finishes: `max_reviews` (preserved from existing state), `current_task: "{id}"`, `phase: "complete-task"`, `next_phase: "code-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`, `tdd: false`. `complete-task-tdd` writes the same but with `phase: "complete-task-tdd"` and `tdd: true`. When the main agent then tries to stop, the hook takes over and runs the review loop. The action itself no longer contains a Phase 2/3/4 loop — the hook handles it. **Note:** This replaces the existing 3-cycle review cap in `complete-task.md` with the global `max_reviews` setting (default 8). The cap is now enforced by the hook, not by the action prompt. The higher default allows more thorough automated review cycles since the two-consecutive-clean exit condition typically terminates earlier.

6. **`code-review.md`** — When invoked standalone, writes review and sets `next_phase: null`. When invoked by the hook, the hook manages the state transitions (the action itself doesn't need to update `state.json` since the hook does it).

7. **`post-code-review.md`** — After applying fixes, ALWAYS sets `next_phase: "code-review"` (when in automated flow) to loop back for another review. The reviewer — not the implementer — decides whether issues remain. The exit condition is two consecutive clean reviews from the reviewer subprocess. When invoked standalone (no automation), sets `next_phase: null`. The determination of standalone vs. automated is based on whether `phase_iteration` is non-null in `state.json`.

8. **`plan-review.md`** / **`post-plan-review.md`** — Same pattern. Standalone sets `next_phase: null`. When in automated flow, `post-plan-review` ALWAYS sets `next_phase: "plan-review"` to loop back. The reviewer decides when the plan is ready (two consecutive clean reviews required to advance to `create-tasks`).

9. **`tasks-review.md`** / **`post-tasks-review.md`** — Same pattern. `post-tasks-review` ALWAYS sets `next_phase: "tasks-review"` in automated flow. The reviewer decides when tasks are ready (two consecutive clean reviews required to advance to `next-task`).

10. **`continue-task.md`** — Updates `state.json` with `phase: "continue-task"`, preserving the existing `next_phase` value. Before updating, the action reads `next_phase` from the current `state.json`. If `next_phase` is already set to a review phase (e.g. `"code-review"`), it was set by a prior automation command and is preserved unchanged. If `next_phase` is null, it's standalone mode — keep it null. This makes `continue-task` a transparent pass-through for `next_phase`.

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

A new validation rule (rule 8) is added: if `state.json` exists, validate that it is valid JSON and contains the required fields (`phase`, `next_phase`, `review_model`, `max_reviews`, `consecutive_clean`, `tdd`). If validation fails, log a warning but do NOT block the stop — a corrupt state file should not prevent the user from stopping.

**Forward-compatibility**: The hook reads all `state.json` fields using `jq` default operators (e.g. `(.consecutive_clean // 0)`, `(.max_reviews // 8)`, `(.review_model // "opus")`, `(.tdd // false)`) so that missing fields from older state files are handled gracefully with sensible defaults. This avoids the need for a formal schema version number — new fields can be added in future versions without breaking existing state files.

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
│   ├── test-stop-hook-edge-cases.sh             # NEW: edge cases & integration tests
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
# MOCK_CLAUDE_VERDICT controls the verdict line: "PASS" or "FAIL" (default: "FAIL")
if [ -n "${MOCK_CLAUDE_REVIEW_DIR:-}" ] && [ -n "${MOCK_CLAUDE_REVIEW_FILE:-}" ]; then
    VERDICT="${MOCK_CLAUDE_VERDICT:-FAIL}"
    if [ "$VERDICT" = "PASS" ]; then
        cat > "${MOCK_CLAUDE_REVIEW_DIR}/${MOCK_CLAUDE_REVIEW_FILE}" << 'REVIEW'
# Review
No issues found. The implementation looks good.

VERDICT: PASS
REVIEW
    else
        cat > "${MOCK_CLAUDE_REVIEW_DIR}/${MOCK_CLAUDE_REVIEW_FILE}" << 'REVIEW'
# Review
## Issues Found
1. Minor: variable naming inconsistency

VERDICT: FAIL
REVIEW
    fi
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
| 1 | Trigger code review | `{phase: "next-task", next_phase: "code-review", phase_iteration: 0, max_reviews: 8, review_model: "opus", current_task: "1", consecutive_clean: 0}` | block, reason contains "task-1-review-1.md", mock claude invoked |
| 2 | Trigger plan review | `{phase: "new-plan", next_phase: "plan-review", phase_iteration: 0, max_reviews: 8, review_model: "opus", current_task: null, consecutive_clean: 0}` | block, reason contains "plan-review-1.md", mock claude invoked |
| 3 | Trigger tasks review | `{phase: "create-tasks", next_phase: "tasks-review", phase_iteration: 0, max_reviews: 8, review_model: "opus", current_task: null, consecutive_clean: 0}` | block, reason contains "tasks-review-1.md", mock claude invoked |
| 4 | next_phase is null (standalone) | `{phase: "next-task", next_phase: null, ...}` | approve (falls through to validation), mock claude NOT invoked |
| 5 | next_phase is post-code-review (not a review phase) | `{phase: "code-review", next_phase: "post-code-review", ...}` | approve (post-review is done by the main agent, not the hook) |
| 6 | Max reviews reached (hard stop) | `{phase: "post-code-review", next_phase: "code-review", phase_iteration: 8, max_reviews: 8, ...}` | approve (falls through to validation), mock claude NOT invoked, agent must wait for user input |
| 7 | Max reviews with custom limit | `{..., phase_iteration: 3, max_reviews: 3, ...}` | approve (limit reached, hard stop) |
| 8 | state.json missing | no state.json file | approve (falls through to validation only) |
| 9 | state.json malformed | `"not json"` | approve (falls through to validation only), warning logged |
| 10 | next_phase is "complete-task" (auto-advance, not review) | `{phase: "post-code-review", next_phase: "complete-task", ...}` | approve (not a review phase) |
| 11 | next_phase is "create-tasks" (auto-advance, not review) | `{phase: "post-plan-review", next_phase: "create-tasks", ...}` | approve (not a review phase) |
| 12 | Trigger all-code-review | `{phase: "post-code-review", next_phase: "all-code-review", phase_iteration: 0, ..., consecutive_clean: 0}` | block, reason contains "all-code-review-1.md" |
| 13 | One clean review — not enough to advance | `MOCK_CLAUDE_VERDICT=PASS`, `consecutive_clean: 0` | block (consecutive_clean becomes 1, still < 2), reason contains post-review instruction |
| 14 | Two consecutive clean reviews — auto-advance | `MOCK_CLAUDE_VERDICT=PASS`, `consecutive_clean: 1` | approve (consecutive_clean becomes 2 >= 2), next_phase set to advance target |
| 15 | Clean then dirty resets counter | `MOCK_CLAUDE_VERDICT=FAIL`, `consecutive_clean: 1` | block (consecutive_clean resets to 0), reason contains post-review instruction |

### Test Suite 3: State Transitions (test-stop-hook-state-transitions.sh)

Tests that the hook correctly updates `state.json` after running a review. All tests use the mock `claude` CLI.

| # | Test | Initial state.json | Expected state.json after hook |
|---|------|--------------------|---------------------------------|
| 1 | Code review: phase updated | `{phase: "next-task", next_phase: "code-review", phase_iteration: 0, review_model: "opus", current_task: "1", consecutive_clean: 0}` | `{phase: "code-review", next_phase: "post-code-review", phase_iteration: 1, review_model: "sonnet", current_task: "1", consecutive_clean: 0}` (`MOCK_CLAUDE_VERDICT=FAIL`) |
| 2 | Plan review: phase updated | `{phase: "new-plan", next_phase: "plan-review", phase_iteration: 0, review_model: "opus", current_task: null, consecutive_clean: 0}` | `{phase: "plan-review", next_phase: "post-plan-review", phase_iteration: 1, review_model: "sonnet", current_task: null, consecutive_clean: 0}` |
| 3 | Tasks review: phase updated | `{phase: "create-tasks", next_phase: "tasks-review", phase_iteration: 0, review_model: "opus", consecutive_clean: 0}` | `{phase: "tasks-review", next_phase: "post-tasks-review", phase_iteration: 1, review_model: "sonnet", consecutive_clean: 0}` |
| 4 | Model alternation opus→sonnet | `{..., review_model: "opus", phase_iteration: 0}` | `{..., review_model: "sonnet", phase_iteration: 1}` |
| 5 | Model alternation sonnet→opus | `{..., review_model: "sonnet", phase_iteration: 1, next_phase: "code-review"}` | `{..., review_model: "opus", phase_iteration: 2}` |
| 6 | Iteration increment | `{..., phase_iteration: 4, next_phase: "code-review"}` | `{..., phase_iteration: 5}` |
| 7 | max_reviews preserved | `{..., max_reviews: 5}` | `{..., max_reviews: 5}` (unchanged) |
| 8 | current_task preserved | `{..., current_task: "3"}` | `{..., current_task: "3"}` (unchanged) |
| 9 | consecutive_clean incremented on clean review | `{..., consecutive_clean: 0}`, `MOCK_CLAUDE_VERDICT=PASS` | `{..., consecutive_clean: 1}` |
| 10 | consecutive_clean reset on review with issues | `{..., consecutive_clean: 1}`, `MOCK_CLAUDE_VERDICT=FAIL` | `{..., consecutive_clean: 0}` |
| 11 | Two clean code reviews → auto-advance to complete-task | `{..., consecutive_clean: 1, next_phase: "code-review", tdd: false}`, `MOCK_CLAUDE_VERDICT=PASS` | `{..., next_phase: "complete-task"}` (auto-advanced, not "post-code-review") |
| 12 | Two clean plan reviews → auto-advance to create-tasks | `{..., consecutive_clean: 1, next_phase: "plan-review"}`, `MOCK_CLAUDE_VERDICT=PASS` | `{..., next_phase: "create-tasks"}` |
| 13 | Two clean tasks reviews → auto-advance to complete-task | `{..., consecutive_clean: 1, next_phase: "tasks-review", tdd: false}`, `MOCK_CLAUDE_VERDICT=PASS` | `{..., next_phase: "complete-task"}` |
| 14 | Two clean all-code-reviews → auto-advance to complete | `{..., consecutive_clean: 1, next_phase: "all-code-review"}`, `MOCK_CLAUDE_VERDICT=PASS` | `{..., next_phase: "complete"}` |
| 15 | Auto-advance writes all modified fields | `{..., consecutive_clean: 1, phase_iteration: 3, review_model: "opus"}`, `MOCK_CLAUDE_VERDICT=PASS` | `{..., phase_iteration: 4, review_model: "sonnet", consecutive_clean: 2}` (all fields updated, not stale) |
| 16 | Atomic write: state.json is valid JSON after update | any review trigger | read state.json after hook — must be valid JSON parseable by `jq` with all 8 required fields present |

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
| 8 | All-code-review prompt contains all-code-review reference | all-code-review | prompt contains `all-code-review.md` and `all-code-review-` |
| 9 | Review file written to correct path | code review for task 2, iteration 3 | file `task-2-review-3.md` exists in plan directory |
| 10 | Claude CLI not on PATH | remove mock from PATH | hook approves (falls through to validation), warning logged to stderr |
| 11 | Claude CLI fails (exit 1) | `MOCK_CLAUDE_EXIT_CODE=1` | hook approves (falls through to validation), warning logged |
| 12 | Claude CLI fails to write review file | `MOCK_CLAUDE_REVIEW_DIR` not set (mock writes nothing) | hook approves (falls through to validation), warning logged |
| 13 | Claude CLI timeout | `MOCK_CLAUDE_DELAY=5` with hook timeout shorter | hook approves (falls through), warning logged |
| 14 | CLI uses structured JSON output | any review trigger | args contain `--output-format json` and `--json-schema` |

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
| 8 | max_reviews is 0 (skip reviews, advance state) | `{..., max_reviews: 0, phase_iteration: 0, next_phase: "code-review", tdd: false}` | approve, state.json updated: `next_phase: "complete-task"` (auto-advanced to advance target), mock claude NOT invoked, `phase_iteration` unchanged at 0 |
| 9 | Backwards compatibility: no state.json, valid plan | plan.md + tasks.md, no state.json | approve (validation only, no auto-review) |
| 10 | Full model alternation across 4 iterations | invoke hook 4 times with mock CLI, simulating post-review between each | MOCK_CLAUDE_LOG shows: opus, sonnet, opus, sonnet. state.json review_model alternates correctly after each. |
| 11 | Two consecutive clean reviews auto-advance (integration) | invoke hook twice with `MOCK_CLAUDE_VERDICT=PASS` (consecutive_clean: 0 → 1 → 2) | first hook blocks, second hook approves and sets next_phase to advance target |
| 12 | Atomic write: no temp files left behind | trigger review, check plan directory | no `.state.json.*` temp files remain after hook completes |

### Expected Test Counts

| Test suite | Count |
|------------|-------|
| Validation rules (ported + new) | 17 |
| Auto-review logic | 15 |
| State transitions | 16 |
| CLI invocation | 14 |
| Block message templates | 6 |
| Edge cases & integration | 12 |
| **Total** | **80** |

### Test Execution

All tests must pass with `make test` before any commit. Tests are exempt from versioning (per CLAUDE.md).

**Test distribution strategy**: Tests should be written alongside their corresponding feature implementation, not deferred to a separate test-only task. For example, the task implementing hook auto-review logic should also write test suite 2 (auto-review logic tests). This ensures each feature is tested as it's built and prevents a single massive test task at the end. The test infrastructure (shared helpers, mock claude, test runner updates) should be its own task since other tasks depend on it.

Tests that invoke the mock `claude` CLI must clean up the mock from PATH after each test case to avoid polluting subsequent tests. Each test creates its own `mktemp -d` and cleans it in a trap.

No real API calls are ever made during testing. The mock `claude` script is the only "CLI" that runs.

## Risk Assessment

1. **Hook timeout**: The unified Stop hook timeout is set to 600 seconds (10 minutes). If the `claude` CLI subprocess exceeds this, the hook logs a warning and allows the stop rather than blocking indefinitely.

2. **Claude CLI availability**: The hook checks `command -v claude` before attempting to invoke it. If `claude` is not on PATH, the hook skips the review, logs a warning, and falls through to validation only.

3. **Concurrent state writes**: The hook and the main agent never write `state.json` at the same time because the hook runs synchronously during the Stop event — the main agent is paused while the hook executes. The sequence is: main agent writes → tries to stop → hook fires (agent paused) → hook writes → hook returns → agent resumes → agent writes. No overlap. All writes use the atomic temp-file-then-mv pattern (see Atomic State Updates).

4. **Infinite loops**: The `stop_hook_active` flag prevents the hook from firing recursively. The `max_reviews` limit (default 8) caps the review loop. When `phase_iteration > max_reviews`, the agent performs a hard stop and waits for user input — it does NOT auto-advance.

5. **State file corruption prevention and recovery**: All writes use atomic temp-file-then-mv, so partial writes cannot occur. If `state.json` is missing or contains invalid JSON (e.g., from external manual editing), the `continue-plan` action falls back to git history analysis (pre-stateful behavior). The hook also handles this gracefully — if it can't read `state.json`, it skips the review and runs validation only.

6. **Crash between hook block and agent post-review**: If the main agent crashes after the hook blocks the stop but before the agent completes post-review, `state.json` will show `phase: "<review-type>"` with `next_phase: "post-<review-type>"`. When the user resumes with `continue-plan`, it reads this state and routes to the post-review action. The review file is already on disk (written by the hook's subprocess), so the agent can pick up where it left off. This is a safe recovery path.

7. **Destructive reviews**: There is no rollback mechanism if a review suggests destructive changes. The `max_reviews` limit is the safety valve — after 8 iterations, the agent stops and requests human input. Each subtask completion is committed to git, so `git revert` or `git reset` can undo damage. The post-review action should be instructed to exercise judgment and skip suggestions that would remove working functionality.

8. **User escape hatch**: To break the auto-review loop mid-workflow, the user can edit `state.json` and set `"next_phase": null`. The hook will see null and allow the stop on the next attempt. Alternatively, setting `"max_reviews": 0` disables all reviews. These options should be mentioned in the block message template as a brief note, e.g.: `"(To stop the review loop, set next_phase to null in state.json.)"`

9. **Worst-case review cost**: With `max_reviews: 8` (default), the worst-case automated review count for a plan with N tasks is: 8 (plan reviews) + 8 (tasks reviews) + 8×N (code reviews per task) + 8 (all-code-reviews) = 24 + 8N. For a 10-task plan, this is 104 automated `claude` CLI invocations. At the 10-minute timeout ceiling, this is ~17 hours of unattended automated reviews. In practice, the two-consecutive-clean exit condition terminates most review cycles after 2-4 iterations, bringing the typical count much lower (closer to 2×4 + 2N). Users who want tighter control should lower `max_reviews` — setting it to 4 halves the worst case while still being generous for most plans.
