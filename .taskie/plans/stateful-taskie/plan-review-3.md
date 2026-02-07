# Plan Review 3 — Stateful Taskie

The plan has matured through two solid review cycles. The schema is clean (6 fields), automation boundaries are well-defined, the CLI invocation is correct, and testing is comprehensive. This review focuses on implementation-readiness: gaps that would surface during coding, semantic contradictions, and untested scenarios.

## Issues

### 1. The hook's increment-then-compare yields `max_reviews + 1` iterations, not `max_reviews`

The `phase_iteration` field definition says:

> The hook increments it BEFORE running each review (so the first review runs at iteration 1, written to `*-review-1.md`). The hook checks `phase_iteration < max_reviews` AFTER incrementing — if false, the review is skipped and the stop is allowed. This yields exactly `max_reviews` reviews.

But step 5b of the hook flow says:

> b. Check if `phase_iteration` <= `max_reviews` — if NOT, skip to step 6 (limit reached)

These two descriptions contradict each other. One uses `< max_reviews`, the other uses `<= max_reviews`.

Walk through the sequence with `max_reviews: 8`:
- Enter with `phase_iteration: 0`. Step 5a: increment to 1. Step 5b: is `1 <= 8`? Yes → run review 1.
- Enter with `phase_iteration: 1`. Step 5a: increment to 2. Step 5b: is `2 <= 8`? Yes → run review 2.
- ...
- Enter with `phase_iteration: 7`. Step 5a: increment to 8. Step 5b: is `8 <= 8`? Yes → run review 8.
- Enter with `phase_iteration: 8`. Step 5a: increment to 9. Step 5b: is `9 <= 8`? No → skip.

That gives exactly 8 reviews, which is correct. But the field definition says `< max_reviews`, which would skip at `8 < 8` = false, giving only 7 reviews. The field definition and step 5b must agree. One of them is wrong.

**Recommendation:** Standardize on `<=` in step 5b (which matches the worked example) and update the field definition to say: "The hook checks `incremented_value <= max_reviews`" (not `<`). Alternatively, switch to `<` everywhere and document that this gives `max_reviews - 1` reviews, then adjust the default to 9. The `<=` approach is simpler.

### 2. `complete-task` delegates to `next-task` internally, but `next-task` sets `next_phase: null`

Action item #5 says:

> **`complete-task.md`** / **`complete-task-tdd.md`** — These are the automation entry points. After the implementation phase (delegating to `next-task.md` / `next-task-tdd.md` internally), they update `state.json` with `next_phase: "code-review"`, `phase_iteration: 0`, `review_model: "opus"`.

But action item #4 says:

> **`next-task.md`** / **`next-task-tdd.md`** — After implementation, updates `state.json` with `phase: "next-task"`, sets `current_task`, sets `next_phase: null`.

If `complete-task` delegates to `next-task` and `next-task` writes `next_phase: null`, then `complete-task` needs to overwrite it immediately after `next-task` finishes. This creates a sequence: `next-task` writes `null` → `complete-task` writes `"code-review"`. The state file is written twice in rapid succession.

This is fragile. If the agent crashes between `next-task`'s write and `complete-task`'s overwrite, the state says `next_phase: null` (standalone mode) even though the user intended full automation. On resume via `continue-plan`, the user would have to manually trigger code review.

**Recommendation:** The plan should clarify the write ordering explicitly. Either:
- (a) `next-task` does NOT write `next_phase` at all when called as a delegate (it only writes `phase` and `current_task`), and the caller (`complete-task`) is responsible for writing `next_phase`. This requires `next-task` to know whether it's being called standalone or as a delegate — perhaps via a parameter or by checking if `next_phase` is already set. OR
- (b) `complete-task` writes `state.json` ONCE after `next-task` finishes (a single atomic write with all fields), instead of relying on `next-task` to write first. The action prompt for `complete-task` explicitly says "do NOT update state.json during implementation — only update it after the task is fully implemented."

Option (b) is cleaner. Document it explicitly.

### 3. `post-code-review` determines "all issues resolved" vs. "issues remain" — but how?

Action item #7 says:

> **`post-code-review.md`** — After applying fixes: if issues remain, sets `next_phase: "code-review"`; if all issues resolved, sets `next_phase: "next-task"` (auto-advance).

The decision "if issues remain" is made by the main agent reading the review file and applying fixes. But the current `post-code-review.md` action doesn't instruct the agent to make a judgment call about whether all issues are resolved. It just says "address the issues" and document what was done.

More importantly: the main agent is the one who implemented the code AND is now evaluating whether its own fixes are sufficient. This is inherently biased — the same agent that wrote the code is deciding its code is "good enough" to skip further review.

In the current manual workflow, the USER makes this determination. In the automated workflow, nobody does — the agent just optimistically sets `next_phase: "next-task"` and moves on, or conservatively always sets `next_phase: "code-review"` and loops until `max_reviews`.

