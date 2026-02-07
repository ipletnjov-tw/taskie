# Plan Review 7 — Clean Slate

This is a fresh, independent review of the stateful Taskie implementation plan. No prior reviews were consulted.

---

## Issue 1: `complete-task` Delegation Anti-Pattern Creates Fragile Coupling

**Severity: HIGH**

Section "5. `complete-task.md` / `complete-task-tdd.md`" introduces a rule: "`next-task` does NOT write `state.json` when called as a delegate." This creates a hidden behavioral contract between two action files — `next-task.md` must somehow know whether it was invoked standalone or as a delegate, and change its behavior accordingly.

The plan doesn't specify how `next-task.md` detects this. It's an action file (a Markdown prompt), not executable code. The LLM reading `next-task.md` has no reliable mechanism to know who invoked it. The plan says `complete-task` "delegates implementation to `next-task.md` internally" — but the current `complete-task.md` says "Execute action `@${CLAUDE_PLUGIN_ROOT}/actions/next-task.md`", which means the LLM is instructed to read and follow that file. There's no parameter-passing mechanism in Markdown prompts.

**Possible solutions:**
- (a) Have `complete-task.md` inline its own implementation instructions instead of delegating to `next-task.md`. This duplicates some text but eliminates the coupling.
- (b) Have `complete-task.md` write `state.json` BEFORE delegating to `next-task.md`, so the state is already set correctly regardless of what `next-task` does. Then `next-task.md` can always write its own state (overwriting is fine since `complete-task` already set `next_phase: "code-review"` and `next-task` would set `next_phase: null` — but then we'd lose the automation intent). This doesn't work either.
- (c) Best approach: `complete-task.md` should explicitly instruct the LLM: "Implement the task as described in `next-task.md`, but do NOT update `state.json` during this step — you will update it in Phase 2 below." This makes the override explicit in the prompt text.

**Recommendation:** Adopt (c), but acknowledge the fragility — an LLM might still write state.json if the `next-task.md` instructions are sufficiently emphatic. Document this risk.

---

## Issue 2: `continue-plan` Routing Table Has an Ambiguous Crash Recovery Case

**Severity: HIGH**

The plan says when `next_phase` is a review phase (e.g., `"code-review"`) and `phase` is NOT a post-review value (e.g., `phase` is `"next-task"`), this means "the agent was mid-implementation when it crashed — execute `continue-task.md` to finish the work before stopping."

But this is also the NORMAL state immediately after a fresh `complete-task` finishes implementation. After `complete-task` completes Phase 1 (implementation), it writes: `phase: "next-task"`, `next_phase: "code-review"`. This is the EXPECTED state for the hook to pick up. If the agent then tries to stop (which triggers the hook), the hook sees `next_phase: "code-review"` and runs the review. Correct.

But if instead of stopping, the user runs `continue-plan`, the routing logic says: "phase is `next-task` (not a post-review), so execute `continue-task.md` to finish the work." This would RE-IMPLEMENT the task that was already completed. The agent would try to do the task again.

The distinction between "implementation just finished normally" and "implementation crashed mid-way" is indistinguishable from `state.json` alone when `phase: "next-task"` and `next_phase: "code-review"`. The plan relies on the hook intercepting the stop, but `continue-plan` is a manual invocation that doesn't go through the hook.

**Recommendation:** The `continue-plan` routing for `next_phase` = review phase should check if the task file shows the task as completed/in-progress-with-subtasks-done. If the task appears complete, simply stop to let the hook handle the review. If the task appears incomplete, then run `continue-task`.

---

## Issue 3: The All-Code-Review Prompt Tells the CLI to Read "All task-*.md Files" — Token Bomb

**Severity: MEDIUM**

The CLI invocation for all-code-review says:

```
"Read ... .taskie/plans/${PLAN_ID}/tasks.md, and all .taskie/plans/${PLAN_ID}/task-*.md files."
```

For a plan with, say, 10 tasks and 3 review iterations each, the plan directory could contain 10 task files + 30 review files + 30 post-review files = 70+ files. The glob `task-*.md` matches ALL of them — task files, review files, AND post-review files. The CLI subprocess would attempt to read all 70+ files into its context window.

Even if we're generous and assume the `--print` mode handles this, the total token count could easily exceed the context window of the CLI subprocess, leading to truncated context or outright failure.

**Recommendation:** The prompt should be more targeted — e.g., "Read `tasks.md` and only the `task-{N}.md` files (not review or post-review files)" or explicitly list the task file names derived from `tasks.md`. Alternatively, the hook could construct the file list programmatically before passing it to the CLI.

---

## Issue 4: Hook Finds "Most Recently Modified Plan" Using `find -printf` — Brittle Heuristic

**Severity: MEDIUM**

The existing `validate-ground-rules.sh` (line 152) uses `find ... -name "*.md" -printf '%T@ %h\n'` to find the most recently modified plan. The plan says the new hook will use the same approach.

Problem: `state.json` is not an `.md` file, so modifying state.json won't update the "most recently modified plan" heuristic. If two plans exist and the user switches between them, writes to state.json (non-.md) won't change which plan the hook validates.

This could lead to the hook reviewing the WRONG plan — e.g., the user writes to plan B's `state.json`, but plan A has a more recently modified `.md` file, so the hook picks up plan A.

**Recommendation:** The "find most recent plan" heuristic should also consider `state.json` modification times. Change the find pattern to include `\( -name "*.md" -o -name "state.json" \)`.

---

## Issue 5: `max_reviews` Semantics Are Confusing — "Per Task Per Reviewable Phase Type" vs. Global

**Severity: MEDIUM**

The field definition says: "Maximum review iterations per task **per reviewable phase type** (default 8)." But the schema has a single `max_reviews` field, not one per phase type. And `phase_iteration` resets when entering a new review cycle.

This means `max_reviews: 8` allows up to 8 plan reviews AND 8 task reviews AND 8 code reviews per task AND 8 all-code-reviews. That's potentially 8+8+(8*N)+8 = 24+8N total automated reviews for a plan with N tasks. For 10 tasks, that's 104 automated review invocations, each spawning a full `claude` CLI session. At 10 minutes per review (the timeout), that's potentially 17+ hours of unattended automated reviews.

The plan mentions this limit mostly in the context of "safety valve," but the practical cost implications of defaulting to 8 reviews per phase are significant. Most issues should be caught in the first 2-3 reviews. A default of 4 would still be generous while halving the worst-case cost.

**Recommendation:** Either (a) lower the default to 4, or (b) explicitly document the worst-case cost implications in the Risk Assessment section so users can make an informed choice.

---

## Issue 6: No Mechanism to Skip All-Code-Review for Small Plans

**Severity: LOW**

After the last task's code review passes with 2 clean reviews, the hook auto-advances to `all-code-review`. This makes sense for multi-task plans, but for a 1-2 task plan where each task has already been thoroughly reviewed (up to 8 iterations), an additional all-code-review cycle (up to 8 more iterations) is redundant.

The plan has `max_reviews: 0` as an escape hatch for skipping ALL reviews, but there's no way to skip ONLY the all-code-review while keeping per-task reviews. The user would have to manually edit `state.json` to set `next_phase: null` or `phase: "complete"` after the last task finishes.

**Recommendation:** Consider a separate `skip_all_code_review: true` field, OR document the manual escape hatch explicitly in the plan as the intended workflow for small plans. The latter is simpler and probably sufficient.

---

## Issue 7: Block Message Templates Instruct the Agent to Update `state.json` — But the Hook Already Wrote It

**Severity: MEDIUM**

The block message template for code review says:

> "Update state.json atomically ... set phase to 'post-code-review', set next_phase to 'code-review'."

But at step 5h, the hook ALREADY wrote state.json with these values:

> "set `phase` to the review phase ... set `next_phase` to the corresponding post-review phase"

So `phase` is already set to `"code-review"` and `next_phase` is already `"post-code-review"`. The block message then tells the agent to set `phase: "post-code-review"` and `next_phase: "code-review"` — this is the OPPOSITE direction. The hook sets the state to reflect "we just did a review, next is post-review." The agent then does the post-review and should set the state to reflect "we just did post-review, next is review."

So the block message is correct in INTENT (the agent should update state after doing post-review), but the timing is wrong — the agent should update state AFTER doing the post-review work, not as part of reading the block message. If the agent updates state immediately upon receiving the block message (before doing any work), and then crashes, the state says "post-code-review" but no post-review work was done and no post-review file exists.

**Recommendation:** The block message should say: "After completing the post-review work and writing the post-review file, update state.json: set phase to 'post-code-review', set next_phase to 'code-review'." The ordering must be explicit — work first, then state update.

---

## Issue 8: No Handling of `continue-plan` When Phase Is `"complete"`  and `next_phase` Is `null`

**Severity: LOW**

The routing table for `continue-plan` under "When `next_phase` is null" lists:

- `phase = "continue-task"` or `"next-task"` or `"next-task-tdd"` → execute `continue-task.md`
- `phase = "complete"` → inform user all tasks are done

But what about `phase = "code-review"`, `"plan-review"`, `"tasks-review"`, `"post-code-review"`, etc. with `next_phase: null`? These are valid states for standalone commands that were interrupted. For example, the user runs standalone `/taskie:code-review`, the agent crashes mid-review, and `state.json` has `phase: "code-review"`, `next_phase: null`. Running `continue-plan` has no routing for this — it falls through to... nothing? The plan doesn't specify a fallback for unmatched combinations.

**Recommendation:** Add a catch-all routing rule: if `next_phase` is null and `phase` is not one of the explicitly handled values, fall back to git history analysis (the pre-stateful behavior). This provides a safety net for edge cases.

---

## Issue 9: Stdout Suppression Hides Review Errors

**Severity: LOW**

The CLI invocation redirects stdout to `/dev/null`:

```bash
claude --print ... > /dev/null 2>&1
```

Both stdout AND stderr are suppressed. If the `claude` subprocess fails — e.g., it can't read a file, hits an API error, or produces an error message — the hook has no way to know WHY it failed. The only detection is "did the review file get written?" (step 5e). But the error context is lost.

**Recommendation:** Redirect stderr to a log file (e.g., `.taskie/plans/${PLAN_ID}/.review-${ITERATION}.log`) instead of `/dev/null`. This preserves debugging information without polluting hook stdout. The log file can be cleaned up after successful reviews.

---

## Issue 10: The `stop_hook_active` Field — Where Does It Come From?

**Severity: HIGH**

The plan says: "The hook receives a JSON payload on stdin containing at least: `stop_hook_active` (boolean): If true, the hook is being invoked during a continuation."

But `stop_hook_active` is NOT a standard Claude Code hook event field. Looking at the existing hook code, it reads `stop_hook_active` from the JSON event (line 22 of `validate-ground-rules.sh`). The question is: who sets this field? The plan doesn't explain this.

From the existing code, it appears Claude Code's hook system automatically includes `stop_hook_active: true` when the stop is triggered by the agent resuming from a hook block. But this is an ASSUMPTION — the plan should document this explicitly and confirm whether this is a documented Claude Code hook feature or an implementation detail that could change.

If this field is NOT reliably provided by Claude Code, the hook has no infinite-loop protection, which is a critical safety gap.

**Recommendation:** Verify and document the source of `stop_hook_active`. If it's not a guaranteed Claude Code feature, implement an alternative loop detection mechanism (e.g., a `.hook-running` lock file).

---

## Issue 11: Test Count Mismatch — Plan Says 80, Detailed Tables Show Different

**Severity: LOW**

The "Expected Test Counts" table claims 80 total tests. Let me count from the detailed tables:

- Suite 1 (Validation): Tests 1-17 = 17
- Suite 2 (Auto-review): Tests 1-15 = 15
- Suite 3 (State transitions): Tests 1-16 = 16
- Suite 4 (CLI invocation): Tests 1-14 = 14
- Suite 5 (Block messages): Tests 1-6 = 6
- Suite 6 (Edge cases): Tests 1-12 = 12

Total: 17+15+16+14+6+12 = **80** ✓

The count is actually correct. No issue here — withdrawing this point.

---

## Summary

| # | Issue | Severity | Actionable? |
|---|-------|----------|-------------|
| 1 | `complete-task` delegation anti-pattern — no detection mechanism for delegate mode | HIGH | Yes — inline instructions or use explicit prompt override |
| 2 | `continue-plan` can't distinguish "task finished" from "task crashed mid-way" | HIGH | Yes — check task file completion status |
| 3 | All-code-review CLI prompt reads ALL task-*.md files (reviews + post-reviews included) | MEDIUM | Yes — filter the glob or construct explicit file list |
| 4 | "Most recently modified plan" heuristic ignores state.json | MEDIUM | Yes — include state.json in find pattern |
| 5 | Default `max_reviews: 8` creates potential for 100+ automated reviews | MEDIUM | Yes — lower default or document cost implications |
| 6 | No way to skip all-code-review without skipping all reviews | LOW | Document manual escape hatch |
| 7 | Block message timing — agent should update state AFTER work, not before | MEDIUM | Yes — reword block messages |
| 8 | `continue-plan` has no fallback for unmatched phase+null next_phase combos | LOW | Yes — add catch-all git history fallback |
| 9 | CLI stderr suppressed — debugging info lost on failure | LOW | Yes — redirect stderr to log file |
| 10 | `stop_hook_active` origin undocumented — safety depends on unverified assumption | HIGH | Yes — verify and document, or add fallback |

VERDICT: FAIL
