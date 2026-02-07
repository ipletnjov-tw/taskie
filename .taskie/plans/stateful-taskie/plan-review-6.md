# Plan Review 6 — Stateful Taskie (Clean Slate)

Fresh review of the complete plan, ignoring all previous review cycles. Reading the plan as a developer who needs to implement it from scratch.

## Issues

### 1. The hook reads stdin but the plan never mentions stdin

The existing `validate-ground-rules.sh` reads its input from stdin via `EVENT=$(cat)`. The JSON contains fields like `cwd`, `stop_hook_active`, etc. The plan describes the hook logic in detail (steps 1-6) but never explicitly states that the hook receives its input via stdin, nor documents the expected input JSON schema.

Step 1 says "Check `stop_hook_active`" — but where does this field come from? A developer looking only at the plan would not know it's a field in the stdin JSON payload, nor would they know that `cwd` is how the hook discovers the working directory.

Step 3 says "Find the most recently modified plan directory" — the plan doesn't say how the hook knows where to look. The existing hook uses `cwd` from the stdin JSON to `cd` into the project directory, then searches `.taskie/plans`.

**Recommendation:** Add a brief "Hook Input" subsection before step 1 documenting:
- Hook receives JSON on stdin with at least `cwd` (working directory) and `stop_hook_active` (boolean)
- Hook outputs JSON on stdout: `{"decision": "block", "reason": "..."}` to block, or `{"suppressOutput": true}` / `{"systemMessage": "...", "suppressOutput": true}` to approve
- Exit code 0 = success (approve or block), exit code 2 = fatal error (invalid input)

### 2. `complete-task` currently has a 3-cycle review cap — the plan removes it but doesn't acknowledge the behavioral change

The existing `complete-task.md` says: "Maximum of 3 code-review <-> post-code-review cycles per task. If issues remain after 3 cycles, pause and request human input."

The plan replaces this with `max_reviews: 8` (default) and hook-based automation. This is a significant behavioral change: the review cap goes from 3 to 8, and the mechanism shifts from the action prompt's internal loop to the hook + state machine.

The plan never mentions this difference or explains why 8 was chosen over 3. A developer implementing the plan might wonder if the old 3-cycle cap should be preserved somewhere.

