# Plan Review 1 — Stateful Taskie

## Critical Issues

### 1. Claude CLI invocation is wrong

The plan shows:
```bash
claude --model claude-sonnet-4-5-20250929 \
       --print \
       --no-input \
       "Perform the action..."
```

**Problems:**
- There is no `--no-input` flag. The correct flag for non-interactive mode is `--print` / `-p`, which already implies non-interactive.
- `--print` sends output to stdout, it does NOT write to a file. The hook script would need to redirect stdout to the review file explicitly (e.g. `> review-file.md`) or use a prompt that instructs the `claude` CLI to write the file itself using its Write tool.
- The model aliases should use shorthand (`sonnet`, `opus`) or the precise model IDs. The plan mixes approaches — `claude-sonnet-4-5-20250929` is an exact model ID, but the plan says "latest Sonnet" and "latest Opus". Using aliases (`--model sonnet`, `--model opus`) is more future-proof and matches the stated intent.
- The prompt passed as a positional argument needs to include enough context for the `claude` CLI to actually perform the review. The CLI starts a fresh session with no prior context — it doesn't know the project, the codebase, or the plan. The prompt needs to instruct it to read the relevant files first.

**Recommendation:** Use `--print` with stdout redirection to the review file. Use model aliases. Craft a self-contained prompt that instructs the CLI to read ground-rules, plan, task file, and then perform the review.

### 2. Hook ordering is parallel, not sequential

The plan states hooks execute in order:
1. `auto-review.sh`
2. `validate-ground-rules.sh`

But Claude Code hooks for the same event run **in parallel**, not sequentially. There is no explicit ordering mechanism. This means both hooks fire simultaneously, and `validate-ground-rules.sh` could block the stop independently of `auto-review.sh`, or both could try to block, leading to confusing behavior.

