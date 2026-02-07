# Plan Review 9 (Clean Slate)

## Critical Issues

### 1. Hook Script Complexity and Responsibility Overload

The unified `stop-hook.sh` is doing far too much:
- JSON parsing and validation
- File system operations (finding plans, reading state)
- Subprocess management (spawning `claude` CLI)
- Verdict extraction and interpretation
- State file updates (atomic writes with temp files)
- Model alternation logic
- Consecutive clean review tracking
- Auto-advance decision making
- Validation rule enforcement (7 rules)
- Error handling and logging

**Problem:** This creates a single point of failure with hundreds of lines of complex bash code. Debugging will be extremely difficult. One logic error could break the entire workflow.

**Recommendation:** Consider splitting responsibilities. For example, a separate helper script for state management, or moving verdict evaluation to a more robust language (Python).

### 2. 10-Minute Hook Timeout is Problematic

The hook timeout is set to 600 seconds (10 minutes) to accommodate `claude` CLI subprocess execution.

**Problems:**
- Users are blocked from stopping for up to 10 minutes
- No progress indication during this time
- If the subprocess hangs, users have no visibility
- The Stop event becomes unreliable and unpredictable
- Multiple automated reviews mean users could be blocked for hours

**Recommendation:** Consider a background task approach instead of blocking the Stop event. Let the user stop immediately, then have a separate mechanism (possibly a cron-like scheduler or a Resume hook) that triggers reviews asynchronously.

### 3. Cost and Performance Unaddressed

The plan acknowledges worst-case cost (104 reviews for a 10-task plan) but dismisses it with "typical count much lower."

**Problems:**
- No cost budgeting mechanism
- No user preferences for review depth
- Starts with Opus (most expensive model) every cycle
- No consideration of simple changes that don't need expensive reviews
- 10 minutes per review × 104 reviews = 17+ hours of automated processing

**Recommendation:** Add a `review_budget` field to `state.json` that tracks remaining review credits. Add user-configurable review strategies (quick/normal/thorough). Consider starting with Sonnet for first pass, escalating to Opus only if issues found.

### 4. Two Consecutive Clean Reviews is Arbitrary

The requirement for 2 consecutive clean reviews has no justification.

**Problems:**
- Why 2? Why not 1 or 3?
- Leads to redundant reviews when the first is genuinely clean
- The second reviewer has no context from the first review
- Both reviewers could miss the same issue independently
- Doubles review cost even when code is perfect

**Recommendation:** Either justify the "2" requirement with reasoning, or make it configurable via `state.json` (e.g., `consecutive_clean_threshold: 2`). Consider alternative exit conditions: "1 clean review from Opus" or "2 reviews that agree on specific aspects."

### 5. Hook-Driven Workflow Removes User Agency

The automated review loop blocks the user and forces a specific workflow.

**Problems:**
- User cannot review their own implementation before automated review runs
- No opt-out without manual `state.json` editing
- The "hard stop" at `max_reviews` leaves users confused with no clear next action
- Users might want to commit work before review, but the hook blocks the stop
- The escape hatch (editing `state.json`) is buried in a parenthetical note

**Recommendation:** Make automation opt-in, not opt-out. Add a `--auto-review` flag to commands like `complete-task`. Let the default behavior be non-blocking. Add a clear UI message when max_reviews is reached with suggested next actions.

### 6. State Synchronization Fragility

The state file is updated by both the hook and action files, with no reconciliation mechanism.

