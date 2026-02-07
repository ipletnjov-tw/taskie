# Post-Review Fixes — Plan Review 1

## Issues Addressed

### Critical Issues

**Issue 1: Claude CLI invocation is wrong**
- Removed `--no-input` (doesn't exist)
- Changed from stdout-to-file assumption to explicit instruction for the CLI to write the review file via its Write tool, with stdout redirected to `/dev/null`
- Switched to model aliases (`opus`, `sonnet`) instead of exact model IDs
- Added self-contained prompt that instructs the CLI to read ground-rules, plan, and task files before reviewing
- Added `--dangerously-skip-permissions` and `--allowedTools "Read Grep Glob Write Bash"` to the invocation

**Issue 2: Hook ordering is parallel, not sequential**
- Merged `validate-ground-rules.sh` and `auto-review.sh` into a single unified `stop-hook.sh`
- Validation logic (rules 1-7) is preserved within the unified hook and runs only when the hook decides NOT to run a review
- Eliminates race conditions between parallel hooks

**Issue 3: `plan_phase` and `phase` are redundant**
- Removed `plan_phase` from the schema entirely
- Added a "Deriving the High-Level Stage" table showing how to derive the stage from `phase`
- Updated schema example and field definitions

**Issue 4: Auto-advance after planning/task creation is underspecified**
- Added explicit "Auto-advance boundaries" section to state transitions
- Clarified: plan review passes → auto-advance to `create-tasks`, tasks review passes → auto-advance to `next-task`, code review passes → auto-advance to next task
- Documented that `complete-task`/`complete-task-tdd` are the automation entry points — the entire plan→review→tasks→review→implement→review flow runs continuously without user intervention

**Issue 5: `complete-task` simplification breaks existing contract**
- Added "Automation Boundary Rule" section defining the clear distinction
- `complete-task`/`complete-task-tdd` set `next_phase` to review phases (enabling hooks)
- `next-task`/`code-review`/etc. set `next_phase: null` when invoked standalone (no hook automation)
- Documented all three scenarios with examples

**Issue 6: `--print` flag and tool usage / permissions**
- Added `--dangerously-skip-permissions` to the CLI invocation
- Added `--allowedTools "Read Grep Glob Write Bash"` to limit scope
- Documented the security implications and rationale

**Issue 7: State corruption risk**
- Clarified that the hook runs synchronously — the main agent is paused while the hook executes, so no concurrent writes
- Documented the exact sequence: agent writes → tries to stop → hook fires (agent paused) → hook writes → hook returns → agent resumes → agent writes
- Added crash recovery strategy: if the agent crashes after hook block, `state.json` is in a recoverable state and `continue-plan` can pick up

**Issue 8: Missing `continue-task` phase**
- Added `"continue-task"` to the phase enum in field definitions
- Added `continue-task` to the state transition diagrams
- Added `continue-task.md` to the action changes section

### Moderate Issues

**Issue 9: `current_subtask` tracking is impractical**
- Removed `current_subtask` from the schema entirely
- Task-level granularity (`current_task`) is sufficient for hooks and `continue-plan`

**Issue 10: Hook block message needs precise templates**
- Added "Block Message Template" section with exact templates for code review, plan review, and tasks review
- Templates include file paths, action instructions, state.json update instructions, and push reminder

**Issue 11: Max reviews per-task semantics**
- Clarified in field definitions: `phase_iteration` resets to 1 when `current_task` changes
- Updated `max_reviews` description: "per task per reviewable phase type"

**Issue 12: Model IDs will go stale**
- Changed to use CLI aliases (`--model opus`, `--model sonnet`) which auto-resolve
- Documented in the `review_model` field description and CLI invocation section

**Issue 13: Codex updates scope**
- Reduced Codex scope to only `new-plan` (initialize state) and `continue-plan` (read state for routing)
- Removed the broad "all review/post-review prompts" update

### Minor Issues

**Issue 14: Validation hook and state.json**
- Clarified that `*.md` glob already ignores `state.json` — no change needed for filename validation
- Added new rule 8 for optional `state.json` schema validation (warning only, non-blocking)

**Issue 15: No rollback mechanism**
- Added risk #7 documenting that git commits per subtask enable `git revert`/`git reset` as rollback
- Added note that the post-review action should exercise judgment on destructive suggestions

**Issue 16: `create-tasks.md` missing ground-rules reference**
- Added to action changes: `create-tasks.md` will include `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md` reference

## Notes

- The unified Stop hook (`stop-hook.sh`) replaces both `validate-ground-rules.sh` and the planned `auto-review.sh`
- The `state.json` schema is now 6 fields (was 8) — simpler and no synchronization burden
- All changes maintain backwards compatibility: if `state.json` doesn't exist, `continue-plan` falls back to git history