**Recommendation:** Add a brief note in the `complete-task` action item (#5) acknowledging: "This replaces the existing 3-cycle review cap in `complete-task.md` with the global `max_reviews` setting (default 8). The cap is now enforced by the hook, not by the action prompt. The higher default allows more thorough automated review cycles since the two-consecutive-clean exit condition typically terminates earlier."

### 3. `next-task` delegates to `next-task-tdd` confusingly in action item #5

Action item #5 says: "They delegate implementation to `next-task.md` / `next-task-tdd.md` internally."

But `complete-task` delegates to `next-task`, and `complete-task-tdd` delegates to `next-task-tdd`. The sentence structure makes it sound like both `complete-task` and `complete-task-tdd` delegate to both `next-task` and `next-task-tdd`, which is wrong.

**Verdict:** Minor wording ambiguity. The slash means "respectively" but could be read as "or". Not a blocker — a developer reading both action files would understand the mapping. No change needed.

### 4. The `continue-plan` routing table has a gap: `next_phase = "complete"`

The `continue-plan` routing covers `next_phase` values: post-review phases, review phases, `"next-task"` / `"next-task-tdd"`, `"create-tasks"`. It also covers `phase = "complete"` when `next_phase` is null.

But what if `next_phase = "complete"`? This happens after all-code-review auto-advance (step 5g sets `next_phase: "complete"` for all-code-review). If the agent crashes between the hook writing state and the agent actually stopping, `continue-plan` sees `next_phase: "complete"` and... has no routing rule for it.

The `next_phase` is non-null, so the "When `next_phase` is null" branch doesn't apply. The `next_phase` is `"complete"`, which isn't a post-review phase, isn't a review phase, isn't `"next-task"`, and isn't `"create-tasks"`.

**Recommendation:** Add a routing rule for `next_phase = "complete"`: set `phase: "complete"`, `next_phase: null`, and inform the user all tasks are done. This is the same behavior as the `phase = "complete"` case in the null branch — it just needs to be reachable from the non-null branch too.

### 5. Step 5a references "same mapping as step 5f" but step 5f doesn't exist anymore

Post-review 5 added step 5a for `max_reviews == 0` and renumbered steps. Step 5a says: "Set `next_phase` to the advance target (same mapping as step 5f: ...)."

But step 5f is now "Determine if the review is clean." The advance target mapping is in step 5g. This is a stale cross-reference from the renumbering.

**Recommendation:** Update step 5a to reference step 5g instead of step 5f.

### 6. The hook script's `PLUGIN_ROOT` resolution assumes the hook is always at `hooks/stop-hook.sh`

The plan says: `PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` — this resolves correctly when the hook lives at `taskie/hooks/stop-hook.sh`.

But Claude Code plugins are installed to a cache directory. The actual hook path will be something like `~/.claude/plugins/cache/taskie/taskie/2.2.1/hooks/stop-hook.sh`. The `..` resolves to `~/.claude/plugins/cache/taskie/taskie/2.2.1/` — which IS the plugin root containing `actions/`, `ground-rules.md`, etc. So this is correct.

**Verdict:** Works correctly. The `BASH_SOURCE[0]` approach resolves to the installed cache location, which has the full plugin directory structure. No change needed.

### 7. The plan doesn't specify what happens when the `next-task` action discovers no remaining tasks during auto-advance

Step 5g says the hook sets `next_phase: "next-task"` for code review auto-advance and the action figures out there are no remaining tasks. But the plan only says "The `continue-plan`/`next-task` action reads `tasks.md`, discovers there are no remaining tasks, and sets `next_phase: 'all-code-review'` itself."

Which action does this? `continue-plan`? `next-task`? Both? The sentence uses a slash but they're different actions with different responsibilities. If `continue-plan` routes to `next-task` and `next-task` discovers no remaining tasks, does `next-task` set `next_phase: "all-code-review"` (overriding the null it would normally set as a standalone command)? Or does `continue-plan` check first and route to `all-code-review` instead?

**Recommendation:** Clarify: `next-task` should check `tasks.md` for remaining pending tasks. If none are pending, it should set `phase: "next-task"`, `next_phase: "all-code-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0` (entering a new review cycle). This is an exception to the "standalone = null" rule — when `next-task` is invoked via auto-advance (i.e., the current `next_phase` in state was `"next-task"`), it should check if there are remaining tasks and route accordingly. The action can detect this by reading the current `next_phase` before overwriting: if it was `"next-task"` (set by hook auto-advance), it's in automated mode and should advance to `all-code-review` when no tasks remain.

### 8. `new-plan` initializes `state.json` but doesn't set `current_task: null` explicitly in the action description

Action item #2 lists the fields set by `new-plan`: `phase: "new-plan"`, `next_phase: "plan-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`. That's 5 fields. But `state.json` has 7 fields. Missing: `max_reviews` and `current_task`.

The schema says `max_reviews` defaults to 8 and `current_task` is null during planning. But the action item doesn't mention setting these. A developer implementing this would have to infer the missing values.

**Recommendation:** List all 7 fields explicitly in the `new-plan` action item: `max_reviews: 8`, `current_task: null`, `phase: "new-plan"`, `next_phase: "plan-review"`, `phase_iteration: 0`, `review_model: "opus"`, `consecutive_clean: 0`.

Similarly, action #3 (`create-tasks`) and #5 (`complete-task`) should list all 7 fields — they currently omit `max_reviews` and sometimes `current_task`. The atomic write rule says "always read-modify-write", so technically these actions read the existing `max_reviews` and preserve it. But for a brand-new `state.json` in `new-plan`, there's nothing to read — the action constructs the file from scratch.

## Summary

The plan is comprehensive and well-thought-out. The state machine design, hook logic, atomic writes, and testing strategy are all solid. The issues found are:

- **Hook I/O undocumented** (#1): stdin/stdout protocol not described — a developer implementing the hook needs this.
- **Behavioral change unacknowledged** (#2): 3-cycle cap → 8-cycle cap is a significant change worth noting.
- **`next_phase: "complete"` gap in routing** (#4): `continue-plan` has no rule for this reachable state.
- **Stale step reference** (#5): Step 5a references 5f instead of 5g after renumbering.
- **No-remaining-tasks routing ambiguous** (#7): Which action detects no remaining tasks and transitions to all-code-review?
- **Incomplete field lists in action items** (#8): `new-plan` and others omit `max_reviews` and `current_task`.
- **Minor/no-change**: Wording ambiguity in #3, PLUGIN_ROOT resolution in #6.

VERDICT: FAIL
