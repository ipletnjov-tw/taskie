# Task 4: Action File Changes — Planning Actions

Update `new-plan.md`, `continue-plan.md`, and `create-tasks.md` with state.json read/write instructions.

## Subtasks

### Subtask 4.1: Update `new-plan.md` to initialize `state.json`
- **Short description**: Add instructions to `taskie/actions/new-plan.md` that after creating `plan.md`, the agent must initialize `state.json` with all 8 fields: `max_reviews: 8`, `current_task: null`, `phase: "new-plan"`, `next_phase: "plan-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`, `tdd: false`. This is the only action that constructs `state.json` from scratch. Add a note that automated review begins immediately after the plan is created.
- **Status**: pending
- **Sample git commit message**: Update new-plan.md to initialize state.json
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 3
- **Test approach**: Manual: run `/taskie:new-plan` and verify `state.json` is created with correct initial values.
- **Must-run commands**: N/A (prompt file, no executable code)
- **Acceptance criteria**:
  - `new-plan.md` instructs the agent to create `state.json` with all 8 fields
  - All default values match the plan schema
  - `state.json` is constructed from scratch (not read-modify-write)
  - Note about automated review cycle beginning immediately is present
  - Note about escape hatch (`next_phase: null`) is present

### Subtask 4.2: Rewrite `continue-plan.md` for state-based routing
- **Short description**: Major rewrite of `taskie/actions/continue-plan.md`. The action reads `state.json` and routes based on `next_phase` first (primary path), falling back to `phase` when `next_phase` is null (standalone interrupted). Implements the full routing table from the plan: post-review phases → execute post-review; review phases → two-level crash recovery heuristic (check `phase` for post-review, then check artifact completeness); advance targets → execute action; `next_phase: null` with implementation phases → `continue-task`; `next_phase: null` with other phases → inform user, ask what to do; no `state.json` → fall back to git history.
- **Status**: pending
- **Sample git commit message**: Rewrite continue-plan.md for state-based routing
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 8
- **Test approach**: Manual: test each routing path by setting up different `state.json` states and running `/taskie:continue-plan`. Verify correct action is taken in each case.
- **Must-run commands**: N/A (prompt file, no executable code)
- **Acceptance criteria**:
  - Reads `state.json` as first step (before any git history analysis)
  - Routes correctly for all `next_phase` values listed in the plan
  - Two-level crash recovery heuristic for review phases:
    - Checks `phase` for post-review → just stop
    - Checks artifact completeness for plan-review (plan.md exists + >50 lines or has `## Overview`)
    - Checks artifact completeness for tasks-review (tasks.md exists + has table rows)
    - Checks subtask completion for code-review/all-code-review
  - Catch-all for `next_phase: null` with review/post-review phases → inform user, ask
  - Falls back to git history ONLY when `state.json` doesn't exist
  - Handles `next_phase: "complete"` → set `phase: "complete"`, inform user

### Subtask 4.3: Update `create-tasks.md` to write `state.json`
- **Short description**: Update `taskie/actions/create-tasks.md` to write `state.json` after creating tasks: set `phase: "create-tasks"`, `current_task: null`, `next_phase: "tasks-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`. Preserve `max_reviews` and `tdd` from existing state (read-modify-write). Add `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` reference (currently missing from this action).
- **Status**: pending
- **Sample git commit message**: Update create-tasks.md to write state.json and add ground-rules reference
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 3
- **Test approach**: Manual: run `/taskie:create-tasks` and verify `state.json` is updated correctly. Verify ground-rules reference is loaded.
- **Must-run commands**: N/A (prompt file, no executable code)
- **Acceptance criteria**:
  - `create-tasks.md` instructs read-modify-write of `state.json` (not from scratch)
  - Sets `phase`, `current_task`, `next_phase`, `phase_iteration`, `review_model`, `consecutive_clean`
  - Preserves `max_reviews` and `tdd` from existing state
  - Always sets `next_phase: "tasks-review"` (auto-triggers tasks review)
  - Ground-rules reference added at top of action
