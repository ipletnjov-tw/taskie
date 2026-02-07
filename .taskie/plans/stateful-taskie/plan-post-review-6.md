# Post-Review Fixes — Plan Review 6 (Clean Slate)

## Issues Addressed

### Issue 1: Hook I/O undocumented

- Added "Hook Input/Output Protocol" subsection before the hook logic steps
- Documents stdin JSON schema (`cwd`, `stop_hook_active`), stdout decision formats (approve silent, approve with message, block, fatal error), and exit codes
- A developer can now implement the hook's I/O layer without reverse-engineering the existing `validate-ground-rules.sh`

### Issue 2: 3→8 cycle cap change unacknowledged

- Added note to `complete-task` action item (#5): "This replaces the existing 3-cycle review cap in `complete-task.md` with the global `max_reviews` setting (default 8). The cap is now enforced by the hook, not by the action prompt. The higher default allows more thorough automated review cycles since the two-consecutive-clean exit condition typically terminates earlier."

### Issue 3: Wording ambiguity in delegation — DISMISSED (minor)

The slash in "delegate to `next-task.md` / `next-task-tdd.md`" means "respectively" and is clear enough in context. No change.

### Issue 4: `next_phase: "complete"` gap in continue-plan routing

- Added routing rule: `next_phase = "complete"` → set `phase: "complete"`, `next_phase: null`, inform user all tasks are done
- This is reachable when the hook sets `next_phase: "complete"` after all-code-review auto-advance, and the agent crashes before actually stopping

### Issue 5: Stale step reference (5f → 5g)

- Fixed step 5a cross-reference: "same mapping as step 5g" (was "5f" before the renumbering in post-review 5)

### Issue 6: PLUGIN_ROOT resolution — DISMISSED (correct)

Works correctly. `BASH_SOURCE[0]` resolves to the installed cache path, and `..` correctly reaches the plugin root. No change.

### Issue 7: No-remaining-tasks routing clarified

- Updated `next-task` action item (#4): when invoked via auto-advance (detectable because current `next_phase` is `"next-task"` before overwrite), it checks `tasks.md` for remaining pending tasks
- If no tasks remain: sets `next_phase: "all-code-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0` (entering new review cycle)
- This is an explicit exception to the "standalone = null" rule for the auto-advance case
- The action detects auto-advance mode by reading `next_phase` before overwriting — if it was `"next-task"` (set by hook), it's in automated mode

### Issue 8: Incomplete field lists in action items

- `new-plan` (#2): now lists all 7 fields explicitly, with note that this is the only action constructing state from scratch
- `create-tasks` (#3): now lists fields set + "preserve `max_reviews` from existing state"
- `complete-task` (#5): now includes `max_reviews` (preserved from existing state)

## Notes

- Two issues dismissed (#3 minor wording, #6 correct behavior)
- Six issues addressed with concrete plan edits (#1, #2, #4, #5, #7, #8)
- The hook I/O documentation (#1) is particularly important — without it, a developer would have to reverse-engineer the existing hook to understand the contract
