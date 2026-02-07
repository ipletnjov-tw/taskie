# Plan Review 4 — Stateful Taskie

The plan has been through three thorough review cycles. The schema is solid (7 fields), automation boundaries are clear, atomic writes prevent corruption, and the two-consecutive-clean-review exit condition is well-defined. This review is a final pass focused on implementation gotchas, internal consistency, and anything that would trip up a developer during coding.

## Issues

### 1. The "clean review" heuristic is too naive and will produce false positives

Step 5e says:

> A simple heuristic: if the review file contains no headings with "issue", "problem", "bug", "error", "fix", or "change" (case-insensitive), it's considered clean.

This will misfire constantly. A perfectly valid clean review that says "No issues found. The implementation looks good. No changes needed." would match "issue", "change", and be classified as dirty. Conversely, a review that lists problems using bullet points without those exact keywords would be classified as clean.

The heuristic is searching for keywords that naturally appear in BOTH positive and negative review contexts. The word "issue" appears in "No issues found", "change" appears in "No changes needed", "error" appears in "No errors detected".

**Recommendation:** Instead of keyword matching, instruct the review subprocess to include a structured verdict at the end of its review. Add to the CLI prompt: "At the very end of your review, write exactly one of these lines: `VERDICT: PASS` (if no issues found) or `VERDICT: FAIL` (if issues found)." The hook then checks for `VERDICT: PASS` — a simple, unambiguous grep. This is more reliable than negative keyword matching and gives the hook a clear signal. Update the mock claude script to include this verdict line in its output.

### 2. The auto-advance in step 5f has a "remaining tasks" check but no mechanism for it

Step 5f says:

> For code review advancing to next task: also check if there are remaining tasks — if none, set `next_phase: "all-code-review"` instead.

But the hook script is a bash script reading `state.json`. It knows `current_task` (e.g. `"3"`) but doesn't know the total number of tasks. To determine "are there remaining tasks", the hook would need to:
- Parse `tasks.md` to find the total task count
- Or iterate `task-*.md` files to find the highest task ID
- Or read each task file to check completion status

This is non-trivial for a bash hook that's supposed to be simple and fast. The hook currently reads `state.json` and runs `claude` — adding `tasks.md` parsing is scope creep that complicates the hook significantly.

**Recommendation:** Move the "remaining tasks" determination to the post-code-review action. When the two-consecutive-clean exit triggers the auto-advance, the hook always sets `next_phase: "next-task"`. Then the `continue-plan`/`next-task` action reads `tasks.md`, discovers there are no remaining tasks, and sets `next_phase: "all-code-review"` itself. This keeps the hook simple (only reads `state.json`, writes `state.json`, invokes `claude`) and pushes domain logic to the action prompts where it belongs.

### 3. `continue-task.md` doesn't know if it's in standalone or automated mode

Action item #10 says:

> **`continue-task.md`** — Updates `state.json` with `phase: "continue-task"`. After completion, follows the same `next_phase` logic as `next-task` (null for standalone, `"code-review"` if in automated workflow).

But `continue-task` is invoked in two scenarios:
- The user types `/taskie:continue-task` directly (standalone — should set `next_phase: null`)
- The `continue-plan` action routes to it because the task was interrupted mid-implementation

In the second case, the state might already have `next_phase: "code-review"` (from a prior `complete-task` invocation that was interrupted). `continue-task` needs to decide: should it preserve the existing `next_phase` or overwrite it?

The current wording says "null for standalone, code-review if in automated workflow" but doesn't say HOW `continue-task` knows which mode it's in. Is it by checking `phase_iteration`? By checking the current value of `next_phase` before overwriting?

**Recommendation:** Clarify: `continue-task` should READ `next_phase` from the current `state.json` before updating. If `next_phase` is already set to a review phase (e.g. `"code-review"`), it was set by a prior automation command and should be preserved — just update `phase` to `"continue-task"`. If `next_phase` is null, it's standalone mode — keep it null. This makes `continue-task` a transparent pass-through for `next_phase`.

### 4. Block message templates don't include the all-code-review case

The Block Message Template section has templates for code review, plan review, and tasks review. But step 5 also handles `all-code-review` as a review phase. There is no block message template for all-code-review.

When the hook runs an all-code-review and blocks, what does the `reason` say? Without a template, it's undefined.

**Recommendation:** Add a fourth block message template for all-code-review:
```
An all-code review (iteration ${ITERATION}) has been written to .taskie/plans/${PLAN_ID}/all-code-review-${ITERATION}.md by an independent reviewer. Read this review file and perform the post-all-code-review action: address all issues across all tasks, then create .taskie/plans/${PLAN_ID}/all-code-post-review-${ITERATION}.md documenting your fixes. Update state.json atomically: set phase to "post-all-code-review", set next_phase to "all-code-review". Keep all other fields unchanged. Write via temp file then mv. Update tasks.md and push to remote.
```

