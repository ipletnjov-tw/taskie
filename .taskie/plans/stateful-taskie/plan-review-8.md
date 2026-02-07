# Plan Review 8 (Clean Slate)

This is an independent, clean-slate review of `plan.md` for the Stateful Taskie feature. No prior review files were consulted.

---

## Issue 1: `complete-task` delegation to `next-task` is inherently fragile — and the mitigations are insufficient

**Severity: High**

The plan (line 319) acknowledges the fragility: `complete-task.md` tells the LLM to "implement the task as described in `next-task.md`, but do NOT update `state.json` during implementation." It then adds a mitigation: `next-task.md` itself should include a note saying "Skip this state update if you were invoked from `complete-task`."

This is a prompt-level contract enforced by two separate prompts that must agree on behavior. The LLM reads `next-task.md` and sees emphatic state-writing instructions. A separate line says "skip this if invoked from `complete-task`." There is no programmatic enforcement — the LLM may or may not follow the conditional instruction.

**The real problem:** If the LLM in `complete-task` mode writes `next_phase: null` (following `next-task.md`'s standalone instructions) and then `complete-task` tries to write `next_phase: "code-review"`, there is a crash window between these two writes. The plan acknowledges this but relies entirely on prompt compliance to avoid it.

**Recommendation:** Instead of the delegation + override pattern, `complete-task.md` should contain its OWN implementation instructions (duplicating/inlining the relevant parts of `next-task.md`) rather than delegating. Yes, this creates duplication between `next-task.md` and `complete-task.md`, but it eliminates the fragile cross-prompt conditional entirely. The duplication is small (the implementation instructions are ~10 lines) and the reliability gain is significant. Alternatively, `next-task.md` should contain NO state-writing instructions at all — all state writes should live exclusively in the calling action (`complete-task` or standalone `next-task` wrapper).

---

## Issue 2: `continue-plan` crash recovery heuristic has a blind spot for plan/tasks creation

**Severity: Medium**

Line 301 describes the two-level heuristic for when `next_phase` is a review phase but the agent may have crashed mid-work:

1. Check if `phase` is a post-review value → agent completed post-review, just stop to trigger hook
2. Check task file subtask completion status → if incomplete, run `continue-task`

But step 2 only applies to code-review/all-code-review. For plan-review and tasks-review, the plan says "always stop to trigger the hook since the plan/tasks creation is atomic (either the file exists or it doesn't)."

**The blind spot:** Plan creation is NOT atomic. `new-plan` tells the LLM to create `plan.md` and then write `state.json`. If the agent crashes AFTER creating `plan.md` but BEFORE writing `state.json`, there is no state file at all — the fallback to git history is correct. But if the agent crashes AFTER writing `state.json` with `phase: "new-plan"` but BEFORE finishing the plan content (e.g., `plan.md` is half-written), `continue-plan` sees `next_phase: "plan-review"` and routes to "just stop to trigger the hook." The hook then spawns a reviewer on a half-written plan. The reviewer will likely `VERDICT: FAIL` on every pass until `max_reviews` is exhausted, because it's reviewing incomplete content.

**Recommendation:** For plan-review routing, add a basic completeness check: verify `plan.md` exists AND has a reasonable length (e.g., > 50 lines or contains an `## Overview` heading). If not, route to `new-plan` (or a dedicated "continue creating the plan" path) rather than immediately triggering review. Same logic applies to `create-tasks` — verify `tasks.md` has actual table rows before allowing tasks-review.

---

## Issue 3: The `TASK_FILE_LIST` extraction regex is fragile

**Severity: Medium**

Line 216:
```bash
TASK_FILE_LIST=$(grep -oP 'task-\d+\.md' ".taskie/plans/${PLAN_ID}/tasks.md" | sort -u | sed "s|^|.taskie/plans/${PLAN_ID}/|" | tr '\n' ' ')
```

This uses a Perl-compatible regex (`-oP`) with `grep`. Two problems:

1. **Portability:** `grep -P` is not available on all systems. macOS's default `grep` does not support `-P`. While Claude Code currently runs on Linux, the plugin is distributed to users who may run it on macOS. The hook would silently fail to build the file list.

2. **Matching scope:** The regex `task-\d+\.md` will match the string `task-\d+\.md` anywhere in a line — including inside inline code references, prose descriptions, or URLs. If `tasks.md` contains a line like "See task-99.md for the legacy approach" referring to a non-existent task, the hook would include it in the file list, causing the `claude` CLI to fail when it tries to read a non-existent file.

**Recommendation:** Use POSIX-compatible `grep -oE 'task-[0-9]+\.md'` instead of `-oP`. For the matching scope issue, restrict the match to table rows only (lines starting with `|`) to avoid false positives from prose content.

---

## Issue 4: The `.hook-lock` fallback loop detection has a race condition and cleanup gap

**Severity: Medium**

Line 145 describes the `.hook-lock` mechanism: the hook writes a timestamp file at the start of each review invocation and removes it after the block message is sent. If the hook starts and finds a `.hook-lock` less than 30 seconds old, it approves immediately.

**Problems:**

1. **Race condition with crash:** If the hook crashes (or the `claude` CLI subprocess hangs and the hook is killed by timeout), the `.hook-lock` file is never removed. The next hook invocation finds a stale lock and approves immediately — this is the intended behavior. But if the user manually retries within 30 seconds, they get an unexpected auto-approve instead of a review.

2. **30-second window is arbitrary and not justified:** The plan doesn't explain why 30 seconds was chosen. The `claude` CLI subprocess can run for up to 10 minutes. If the hook is killed at minute 9, the lock file is 9 minutes old and won't trigger the fallback. The lock file's timestamp comparison only protects against rapid re-invocation, not against all loop scenarios.

3. **Cleanup on success path:** The plan says the lock is removed "after the block message is sent," but what about the approve path (two consecutive cleans)? The lock should also be cleaned up on the approve path.

**Recommendation:** Simplify: use a PID-based lock (`echo $$ > .hook-lock`) and check if that PID is still running (`kill -0`). This handles crashes (dead PID → stale lock → ignore) without arbitrary timeouts. Always clean up the lock in a `trap` handler. Alternatively, since `stop_hook_active` is the primary loop defense and this is defense-in-depth, consider whether the added complexity of `.hook-lock` is worth it at all — it may be better to just rely on `stop_hook_active` and `max_reviews` as the two safety nets.

---

## Issue 5: No specification for how `complete-task` detects the auto-advance context in `next-task`

**Severity: Medium**

Line 317: "when `next-task` is invoked via auto-advance from the hook (detectable because the current `next_phase` in `state.json` is `"next-task"` before the action overwrites it), it should check `tasks.md` for remaining pending tasks."

This detection mechanism is described in `next-task.md`'s behavior, but `next-task` is a prompt file — it doesn't "detect" things programmatically. The LLM executing `next-task` would need to:
1. Read `state.json` BEFORE doing anything
2. Check if `next_phase == "next-task"` (which means it was auto-advanced)
3. After implementation, conditionally set `next_phase` to `"all-code-review"` or `null`

But the plan simultaneously says `next-task` is a standalone command that sets `next_phase: null`. The "exception for auto-advance" creates two code paths within the same action file, differentiated by reading pre-existing state. This is confusing and error-prone for the LLM.

**Recommendation:** Make the auto-advance detection explicit in the hook, not in the action file. When the hook auto-advances after code review passes (step 5g), instead of blindly setting `next_phase: "next-task"`, the HOOK should check `tasks.md` for remaining tasks. If none remain, set `next_phase: "all-code-review"` directly. If tasks remain, set `next_phase: "next-task"`. This keeps `next-task.md` simple (always standalone, always `next_phase: null`) and moves the routing logic to the hook where it can be programmatically implemented.

---

## Issue 6: The plan conflates review-phase semantics — `phase` and `next_phase` can both be review phases but mean different things

**Severity: Medium**

Consider this state: `{phase: "code-review", next_phase: "post-code-review"}`. Here `phase` is `"code-review"`, meaning the hook just ran a code review. Now consider: `{phase: "post-code-review", next_phase: "code-review"}`. Here `next_phase` is `"code-review"`, meaning the hook should run a code review on the next stop.

The hook (step 5) checks `next_phase` to decide whether to run a review. But `continue-plan` (line 299) checks BOTH `next_phase` and `phase` with different semantics. The routing logic is:
- `next_phase` = review phase → hook handles it (agent should just stop)
- `next_phase` = post-review → agent should do post-review
- `next_phase` = null, `phase` = review → catch-all, fall back to git history

The third case is odd. If `phase` is `"code-review"` and `next_phase` is null, this means someone ran a standalone code-review that wrote a review file but didn't set up automation. Falling back to git history seems wrong — the git history will show the review file was just created, but `continue-plan` won't know whether to do post-review or not (because standalone mode means no automated follow-up was intended).

**Recommendation:** Clarify the semantics: when `next_phase` is null and `phase` is a review or post-review phase, the `continue-plan` action should inform the user of the current state and ask what to do next, rather than silently falling back to git history analysis which may produce confusing results. The git history fallback should be reserved ONLY for the case where `state.json` doesn't exist (true backwards compatibility).

---

## Issue 7: No handling of `tasks.md` parsing failure in the hook

**Severity: Low-Medium**

The hook needs to extract task IDs from `tasks.md` (line 216) to build `TASK_FILE_LIST` for code-review and all-code-review prompts. But `tasks.md` might:
- Not exist yet (if `create-tasks` hasn't run)
- Be empty
- Have a malformed table
- Have table rows but no task file references

If the `grep` returns empty, `TASK_FILE_LIST` is an empty string, and the `claude` CLI prompt would contain "read the task files: " (empty). The CLI would likely still run but without task context, producing a useless review.

**Recommendation:** The hook should check that `TASK_FILE_LIST` is non-empty before invoking `claude`. If empty, log a warning and skip the review (approve the stop). For code-review (single task), the hook should use `current_task` from `state.json` to construct the file path directly (`task-${current_task}.md`) rather than parsing `tasks.md` — the task ID is already known.

---

## Issue 8: The `max_reviews` limit applies per "review cycle" but the semantics are ambiguous for `all-code-review`

**Severity: Low-Medium**

Line 45: "`max_reviews` — Maximum review iterations per task per reviewable phase type (default 8)."

The phrase "per task per reviewable phase type" suggests code-review for task 1 gets 8 reviews, code-review for task 2 gets 8 reviews, plan-review gets 8 reviews, etc. — each independently capped.

But `phase_iteration` is described as resetting "when `current_task` changes or a new review cycle begins" (line 48). For `all-code-review`, `current_task` doesn't change (it reviews all tasks). And `phase_iteration` resets to 0 when entering the all-code-review cycle. So `all-code-review` gets its own 8 reviews, which is correct.

**The ambiguity:** If a user sets `max_reviews: 2` expecting "2 reviews per task," they actually get 2 plan reviews + 2 tasks reviews + 2 code reviews per task + 2 all-code-reviews. The per-phase-type semantics are correct in the schema, but the `max_reviews` field name and description could lead users to think it's a global total. The field description says "Maximum review iterations per task per reviewable phase type" but the field name `max_reviews` without qualification is ambiguous.

**Recommendation:** Rename the field to `max_reviews_per_cycle` or add a brief clarifying comment in the schema description: "Each review cycle (plan-review, tasks-review, code-review per task, all-code-review) independently tracks iterations against this limit."

---

## Issue 9: No versioning strategy specified for the state.json schema

**Severity: Low**

The `state.json` schema has 7 fields. Over time, new fields may be added (e.g., `tdd_mode`, `skip_all_code_review`, etc.). The plan includes no schema version field and no forward-compatibility strategy.

If a user upgrades the plugin while a plan is in progress, the new hook code may expect fields that don't exist in the existing `state.json`. The validation rule (line 363) warns on missing fields but doesn't block — this is good. But the hook logic itself (step 5) reads specific fields like `consecutive_clean` without default fallbacks.

**Recommendation:** Add a brief note to the plan that the hook should use `jq` default operators when reading fields (e.g., `(.consecutive_clean // 0)`) to handle missing fields gracefully. This is cheap insurance and avoids the need for a formal schema version number at this stage.

---

## Issue 10: The test count (80) is ambitious and may front-load too much test infrastructure work

**Severity: Low (process concern, not technical)**

The plan specifies 80 tests across 6 suites, with detailed tables for every test case. This is thorough but creates a significant implementation burden: the test infrastructure (shared helpers, mock claude, test runner updates) plus 80 individual test cases could easily be 40-60% of the total implementation effort.

This isn't wrong, but it's worth flagging: the task breakdown should account for this. If tests are a single task ("write all tests"), it will be a massive task. If tests are split per suite, that's 6 tasks just for testing. The plan should be explicit about how tests are distributed across implementation tasks to avoid underestimation.

**Recommendation:** When creating tasks, split test work alongside feature work (e.g., "Implement hook auto-review logic + write test suite 2") rather than deferring all tests to the end. This ensures each feature is tested as it's built and prevents a test-only mega-task.

---

## Issue 11: stderr capture pattern hides useful debugging information

**Severity: Low**

Line 187: `> /dev/null 2>"$REVIEW_LOG"`

The `claude` CLI's stdout is sent to `/dev/null` and stderr is captured to a log file. The plan says the log is cleaned up after a successful review and persists on failure.

The problem is that `--print` mode may output useful diagnostic information to stdout (e.g., tool use summaries, progress indicators). By sending stdout to `/dev/null`, all of this is lost. On the other hand, the review content is written to disk via the Write tool, so stdout isn't needed for the actual output.

However, if the CLI fails to write the review file (e.g., Write tool permission denied), the only debugging information is in stderr. The `--print` flag may send most output to stdout, meaning stderr might be nearly empty even on failure.

**Recommendation:** Capture both stdout and stderr to the log file: `>"$REVIEW_LOG" 2>&1`. This ensures all diagnostic output is available for debugging failures, at the cost of a slightly larger log file (which is cleaned up on success anyway).

---

## Summary

| # | Issue | Severity | Category |
|---|-------|----------|----------|
| 1 | `complete-task` delegation to `next-task` is fragile | High | Architecture |
| 2 | Crash recovery blind spot for half-written plans/tasks | Medium | Reliability |
| 3 | `TASK_FILE_LIST` regex is non-portable and over-broad | Medium | Portability |
| 4 | `.hook-lock` mechanism has race conditions and cleanup gaps | Medium | Reliability |
| 5 | Auto-advance detection logic is in the wrong place (`next-task` vs hook) | Medium | Architecture |
| 6 | `continue-plan` catch-all for null `next_phase` + review `phase` is confusing | Medium | UX/Correctness |
| 7 | No handling of empty `TASK_FILE_LIST` in hook | Low-Medium | Robustness |
| 8 | `max_reviews` name is ambiguous for per-cycle semantics | Low-Medium | Naming/Clarity |
| 9 | No schema versioning or default fallbacks for `state.json` fields | Low | Forward-compat |
| 10 | 80-test suite needs explicit task distribution strategy | Low | Process |
| 11 | stderr-only capture hides stdout diagnostic info | Low | Debugging |

VERDICT: FAIL
