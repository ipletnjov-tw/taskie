# Post-Tasks-Review Fixes — Tasks Review 1

## Issues Addressed

### ISSUE 1-1: Task dependency ordering (CRITICAL → FIXED)
- Added explicit `**Prerequisites**` line to all 6 task files
- Task 1: "None (this task MUST complete before any other task begins)"
- Task 2: "Task 1 (test infrastructure must exist before test refactoring)"
- Task 3: "Task 2 (stop-hook.sh must exist with steps 1-4 and step 6)"
- Tasks 4-5: "Task 2. Can run in parallel with Task 3"
- Task 6: "Tasks 1-5 (edge case tests require the full system)"

### ISSUE 1-2: Mock flag handling (RECOMMENDATION → FIXED)
- Added acceptance criterion to subtask 1.2: mock gracefully accepts all CLI flags (`--print`, `--model`, `--output-format`, `--json-schema`, `--dangerously-skip-permissions`) without errors — flags are logged but don't alter mock behavior

### ISSUE 2-1/2-5/CT-1: Task 1 → Task 2 dependency (CRITICAL → FIXED)
- Addressed via the prerequisites added in Issue 1-1

### ISSUE 2-2: Missing test runner/Makefile updates (CRITICAL → DISMISSED)
- The reviewer missed that Task 1 subtask 1.3 already covers this: "Update test runner and Makefile" with acceptance criteria for `make test-state`, `make test-validation`, and single-file execution
- No change needed — this was already in the task list

### ISSUE 2-3: Missing tests/README.md update (HIGH → FIXED)
- Added "Update `tests/README.md` with new test file descriptions" to subtask 2.5 acceptance criteria

### ISSUE 2-4: Incorrect version reference (HIGH → FIXED)
- The reviewer incorrectly claimed the current version is 2.2.0 — it's actually 2.2.1 in both `plugin.json` and `marketplace.json`
- Per user instruction, changed from MINOR bump to MAJOR bump: 2.2.1 → 3.0.0 (the stateful hook replaces the validation hook and changes workflow behavior)

### ISSUE 2-6: Vague "make test passes (all suites)" (MEDIUM → FIXED)
- Changed subtask 2.5 must-run from `make test` to `make test-validation` since only suite 1 exists at that point

### ISSUE 3-1: Missing hook steps 1-3 (CRITICAL → DISMISSED)
- The reviewer misread the task structure. Steps 1-3 ARE already in Task 2:
  - Step 1 (`stop_hook_active` check) → Task 2 subtask 2.1
  - Step 2 (`.taskie/plans` check) → Task 2 subtask 2.1
  - Step 3 (find plan directory) → Task 2 subtask 2.2
- Task 3 correctly says "After validation setup (step 4)" — it builds on Task 2's output
- Added clarifying note to Task 3 header: "Steps 1-3 and step 6 are implemented in Task 2"

### ISSUE 3-2: Missing step 6 validation fallback (CRITICAL → DISMISSED)
- Step 6 IS the validation logic, which is Task 2 subtask 2.2. The "fall through to step 6" language in Task 3 means control returns to the validation code that Task 2 already implemented
- Clarified in Task 3 header note

### ISSUE 3-3: CLI schema not specified (CRITICAL → FIXED)
- Added exact `--json-schema` value to subtask 3.2 acceptance criteria:
  `'{"type":"object","properties":{"verdict":{"type":"string","enum":["PASS","FAIL"]}},"required":["verdict"]}'`

### ISSUE 3-4: Auto-advance logic "contradiction" (CRITICAL → DISMISSED)
- Not a contradiction — the reviewer confused two different transitions:
  - code-review → all-code-review (when no tasks remain): enters a fresh all-code-review cycle
  - all-code-review → complete (when all-code-review passes): sets `phase: "complete"`, `next_phase: null`
- These are sequential, not contradictory. Both were already in subtask 3.3
- Expanded the acceptance criteria to list all advance targets more explicitly (5 cases instead of 4)

### ISSUE 3-5: TDD field check not explicit (HIGH → FIXED)
- Expanded subtask 3.3 acceptance criteria from "based on `tdd`" to explicit:
  - `complete-task-tdd` if `tdd == true`, `complete-task` if `tdd == false`
- Applied to both tasks-review and code-review advance targets

### ISSUE 3-6: Timeout macOS incompatibility (HIGH → FIXED)
- Removed `timeout 540` suggestion from subtask 3.2
- Replaced with: "CLI subprocess timeout is handled by Claude Code's 600s hook timeout — do NOT use the shell `timeout` command (not available on macOS)"

### ISSUE 3-7: Hard stop UX unclear (MEDIUM → FIXED)
- Specified exact `systemMessage` content for hard stop: "Max review limit (${MAX_REVIEWS}) reached for ${REVIEW_TYPE}. Edit state.json to adjust max_reviews or set next_phase manually."

### ISSUE 3-8: Remaining tasks check pattern missing (MEDIUM → FIXED)
- Added explicit grep pattern to subtask 3.3: `grep '^|' tasks.md | grep -i 'pending' | wc -l`

### ISSUE 3-9: Test coverage for steps 1-3 (MEDIUM → FIXED)
- Added note to subtask 3.5: "Tests implicitly verify steps 1-3 (from Task 2) work correctly since auto-review tests require valid input parsing and plan detection to function"

### ISSUE CT-2: Test distribution strategy (MEDIUM → ACKNOWLEDGED)
- Reviewer noted this is acceptable: edge cases need the full system
- No change needed

## Dismissal Summary

4 issues dismissed (with justification):
- **2-2**: Test runner already in Task 1 subtask 1.3 (reviewer missed it)
- **3-1**: Hook steps 1-3 already in Task 2 subtasks 2.1-2.2 (reviewer misread task structure)
- **3-2**: Step 6 validation IS Task 2 subtask 2.2 (same misread)
- **3-4**: Not a contradiction, two different transitions (reviewer confused sequential transitions)

## Notes

- 12 issues fixed, 4 dismissed, 1 acknowledged
- User override: version bump changed from MINOR to MAJOR (2.2.1 → 3.0.0)
- All tasks now have explicit prerequisites
- Task 3's relationship to Task 2 is now clearly documented