### 5. The test for `max_reviews: 0` says "hard stop" but `0 <= 0` is true

Edge case test #8:
> `max_reviews: 0` → approve immediately (0 means no reviews, hard stop)

But step 5b says: "Check if incremented `phase_iteration` <= `max_reviews`". With `max_reviews: 0`, the hook increments `phase_iteration` from 0 to 1, then checks `1 <= 0` → false → skips to step 6. So the hook correctly skips the review.

But wait — what about the initial state? The state has `phase_iteration: 0`, `next_phase: "code-review"`. The hook enters step 5, increments to 1, checks `1 <= 0` = false, and falls through to step 6. Step 6a says "if `phase_iteration > max_reviews`: hard stop." Is `1 > 0` true? Yes. So it's a hard stop where the agent waits for user input.

This means `max_reviews: 0` doesn't just "approve immediately" — it triggers a hard stop with a user-input-required message. The test expectation should say "approve (falls through to validation, hard stop — agent waits for user input)" not just "approve immediately (0 means no reviews)".

**Recommendation:** Clarify the test expectation. Also consider whether `max_reviews: 0` should be a special case that means "no reviews at all, just proceed" rather than "hard stop requiring user input". The user might set `max_reviews: 0` as an escape hatch expecting the agent to move on, not get stuck waiting for input. If it should mean "skip reviews and proceed normally", step 6a should only trigger the hard stop when `phase_iteration > max_reviews AND max_reviews > 0`.

### 6. The "tasks review" CLI prompt is underspecified

The plan says:

> For **tasks reviews**, similarly adapted to read `tasks.md` and all `task-*.md` files.

But there's no actual prompt shown. For code review and plan review, there are concrete prompt strings. For tasks review, it's hand-waved. During implementation, the developer will need to construct this prompt, and "similarly adapted" doesn't tell them:
- Should the subprocess read ALL `task-*.md` files? Even already-completed ones?
- What action file does it reference? `${PLUGIN_ROOT}/actions/tasks-review.md`?
- What's the output filename? `tasks-review-${ITERATION}.md`?

**Recommendation:** Add the concrete tasks review prompt:
```bash
"Read the ground rules in ${PLUGIN_ROOT}/ground-rules.md, then read .taskie/plans/${PLAN_ID}/tasks.md and all .taskie/plans/${PLAN_ID}/task-*.md files. Perform the tasks review action described in ${PLUGIN_ROOT}/actions/tasks-review.md. Write your review to .taskie/plans/${PLAN_ID}/tasks-review-${ITERATION}.md. Be very critical."
```

### 7. `review_model` starts at `"opus"` for every new review cycle, not just the first

Action items #2, #3, and #5 all say: `review_model: "opus"`. This means every time a new review cycle begins (new-plan, create-tasks, or complete-task), the model resets to `"opus"`.

Is this intentional? If the plan review cycle ended on iteration 6 with `review_model: "sonnet"`, and then `create-tasks` starts a new cycle, it resets to `"opus"`. This means the strongest model always goes first for each review type, which makes sense.

But consider `complete-task` for the second task. Task 1's code review ends at iteration 4 with `review_model: "sonnet"`. Task 2's code review starts with `review_model: "opus"` (reset). This is fine and probably desired.

**Verdict:** This is likely intentional and correct — strongest model first for each new cycle. But it should be stated explicitly as a design decision, not just implied by the initialization values. Add a brief note: "Model always resets to `opus` at the start of each review cycle (strongest first)."

### 8. Overview says "until either all reviews pass or the max review limit" — outdated

The Overview section (line 21) says:

> This loop continues until either all reviews pass or the max review limit is reached.

But the exit condition was revised to "two consecutive clean reviews" in post-review 3. The overview still uses the old language. Minor inconsistency but it's the first thing someone reads.

**Recommendation:** Update the overview to say: "This loop continues until two consecutive reviews find no issues, or the max review limit is reached (in which case the agent waits for user input)."

## Summary

The plan is essentially implementation-ready. The remaining issues are polish and precision:

- **False-positive heuristic** (#1): Keyword matching will misfire on "No issues found". Use a structured `VERDICT: PASS/FAIL` line instead.
- **Hook checking remaining tasks** (#2): Move task-count logic from the hook to the action prompts. Keep the hook simple.
- **continue-task mode detection** (#3): Should preserve existing `next_phase` rather than guessing standalone vs automated.
- **Missing all-code-review block template** (#4): The fourth review type has no block message template.
- **`max_reviews: 0` semantics** (#5): Hard stop vs. skip-and-proceed needs a deliberate choice.
- **Tasks review prompt missing** (#6): The concrete CLI prompt is not shown.
- **Model reset documentation** (#7): Minor — add a note that opus always goes first per cycle.
- **Overview language outdated** (#8): Minor — update to reflect two-consecutive-clean exit.
