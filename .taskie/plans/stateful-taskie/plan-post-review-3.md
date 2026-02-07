# Post-Review Fixes — Plan Review 3

## Issues Addressed

### Issue 1: `<` vs `<=` contradiction in phase_iteration comparison

- Standardized on `<=` in step 5b of the hook flow (which matches the worked example in review 2)
- Updated field definition to say `incremented_value <= max_reviews` (was `<`)
- Both the field definition and hook flow now consistently use `<=`, yielding exactly `max_reviews` reviews

### Issue 2: `complete-task` delegates to `next-task` but both write state

- Changed design: `next-task` does NOT write `state.json` when called as a delegate from `complete-task`
- Only `complete-task` writes state, ONCE, after implementation finishes — a single atomic write
- This eliminates the double-write race condition where a crash between writes could lose the automation intent
- Updated action items #4 and #5 to document this explicitly

### Issue 3 & 6: Review exit condition and self-assessment bias — DISMISSED per user clarification

- **User clarification**: The last two consecutive reviews must BOTH pass (find no issues) before advancing. The post-review action always loops back (`next_phase: "code-review"`). The reviewer — not the implementer — makes the pass/fail determination.
- Added new `consecutive_clean` field to the schema (7 fields total, up from 6)
- Added clean review detection heuristic to hook step 5e
- Hook step 5f handles the auto-advance when `consecutive_clean >= 2`
- Updated all post-review action items (#7, #8, #9) to always set `next_phase` back to the review phase in automated flow

### Issue 4: new-plan auto-review being aggressive

- The current design (always auto-review) is intentional per review 2 discussion
- Added documentation note to `new-plan` action item: "After running `/taskie:new-plan`, an automated review cycle begins immediately. To break out early, set `next_phase: null` in `state.json`."
- No behavior change — users are informed and have the escape hatch

### Issue 5: Block message templates could clobber fields

- Updated all three block message templates to explicitly instruct: "read current file, modify only phase and next_phase, write complete JSON back"
- Templates now list all fields to keep unchanged: `max_reviews`, `current_task`, `phase_iteration`, `review_model`, `consecutive_clean`
- Added "Write via temp file then mv to prevent corruption" instruction to each template

### Issue 7: Test count was stale

- Updated test counts: Suite 2 → 15 tests (was 12), Suite 3 → 12 tests (was 8), Suite 4 → 12 tests (was 13), Suite 6 → 12 tests (was 9)
- New total: 74 tests (was 65)

### Issue 8: Subprocess hook clarification

- Added explicit note after the CLI invocation section: "The `claude` CLI subprocess does NOT trigger Stop hooks because it runs in `--print` mode (non-interactive). The `stop_hook_active` field is only relevant for the main agent's session."

### Issue 9: Missing integration test for model alternation

- Added test 10 to Suite 6: full model alternation across 4 consecutive iterations, verifying opus→sonnet→opus→sonnet in MOCK_CLAUDE_LOG
- Added test 11 to Suite 6: two consecutive clean reviews integration test

### Issue 10: continue-plan with completed task

- Updated `continue-plan` routing for review phases: agent now verifies whether the current task has outstanding work. If all work is committed, the agent simply stops to trigger the hook. No wasteful `continue-task.md` execution for completed tasks.

## Additional Changes (User Clarifications)

### Two consecutive clean reviews required to advance

- New `consecutive_clean` field in schema, initialized to 0 when entering a review cycle
- Hook reads the review file after the subprocess writes it, determines if it's "clean" (no actionable issues)
- Clean reviews increment `consecutive_clean`; reviews with issues reset it to 0
- When `consecutive_clean >= 2`, the hook auto-advances instead of blocking for another post-review
- All post-review actions now ALWAYS set `next_phase` back to the review phase — the reviewer decides when to advance, not the implementer

### Max iterations = hard stop

- Updated review exit condition: when `phase_iteration > max_reviews`, the agent performs a **hard stop** and waits for user input. It does NOT auto-advance.
- Updated risk #4 and edge case test #8 to reflect hard stop semantics

### Atomic state updates

- Added "Atomic State Updates" section with the temp-file-then-mv pattern
- All writes (hook and main agent) use: read → modify with jq → write to temp file → `mv` to state.json
- `mv` is atomic on POSIX filesystems — no partial writes possible
- Temp file is created in the same directory to ensure same-filesystem rename
- Updated risk #3 and #5 to reference atomic writes
- Added test 12 to Suite 3 (state is valid JSON after update) and test 12 to Suite 6 (no temp files left behind)

## Notes

- Schema now has 7 fields (added `consecutive_clean`)
- Total test count: 74 (up from 65)
- The "reviewer decides" design means the hook needs a clean-review heuristic — this is intentionally simple (keyword-based) and can be refined during implementation