**Recommendation:** The plan should specify the decision criterion explicitly. Two options:
- (a) **Always loop**: `post-code-review` always sets `next_phase: "code-review"`. The review subprocess decides whether there are issues. If the review comes back clean (no issues), the hook detects this (e.g., the review file contains a "PASS" marker or is below a size threshold) and advances. This puts the decision in the reviewer's hands, not the implementer's.
- (b) **Agent decides**: Keep the current approach but add guidance to the action prompt: "Set `next_phase: 'code-review'` if you made ANY substantive code changes. Set `next_phase: 'next-task'` ONLY if the review had zero issues or only trivial documentation/wording suggestions that required no code changes."

Option (b) is simpler and doesn't require parsing review files. But it should be documented.

### 4. The `new-plan` auto-review flow is unreasonably aggressive

The plan says `new-plan` always auto-triggers plan review. This means after `/taskie:new-plan`, the user enters a loop:
1. Agent creates plan.md
2. Agent tries to stop → hook spawns reviewer → review written → block
3. Agent performs post-plan-review → modifies plan.md → tries to stop → hook spawns reviewer again → block
4. Repeat up to 8 times

This means the user cannot create a plan, read it, and THEN decide to review it. The moment they run `/taskie:new-plan`, they're locked into a potentially 8-iteration review cycle consuming significant API credits (each Opus review is expensive).

The same issue applies to `create-tasks` auto-triggering tasks review.

For `complete-task` this makes sense — the user explicitly chose the "complete" workflow. But for `new-plan`, the user might just want to create a plan draft and think about it.

**Recommendation:** Consider making `new-plan` and `create-tasks` behave like standalone commands by default (set `next_phase: null`). Add new commands `/taskie:complete-plan` and `/taskie:complete-tasks` (or overloaded flags) that set `next_phase` to the review phase. This gives the user control over when automation kicks in.

Alternatively, if the current design is intentional (plans should ALWAYS be reviewed), document this prominently so users know what to expect. Add a note in the `new-plan` action: "After creating the plan, an automated review cycle will begin immediately."

### 5. Block message templates instruct the agent to update `state.json`, but the hook also updates it

The code review block message says:

> Update state.json when complete: set phase to "post-code-review" and next_phase to "code-review" if issues remain, or next_phase to "next-task" if all issues are resolved.

But step 5e of the hook flow says:

> e. Update `state.json`: set `phase` to the review phase, write the incremented `phase_iteration`, toggle `review_model`, set `next_phase` to the corresponding post-review phase

So both the hook AND the main agent (via block message instructions) write `state.json`. The hook writes it after the review (setting up for post-review), and then the main agent writes it after post-review (setting up for the next review or next task).

This is fine conceptually, but the block message template is incomplete — it doesn't tell the agent to preserve `phase_iteration`, `review_model`, or `max_reviews`. The instruction "set phase to 'post-code-review' and next_phase to 'code-review'" could result in the agent writing only those two fields and losing the others.

**Recommendation:** The block message should either:
- (a) Instruct the agent to update ONLY `phase` and `next_phase` fields (using `jq` or a targeted update), not overwrite the entire file. OR
- (b) Explicitly list ALL fields to write: "Update state.json: set `phase` to 'post-code-review', keep `phase_iteration` unchanged, keep `review_model` unchanged, keep `max_reviews` unchanged, set `next_phase` to 'code-review' if issues remain or 'next-task' if resolved, keep `current_task` unchanged."

Option (b) is safer given that the agent may not use `jq` for targeted updates.

### 6. The "review exit condition" for passing reviews is undefined

The state transitions say:

> **Review exit conditions** (transition out of review loop):
> - All reviews pass (no issues found) → advance to next phase

But neither the hook nor the block message template defines what "all reviews pass" means. The hook subprocess writes a review file. Someone (the main agent, during post-review) reads it and decides whether issues remain. But:

- Who signals that "no issues were found"? The main agent by setting `next_phase` to the advance target (`next-task`, `create-tasks`, etc.)? That's action item #7's approach.
- What if the review file says "no issues found" but the agent misreads it and sets `next_phase: "code-review"` anyway? You'd get wasted review cycles.
- What if the review file says "5 critical issues" but the agent sets `next_phase: "next-task"` because it thinks it fixed them all? The issues slip through.

This is the same fundamental tension as issue #3 but at the flow level. The review exit is entirely dependent on the main agent's self-assessment.

**Recommendation:** Acknowledge this as a known limitation and document it: "The review loop relies on the main agent to honestly assess whether issues are resolved. The `max_reviews` limit is the safety net. If reviews are going in circles, the user can break the loop via the escape hatch (set `next_phase: null` in `state.json`)." This is already partially covered in risk #8 but should be called out as a design constraint, not just a user workaround.

### 7. Test suite count is wrong after removing `--allowedTools` test

The plan says:

> | CLI invocation | 13 |
> | **Total** | **65** |

But the `--allowedTools` test was removed in post-review 2, leaving 12 tests in suite 4. The total should be 64, not 65. The expected test counts table was not updated.

**Recommendation:** Update the table: CLI invocation = 12, Total = 64.

### 8. The hook's `stop_hook_active` check is undocumented for the `claude` CLI subprocess