**Problems:**
- If hook and action disagree on next_phase, workflow breaks
- If action crashes mid-update, state could be inconsistent
- The "read-modify-write" pattern is documented but not enforced
- No validation that state transitions are legal (e.g., can't jump from "new-plan" to "code-review")
- No schema version field means incompatible changes break silently

**Recommendation:** Add a state machine validator that checks transitions. Add a `schema_version: 1` field. Consider using a lock file during updates (despite the plan dismissing this). Add a `/taskie:fix-state` command that analyzes and repairs broken state files.

### 7. Continue-Plan Routing Logic is Too Complex

The `continue-plan.md` action has a 4-level fallback: `next_phase` → `phase` + artifact checks → git history → ask user.

**Problems:**
- Very difficult to reason about and test
- The artifact completeness checks (> 50 lines, contains "## Overview") are fragile heuristics
- Git history fallback could conflict with state file (which should be authoritative)
- Users won't understand which path was taken
- Debugging "why did continue-plan do X?" is nearly impossible

**Recommendation:** Simplify to 2 levels: `next_phase` (primary) → ask user (fallback). If `state.json` exists but is unclear, don't guess—prompt the user. Remove git history fallback entirely for stateful plans.

### 8. Inline Delegation Creates Duplication

The plan explicitly inlines `next-task` logic into `complete-task` to avoid "fragile cross-prompt conditionals."

**Problems:**
- ~10+ lines of implementation instructions duplicated between `next-task.md` / `next-task-tdd.md` and their `-complete` variants
- Any change to implementation workflow requires updating 4 files
- The "fragility" of delegation is not explained—what was the actual failure mode?
- This violates DRY for the sake of avoiding a simple conditional

**Recommendation:** Keep delegation and fix the conditional properly. The issue is likely that `next-task` was checking if it was called standalone vs. delegated—this can be fixed by having `complete-task` pass a parameter or by having two separate internal actions (one for standalone, one for delegated use).

### 9. Verdict Extraction Relies on Structured Output

The plan uses `--json-schema` to force the model to return `{"verdict": "PASS"}` or `{"verdict": "FAIL"}`.

**Problems:**
- What if the model refuses to give a binary verdict? (e.g., "needs clarification")
- What if the schema validation fails and the CLI returns an error?
- The plan says "fallback to validation only" but this could hide real issues
- A failed review should probably fail loudly, not silently skip

**Recommendation:** Add explicit error handling. If verdict extraction fails, write a `.review-${ITERATION}-ERROR.log` and set `next_phase: null` to force user intervention. Don't silently continue.

### 10. Task File List Construction is Fragile

The hook builds `TASK_FILE_LIST` by grepping `tasks.md` for `task-[0-9]+\.md` patterns.

**Problems:**
- Assumes task IDs are sequential integers (1, 2, 3...)
- Fails for task-1a, task-foo, or any non-standard naming
- The grep pattern `'^|'` assumes table rows, but what if the table format changes?
- If `TASK_FILE_LIST` is empty, the hook "skips the review"—but this could hide real corruption

**Recommendation:** Use a more robust parser. Consider requiring a specific task file naming convention and validating it during task creation. If TASK_FILE_LIST is empty when it shouldn't be (e.g., `tasks.md` exists and has content), error loudly.

### 11. Testing Strategy Weak on Failure Modes

The 80 planned tests focus on happy paths and state transitions.

**Problems:**
- No tests for disk full during state write
- No tests for killed/interrupted subprocess
- No tests for network issues (if CLI needs internet)
- No tests for corrupt state recovery (plan mentions it but doesn't test it)
- No tests for concurrent git operations (what if user manually commits during auto-review?)
- Mock `claude` is too simple—doesn't test real CLI failure modes

**Recommendation:** Add "chaos engineering" tests: kill subprocess mid-review, fill disk during write, corrupt state file and verify recovery, simulate CLI crashes. Test with the REAL `claude` CLI in a sandbox environment.

### 12. Review Content vs. Verdict Separation

The plan separates review content (written to `task-1-review-1.md`) from the verdict (JSON on stdout).

**Problems:**
- The review file might say "looks good" but verdict is "FAIL"—or vice versa
- How do humans review the review when the verdict is separate from the content?
- The structured output is validated by the CLI, but the content is not—model could write gibberish

**Recommendation:** Require the model to include the verdict INSIDE the review markdown (e.g., final line must be `VERDICT: PASS` or `VERDICT: FAIL`). Have the hook extract it from the file, not from a separate JSON output. This ensures content and verdict are synchronized.

### 13. Max Reviews Hard Stop Leaves Users Stranded

When `phase_iteration > max_reviews`, the agent stops and "waits for user input."

**Problems:**
- No clear message to the user explaining what happened
- No suggested actions (should they increase max_reviews? skip the task? fix something?)
- The state is stuck with `next_phase: "code-review"` but the hook won't run it
- Users might not know they need to manually edit `state.json` or run a command

**Recommendation:** When hard stop is reached, the hook should set `next_phase: null` and write a `_MAX_REVIEWS_REACHED.md` file with instructions. The agent should detect this and inform the user with actionable next steps.

### 14. Atomic Write Pattern Not Enforced

The plan documents the temp-file-then-mv pattern but doesn't enforce it.

**Problems:**
- Actions might use naive `echo "$JSON" > state.json` and corrupt the file
- The hook script itself might have a bug in the atomic write code
- No runtime validation that the pattern was followed
- No detection of partial writes (though mv should prevent this)

**Recommendation:** Create a `update_state_json()` shell function in the hook that enforces the pattern. Have all state writes call this function. Add a checksum or magic number to `state.json` to detect corruption.

### 15. POSIX Portability Claims Are Misleading

The plan emphasizes POSIX compatibility (using `grep -E` instead of `grep -P`) but the hook is still bash-specific.

**Problems:**
- Uses bash arrays, process substitution, `$BASH_SOURCE`
- Uses `mapfile` or `readarray` (bash 4+)
- Uses `jq` which is not POSIX
- Not portable to `sh`, `dash`, or other minimal shells

**Recommendation:** Either commit to full POSIX compliance (write in pure `sh`, avoid jq by using `sed`/`awk` for JSON) OR remove portability claims and document "requires bash 4.3+ and jq."

### 16. No Consideration of Review Quality

The plan assumes automated reviews are equivalent to manual human reviews.

**Problems:**
- Models can miss context-dependent issues
- Models can hallucinate problems that don't exist
- No mechanism to rate or validate review quality
- Consecutive "clean" reviews might both be wrong (false negatives)
- No human-in-the-loop checkpoints

**Recommendation:** Add a review quality checkpoint. After 2 consecutive clean reviews, require user confirmation before auto-advancing. Show a summary: "2 reviews found no issues. Proceed to next task? (y/n)."

### 17. State File Bloat Over Time

Each plan directory gets a `state.json` that persists forever.

**Problems:**
- Stale state files from abandoned plans
- No cleanup mechanism
- If user deletes task files but not state.json, the hook breaks
- State file could reference non-existent tasks or phases

**Recommendation:** Add a validation step: if `state.json` references `current_task: "5"` but `task-5.md` doesn't exist, reset to a safe state or error. Add a cleanup command: `/taskie:clean-plan` that archives old state files.

### 18. Auto-Advance Logic is Opaque

The hook's auto-advance logic (step 5g) is complex and hard to audit.

**Problems:**
- Different advance targets for each review type
- The `tdd` field affects advance target, but this is easy to forget
- The "no remaining tasks" check uses `grep`/`awk` on `tasks.md`—fragile
- If the check is wrong, could skip all-code-review or loop forever

**Recommendation:** Move auto-advance logic OUT of the hook and INTO the action files. Have `post-code-review` check for remaining tasks and set `next_phase` accordingly. The hook should only enforce the 2-consecutive-clean rule, not decide what comes next.

### 19. Ground Rules Mutation

The plan adds state.json requirements to `ground-rules.md`.

**Problems:**
- Ground rules are loaded by every action, but only stateful workflows use `state.json`
- Non-stateful users (legacy plans, Codex users) will see irrelevant rules
- Mixes concerns: file structure rules + workflow state rules

**Recommendation:** Create a separate `stateful-ground-rules.md` file included only by stateful actions. Keep `ground-rules.md` generic and stateless.

### 20. No Migration Path for Existing Plans

Users with existing (pre-stateful) plans have no clear upgrade path.

**Problems:**
- `continue-plan` falls back to git history, but what if the state is ambiguous?
- Should users manually create `state.json` for old plans? What values?
- No `/taskie:migrate-plan` command

**Recommendation:** Add a migration command that analyzes git history and creates an initial `state.json`. Alternatively, document that old plans remain stateless and new plans are stateful—don't mix.

## Architectural Concerns

### Concern 1: Over-Engineering the Hook

The hook is trying to be a mini workflow engine. This is not what hooks are designed for. Hooks should be simple validators, not orchestrators.

**Alternative approach:** Use the hook only for validation (rules 1-7). Move the auto-review loop into a `/taskie:auto-review-loop` command that users run explicitly. Or use a background agent that polls `state.json` and triggers reviews asynchronously.

### Concern 2: State File as Single Source of Truth

The plan positions `state.json` as authoritative, overriding git history and file artifacts.

**Risk:** If `state.json` is corrupt or manually edited incorrectly, the entire workflow breaks. Users might not understand that this one JSON file controls everything.

**Alternative:** Use `state.json` as a cache/hint, but always validate against artifacts. If state says "task 5 is done" but `task-5.md` is incomplete, trust the artifact.

### Concern 3: Blocking Stop Event

Making the Stop hook block for minutes (waiting for `claude` CLI) is a UX anti-pattern.

**Risk:** Users will press Ctrl+C multiple times, kill the process, or force-quit, leading to corrupt state.

**Alternative:** Make the Stop hook instant (validation only). Add a separate `/taskie:trigger-review` command that spawns the `claude` CLI and waits. Or use a background task with notifications.

## Scope Creep

The original prompt asked for:
- State file for tracking current task/phase
- Automated code review via hooks

The plan now includes:
- Unified hook combining validation + auto-review (not requested)
- Model alternation with Opus/Sonnet (not requested)
- Two consecutive clean reviews (not requested)
- Auto-advance to next task (not requested)
- Verdict extraction via JSON schema (not requested)
- Comprehensive testing infrastructure (good, but large)
- Codex CLI updates (minimal, inconsistent)
- All-code-review automation (not requested)
- TDD field and workflow tracking (not requested)
- Consecutive clean counter (not requested)

**Recommendation:** Break this into phases. Phase 1: just add `state.json` and update `continue-plan`. Phase 2: add basic hook auto-review (single iteration, no fancy exit conditions). Phase 3: add model alternation and consecutive clean logic. This makes each phase testable and deliverable.

## Summary

This plan is **technically sound but over-engineered**. The core ideas (stateful workflow, automated reviews) are good, but the execution is too complex for a bash hook script and creates too many failure modes.

**Key recommendations:**
1. Simplify the hook—move logic into actions or helper scripts
2. Make automation opt-in, not blocking by default
3. Add better error handling and user feedback
4. Reduce scope—deliver in phases
5. Test failure modes more thoroughly
6. Improve state synchronization and validation
7. Don't block Stop events for minutes—find an async approach

**Estimated complexity:** High. This will take 3-4x longer to implement correctly than a simpler approach.

**Risk level:** Medium-High. Many subtle failure modes, difficult debugging, potential for user frustration.

**Recommendation:** Simplify before implementing. Consider a phased approach or a fundamentally different architecture (async background reviews instead of synchronous hook blocking).