**Recommendation:** Merge the validation logic into `auto-review.sh` or have `auto-review.sh` be the sole Stop hook that internally calls the validation after deciding whether to run a review. Alternatively, keep them separate but ensure `validate-ground-rules.sh` defers when a review is in progress (check `state.json` to see if we're mid-review-cycle).

### 3. `plan_phase` and `phase` are redundant / confusing

The state file has both:
- `plan_phase`: high-level stage (`"planning"`, `"implementation"`, etc.)
- `phase`: current action (`"new-plan"`, `"code-review"`, etc.)

The `plan_phase` can always be derived from `phase`:
- `phase` in `["new-plan"]` → planning
- `phase` in `["plan-review", "post-plan-review"]` → plan-review
- `phase` in `["create-tasks"]` → task-creation
- `phase` in `["tasks-review", "post-tasks-review"]` → task-review
- `phase` in `["next-task", "next-task-tdd", "code-review", "post-code-review", "continue-task"]` → implementation
- `phase` = `"complete"` → complete

Having both fields creates a synchronization burden — every action must update both, and they can get out of sync. This is unnecessary complexity.

**Recommendation:** Remove `plan_phase`. Derive it from `phase` if needed.

### 4. Auto-advance after planning and task creation phases is underspecified

The plan describes auto-advance for the implementation flow (task done → next task), but is vague about what happens when:
- Plan review passes → should it auto-advance to `create-tasks`? Or wait for the user?
- Tasks review passes → should it auto-advance to `next-task`? Or wait for the user?

The state transition diagrams show `plan-review → ... → create-tasks` and `tasks-review → ... → next-task`, but the plan never explicitly says whether these transitions happen automatically (via the hook) or require user invocation.

The clarification says "Plan review, tasks review, AND code review are all automated via hooks during their respective workflows" — but what triggers the plan-review workflow? The user runs `/taskie:new-plan`, then what? Does the hook auto-trigger plan review? Or does the user need to run `/taskie:plan-review` manually? The plan doesn't make this clear.

**Recommendation:** Be explicit: after `new-plan` completes, the state sets `next_phase: "plan-review"`. When the main agent tries to stop, the hook sees `next_phase` is a review phase, runs the review, and blocks. This means `new-plan` + all plan review cycles happen in one continuous session without user intervention. If this is intended, say so clearly. If not, define the breakpoints where the user must intervene.

### 5. `complete-task` simplification breaks the existing contract

The plan says: "The action now only handles the implementation phase. The hook handles review automation."

This means `complete-task.md` would become effectively identical to `next-task.md` — both just do implementation. The only difference would be what happens at the Stop boundary. But the user might invoke `next-task` directly (without wanting auto-review), or invoke `complete-task` (wanting auto-review). How does the hook know which command the user invoked?

The hook reads `state.json`, but who writes `next_phase: "code-review"` into `state.json`? If `next-task.md` writes it, then even manual `next-task` invocations trigger auto-review. If only `complete-task.md` writes it, then we need two nearly-identical action files with a one-line difference.

**Recommendation:** The plan needs to clearly define which actions set `next_phase` to a review phase (triggering automation) vs. which leave it null (no automation). The `complete-task` action should set `next_phase: "code-review"`, while `next-task` used standalone should set `next_phase: null`. This distinction needs to be explicit.

### 6. The `--print` flag and tool usage conflict

When invoking `claude --print`, the CLI runs in non-interactive mode. But to perform a meaningful code review, the `claude` CLI subprocess needs to:
- Read the plan file
- Read the task file
- Read the actual source code changed
- Run must-run commands (the `code-review.md` action says "Double check ALL the must-run commands by running them")
- Write the review file to disk

The `--print` flag does support tool usage, but the plan doesn't discuss:
- What permission mode the subprocess runs in (it needs `--dangerously-skip-permissions` or `--permission-mode bypassPermissions` to run commands and write files without prompting)
- What tools should be available to the subprocess
- What `--allowedTools` should be set

This is a significant oversight — without permissions bypass, the `claude` subprocess will hang waiting for permission prompts that no one can answer.

**Recommendation:** Add `--dangerously-skip-permissions` or `--permission-mode bypassPermissions` to the CLI invocation. Document the security implications (the subprocess can run arbitrary commands). Consider limiting tools with `--allowedTools "Read Grep Glob Write Bash"`.

### 7. State corruption risk is higher than assessed

The plan mentions "only the hook writes during review phases, only the main agent writes during other phases" as mitigation. But consider the sequence:

1. Main agent finishes implementation, writes `state.json` with `next_phase: "code-review"`
2. Main agent tries to stop
3. Hook fires, reads `state.json`, starts `claude` CLI subprocess
4. `claude` subprocess performs review, writes review file
5. Hook updates `state.json` with new phase
6. Hook returns `{"decision": "block", "reason": "..."}`
7. Main agent resumes, performs post-review, updates `state.json`

Steps 5 and 7 could overlap if the hook response and main agent state write happen close together. More importantly: what if the main agent crashes between step 6 and step 7? The `state.json` says we're in `post-code-review` but no post-review was actually done. The `continue-plan` action would try to resume a post-review from a clean slate — possible but fragile.

**Recommendation:** Consider atomic state transitions. The hook should write `state.json` only after the review file is confirmed written. The main agent should write `state.json` only after post-review is committed. Document the recovery strategy for each failure point.

### 8. Missing: `continue-task` phase in state transitions

The plan lists all phases but doesn't include `continue-task` in the state transitions. The `continue-task.md` action exists and is used when a task implementation was interrupted. The state file should support a `phase: "continue-task"` state, and `continue-plan` should route to `continue-task` when appropriate.

**Recommendation:** Add `continue-task` to the state transition diagrams and the phase enum.

## Moderate Issues

### 9. `current_subtask` tracking is impractical

The plan includes `current_subtask` in the state file. But subtask tracking is granular — subtasks complete one by one during a `next-task` execution, and the main agent already tracks subtask status in the task Markdown files. The hook doesn't need to know the current subtask — it only cares about the task-level phase.

Having the main agent update `state.json` for every subtask completion adds unnecessary writes and synchronization burden. Subtask granularity is already tracked in `task-{id}.md`.

**Recommendation:** Remove `current_subtask` from the state file. Task-level granularity is sufficient for the hook and for `continue-plan`.

### 10. The hook blocks the stop, but with what message?

When the hook returns `{"decision": "block", "reason": "..."}`, the `reason` string is fed back to the main agent as context. The plan doesn't specify what this reason message should say. It needs to be precise enough that the main agent knows to:
1. Read the review file that was just written
2. Perform the `post-code-review` action
3. Update `state.json` when done

This is essentially a prompt injection into the main agent's context. If the message is vague (e.g. "Please perform post-review"), the agent may not know which file to read or what action to follow.

**Recommendation:** Define the exact `reason` template, e.g.: `"A code review has been written to .taskie/plans/{plan-id}/task-{task-id}-review-{n}.md. Perform the action described in {PLUGIN_ROOT}/actions/post-code-review.md for plan directory .taskie/plans/{plan-id}/ and task {task-id}. Update state.json when complete."`

### 11. Max reviews should cap per-phase, not just per-task

The plan says `max_reviews` is "Maximum review iterations per reviewable phase (default 8)" in the field definition, but then says "maximum code reviews per task, let's default it to 8" in the original prompt. These are different things:
- Per-task: 8 code review iterations for task 3, then 8 more for task 4
- Per-phase globally: 8 total code review iterations across all tasks

The field definition (per reviewable phase) seems correct but should be clarified — does the `phase_iteration` counter reset when moving to a new task?

**Recommendation:** Clarify that `phase_iteration` resets to 1 when `current_task` changes. The limit is 8 review iterations per task per phase type.

### 12. Model IDs will go stale

The plan uses `"opus"` and `"sonnet"` as model identifiers in the state file. The hook then needs to map these to actual `--model` flags. Using aliases is good, but the mapping should be documented. Also, what happens when a new model generation drops? (e.g., Claude 5.0). Who updates the model mapping?

**Recommendation:** Use the Claude CLI's built-in aliases (`--model opus`, `--model sonnet`) which always resolve to the latest version. Document this in the plan so it's clear no manual updates are needed when new models release.

### 13. Codex updates scope is questionable

The plan says Codex prompts will be updated to read/write `state.json`. But Codex CLI uses `$ARGUMENTS` as a text substitution mechanism and runs prompts as plain text — it doesn't have file I/O capabilities built into the prompt system. The Codex agent would need to be explicitly instructed to read/write JSON, which is fragile without the structured hook mechanism to enforce it.

**Recommendation:** For Codex, limit the change to `continue-plan` (read `state.json` for routing) and possibly `new-plan` (initialize `state.json`). Don't try to make every Codex prompt update the state file — it adds complexity for uncertain benefit.

## Minor Issues

### 14. Validation hook and state.json

The plan says `validate-ground-rules.sh` needs to "recognize `state.json` as a valid file." But the validation hook only validates `.md` files (`"$plan_dir"/*.md`). It uses a glob of `*.md` to iterate, so `state.json` is already ignored. No change is needed for rule 2 (filename validation).

The optional schema validation is a good idea but should be a separate validation rule, not mixed into the existing file naming check.

### 15. No rollback mechanism

If auto-review creates problems (e.g., the Opus reviewer says "delete everything and start over"), the main agent dutifully follows post-review instructions and potentially damages working code. There's no mechanism to reject a review or roll back.

**Recommendation:** Consider adding a `review_outcome` field or having the post-review action check if a review's suggestions are destructive before applying them. At minimum, document that the max_reviews limit is the safety valve.

### 16. `create-tasks.md` doesn't reference ground-rules.md

The existing `create-tasks.md` action doesn't end with the standard "Remember, you MUST follow `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md`" footer. This is a pre-existing issue but becomes more important with state management — if the action doesn't reference ground-rules, the agent might not update `state.json`.

**Recommendation:** Add the ground-rules reference to `create-tasks.md` as part of the modifications.

## Summary

The plan has a solid core concept but needs corrections in several areas:
- **CLI invocation** is incorrect (`--no-input` doesn't exist, `--print` needs stdout redirection, permissions bypass needed)
- **Hook ordering** assumption is wrong (parallel, not sequential) — merge hooks or add coordination
- **Schema** has redundancy (`plan_phase`) and unnecessary granularity (`current_subtask`)
- **Automation boundaries** are unclear — which commands trigger auto-review vs. which don't?
- **Block/resume messaging** needs precise templates so the main agent knows exactly what to do
- **State corruption** recovery needs more thought
