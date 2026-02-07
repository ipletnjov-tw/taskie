# Task 5: Action File Changes — Task & Review Actions

**Prerequisites**: Task 2 (hook must exist for block messages to reference). Can run in parallel with Task 3.

Update all task implementation and review action files with state.json read/write instructions.

## Subtasks

### Subtask 5.1: Update `next-task.md` and `next-task-tdd.md`
- **Short description**: Update both action files to write `state.json` after implementation: `phase: "next-task"` (or `"next-task-tdd"`), `current_task: "{id}"`, `next_phase: null`. These are standalone commands — no auto-review, no conditional logic. They always set `next_phase: null`. Remove any delegation-related conditionals. The transition to `all-code-review` when no tasks remain is handled by the hook, NOT by the action.
- **Status**: pending
- **Sample git commit message**: Update next-task and next-task-tdd to write state.json
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 3
- **Test approach**: Manual: run `/taskie:next-task` and verify `state.json` has `next_phase: null` and correct `phase` and `current_task`.
- **Must-run commands**: N/A (prompt file)
- **Acceptance criteria**:
  - Both files instruct writing `state.json` with read-modify-write pattern
  - `phase` set to `"next-task"` or `"next-task-tdd"` respectively
  - `current_task` set to the task ID being implemented
  - `next_phase` always `null` (standalone, no automation)
  - No conditional logic based on invocation context
  - No delegation to or from `complete-task`
  - No logic for detecting last task or transitioning to `all-code-review` (handled by hook)
  - All other fields preserved EXCEPT `phase_iteration` which is set to `null` (standalone mode, not in review cycle): `max_reviews`, `review_model`, `consecutive_clean`, `tdd` preserved from existing state via read-modify-write

### Subtask 5.2: Update `complete-task.md` and `complete-task-tdd.md`
- **Short description**: Update both action files with their OWN implementation instructions (inlining relevant parts of `next-task.md`/`next-task-tdd.md`). After implementation, write `state.json` ONCE: `max_reviews` (preserved), `current_task: "{id}"`, `phase: "complete-task"` (or `"complete-task-tdd"`), `next_phase: "code-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`, `tdd: false` (or `true` for TDD variant). Remove the existing Phase 2/3/4 review loop from `complete-task.md` — the hook now handles it.
- **Status**: pending
- **Sample git commit message**: Update complete-task variants with inlined implementation and state writes
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 5
- **Test approach**: Manual: run `/taskie:complete-task` and verify `state.json` has `next_phase: "code-review"` and `phase: "complete-task"`. Verify the old Phase 2/3/4 loop is removed.
- **Must-run commands**: N/A (prompt file)
- **Acceptance criteria**:
  - Both files contain their OWN implementation instructions (no delegation to `next-task`)
  - Implementation instructions are inlined (~10 lines of task implementation steps)
  - Action reads `tasks.md` and selects the first task with status "pending" (same logic as current implementation)
  - Sets `current_task` in `state.json` to the selected task ID
  - `state.json` written ONCE after implementation completes
  - `complete-task.md` sets `tdd: false`; `complete-task-tdd.md` sets `tdd: true`
  - `next_phase: "code-review"` triggers auto-review loop via hook
  - Old Phase 2/3/4 review loop removed from both `complete-task.md` and `complete-task-tdd.md`
  - Read entire `state.json` before modifying (read-modify-write pattern)
  - `max_reviews` preserved from existing state
  - `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0` (fresh review cycle — must reset when entering code review)

### Subtask 5.3: Update `continue-task.md`
- **Short description**: Update to write `state.json` with `phase: "continue-task"`, preserving the existing `next_phase` value (transparent pass-through). Read `next_phase` from current `state.json` before updating — if already set to a review phase, preserve it. If null, keep null.
- **Status**: pending
- **Sample git commit message**: Update continue-task.md to preserve next_phase transparently
- **Git commit hash**:
- **Priority**: medium
- **Complexity**: 2
- **Test approach**: Manual: set `state.json` with `next_phase: "code-review"`, run `/taskie:continue-task`, verify `next_phase` is still `"code-review"`. Repeat with `next_phase: null`.
- **Must-run commands**: N/A (prompt file)
- **Acceptance criteria**:
  - `phase` set to `"continue-task"`
  - `next_phase` preserved from existing state (not overwritten)
  - Read-modify-write pattern used
  - Works correctly for both automated (`next_phase` set) and standalone (`next_phase: null`) contexts

### Subtask 5.4: Update all review and post-review action files
- **Short description**: Update `code-review.md`, `post-code-review.md`, `plan-review.md`, `post-plan-review.md`, `tasks-review.md`, `post-tasks-review.md`, `all-code-review.md`, `post-all-code-review.md`. Review actions: when standalone, set `next_phase: null`. When invoked by hook, the hook manages state (action doesn't update). Post-review actions: in automated flow (`phase_iteration` is non-null), ALWAYS set `next_phase` back to the review phase. When standalone, set `next_phase: null`.
- **Status**: pending
- **Sample git commit message**: Update all review and post-review actions with state.json instructions
- **Git commit hash**:
- **Priority**: high
- **Complexity**: 5
- **Test approach**: Manual: verify each post-review action sets `next_phase` back to review phase when `phase_iteration` is non-null. Verify standalone review actions set `next_phase: null`.
- **Must-run commands**: N/A (prompt files)
- **Acceptance criteria**:
  - Review actions (4 files): when `phase_iteration` is null in state.json (standalone), set `phase: "{review-type}"` and `next_phase: null`. When `phase_iteration` is non-null (hook-invoked), don't update state.json (hook manages it)
  - Post-review actions (4 files): automated flow sets `next_phase` to corresponding review phase; standalone sets `next_phase: null`
  - Automated vs standalone detection for post-review actions: check if `phase_iteration` is non-null in `state.json`
  - All 8 files use read-modify-write pattern for state updates
  - All other state fields preserved unchanged in standalone mode

### Subtask 5.5: Update `add-task.md`
- **Short description**: Update `taskie/actions/add-task.md` to write `state.json`: set `current_task` to the new task ID if no task is currently in progress (i.e. `current_task` is null). If a task is already in progress, leave `current_task` unchanged.
- **Status**: pending
- **Sample git commit message**: Update add-task.md with state.json current_task logic
- **Git commit hash**:
- **Priority**: low
- **Complexity**: 2
- **Test approach**: Manual: run `/taskie:add-task` with `current_task: null` and verify it's set. Run with `current_task: "3"` and verify it's unchanged.
- **Must-run commands**: N/A (prompt file)
- **Acceptance criteria**:
  - If `current_task` is null: set to new task ID
  - If `current_task` is non-null: preserve existing value (task in progress)
  - Read-modify-write pattern used