Step 1 of the hook logic says:

> 1. Check `stop_hook_active` — if true, approve immediately (prevent infinite loops)

The `claude` CLI subprocess invoked by the hook is a separate process. When that subprocess finishes its review and tries to stop, does the stop hook fire for IT too? If so, the hook would see `stop_hook_active` is... what? The subprocess doesn't set `stop_hook_active` — the MAIN agent's session does.

Actually, the `claude` CLI invoked with `--print` runs in non-interactive mode and doesn't fire Stop hooks at all (it's not stopping in the hook sense — it just exits after printing). So this might be a non-issue.

But the plan should explicitly state: "The `claude` CLI subprocess invoked by the hook does NOT trigger Stop hooks because it runs in `--print` mode (non-interactive). The `stop_hook_active` field is only relevant for the main agent's session."

**Recommendation:** Add a brief note clarifying that the subprocess doesn't trigger hooks.

### 9. No test for the review model alternation across the full lifecycle

Test suite 3 tests individual transitions (opus→sonnet in test 4, sonnet→opus in test 5). But there's no integration test that verifies the full alternation sequence across multiple review iterations:

```
iter 0→1 (opus) → post-review → iter 1→2 (sonnet) → post-review → iter 2→3 (opus) → ...
```

This matters because the alternation depends on the hook correctly toggling `review_model` AND the main agent NOT overwriting `review_model` during post-review (see issue #5). A single-iteration unit test won't catch a bug where the main agent accidentally resets `review_model` to `"opus"` every time.

**Recommendation:** Add an integration test (in test suite 6 or a new suite) that simulates 4 consecutive review iterations and verifies the model alternates correctly: opus, sonnet, opus, sonnet. This test would need to invoke the hook 4 times with the mock CLI, checking `state.json` after each.

### 10. `continue-plan` has a gap: `next_phase` = `"code-review"` means "the hook will handle it" — but the hook won't fire

The `continue-plan` routing says:

> `next_phase` = `"code-review"` / `"plan-review"` / `"tasks-review"` / `"all-code-review"` → the hook will handle this on the next stop, so execute `continue-task.md` or inform the agent to complete its current work and stop

This assumes the agent will "complete its current work and stop", which triggers the hook. But if the agent just started from `continue-plan` and has no work to do (the previous implementation was already committed), what does it "continue"? It can't just stop immediately because there's nothing to stop from.

Consider this crash scenario:
1. Agent finishes task implementation, writes `state.json` with `next_phase: "code-review"`, `phase: "next-task"`
2. Agent tries to stop → hook fires → runs review → blocks with `next_phase: "post-code-review"`
3. Agent starts post-review but crashes mid-way. The post-review file is partially written.
4. User resumes with `continue-plan`. State shows `phase: "code-review"`, `next_phase: "post-code-review"`.
5. `continue-plan` routes to `post-code-review.md` (correct — `next_phase` is non-null).

That works. But consider a different crash:
1. Agent finishes task implementation, writes `state.json` with `next_phase: "code-review"`, `phase: "next-task"`
2. Agent crashes BEFORE trying to stop. The hook never fires.
3. User resumes with `continue-plan`. State shows `phase: "next-task"`, `next_phase: "code-review"`.
4. `continue-plan` sees `next_phase: "code-review"` → "the hook will handle this on the next stop, so execute `continue-task.md`".
5. Agent runs `continue-task.md` but the task is already complete (all subtasks done). It has nothing to continue. It tries to stop → hook fires → review runs. OK.

Step 5 works but is wasteful — the agent reads all task files, determines nothing is left, and then stops. The routing should detect this case: if `next_phase` is a review phase AND `phase` is an implementation phase AND the task is already complete, just tell the agent to stop (triggering the hook).

**Recommendation:** Add a note in the `continue-plan` routing: "If `next_phase` is a review phase, the agent should verify whether the current task/phase has outstanding work. If not, it should stop immediately to trigger the hook." Or simplify: always route to `continue-task.md` in this case, and let `continue-task.md` handle the 'nothing to do' case gracefully (it already should).

## Summary

The plan is near implementation-ready. The remaining issues are:

- **Arithmetic contradiction** (#1): `<` vs. `<=` in the iteration comparison — pick one and be consistent.
- **Double-write fragility** (#2): `next-task` writes `null`, `complete-task` overwrites with `"code-review"` — crash between them loses automation intent.
- **Self-assessment bias** (#3, #6): Main agent decides its own code is "good enough" — document this as a known limitation.
- **Aggressive auto-review on plan creation** (#4): Users may not want an immediate 8-iteration review cycle after `/taskie:new-plan`.
- **Incomplete block message** (#5): Agent could clobber `phase_iteration` and `review_model` when updating `state.json`.
- **Stale test count** (#7): Total should be 64, not 65.
- **Subprocess hook clarification** (#8): The `claude` subprocess doesn't trigger hooks — say so.
- **Missing integration test** (#9): Full model alternation across multiple iterations.
- **continue-plan with completed task** (#10): Agent may have nothing to continue but still runs `continue-task.md`.
