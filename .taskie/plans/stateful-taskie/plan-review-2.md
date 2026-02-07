# Plan Review 2 — Stateful Taskie

The plan has improved significantly since review 1. The CLI invocation is corrected, the schema is cleaner, automation boundaries are explicit, and testing is thorough. This review focuses on remaining gaps and contradictions.

## Issues

### 1. Planning flow says "triggered by complete-task" — but complete-task doesn't create plans

The state transition diagram says:

> **Planning flow (triggered by `complete-task` or `complete-task-tdd`):**
> `new-plan → [STOP HOOK] plan-review ...`

But `complete-task` and `complete-task-tdd` don't invoke `new-plan`. They start at the implementation phase (delegating to `next-task`). There is no command that chains `new-plan` → plan-review → `create-tasks` → tasks-review → `next-task` → code-review in a single automated flow.

The user runs `/taskie:new-plan` to create a plan. That's a standalone command. According to the automation boundary rule, standalone commands set `next_phase: null`. So the hook would never trigger plan-review automatically.

For the planning flow diagram to be accurate, either:
- (a) `new-plan` must be an exception that always sets `next_phase: "plan-review"` (breaking the "standalone = null" rule), OR
- (b) There needs to be a new command (e.g., `complete-plan` or similar) that chains the full planning flow, OR
- (c) The planning flow is always manual (user invokes `plan-review` and `post-plan-review` themselves), and the diagram is misleading.

**Recommendation:** Option (a) is simplest. Make `new-plan` always set `next_phase: "plan-review"` since there's no scenario where you'd create a plan and NOT want it reviewed. Same for `create-tasks` always setting `next_phase: "tasks-review"`. The "standalone = null" rule should only apply to implementation commands (`next-task`, `code-review`, etc.) where the user might intentionally want to skip the review loop.

### 2. `phase_iteration` starts at 0 but is documented as "1-based"

The field definition says:
> Review iteration number (1-based).

But `complete-task.md` action item #5 says:
> they update `state.json` with `next_phase: "code-review"`, `phase_iteration: 0`, `review_model: "opus"`

And test suite 2, test 1 uses:
> `phase_iteration: 0`

And the hook increments it to 1 when the first review fires. So the iteration is actually 0-based in the state file and becomes 1-based in the review filename. This is confusing and error-prone.

The `max_reviews` comparison is `phase_iteration >= max_reviews`. If `phase_iteration` starts at 0 and the hook increments before comparing, then 8 iterations would run (0→1, 1→2, ..., 7→8, then 8>=8 stops). If the hook compares before incrementing, only 7 iterations would run. The plan doesn't specify the order of increment vs. compare.

**Recommendation:** Make it consistently 1-based. Initialize at `phase_iteration: 1` when entering a review cycle (not 0). The hook increments after each review, and the comparison `phase_iteration >= max_reviews` is checked before invoking the next review. This way: iter 1 → review → iter 2 → review → ... → iter 8 → review → iter 9 >= 8 → stop. That gives exactly `max_reviews` reviews. OR, keep 0-based but update the field definition to say "0-based" and specify: the hook reads the current value, checks `< max_reviews`, if yes runs the review then writes `phase_iteration + 1`. Document this explicitly.

### 3. How does the hook know `PLUGIN_ROOT`?

The CLI invocation references `${PLUGIN_ROOT}`:
```bash
"Read the ground rules in ${PLUGIN_ROOT}/ground-rules.md, ..."
```

But the hook script is invoked via `hooks.json` with:
```json
"command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh"
```

Inside the hook script, `${CLAUDE_PLUGIN_ROOT}` is available as a shell variable because `hooks.json` does the substitution. But when constructing the prompt string for the `claude` CLI subprocess, the hook needs to resolve this path to an absolute path (not pass the variable name literally).

The current `validate-ground-rules.sh` doesn't use `CLAUDE_PLUGIN_ROOT` at all — it gets `cwd` from the JSON stdin and works relative to the project directory. The new hook needs the plugin root to reference action files and ground-rules.

**Recommendation:** The hook should resolve the plugin root relative to its own location: `PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`. This works because the hook is at `hooks/stop-hook.sh` and the actions are at `actions/*.md` — one directory up. Document this in the hook design section.

### 4. Edge case test #6 logic is wrong

Test edge case #6:
> Combined: auto-review + validation failure → `next_phase: "code-review"` but plan dir has nested files → hook runs review first, then validation catches nested files → block with validation error

But according to the hook flow (step 5), if `next_phase` is a review phase, the hook runs the review and returns a block decision in step 5d. It never reaches step 6 (validation). The review block takes precedence.

Validation only runs when the hook falls through to step 6 (next_phase is NOT a review, or max reviews reached). So you can't get "review + validation failure" in a single hook execution — they're mutually exclusive paths.

**Recommendation:** Fix the test expectation: if `next_phase: "code-review"`, the hook runs the review and blocks. The nested files would only be caught on the next stop attempt (after post-review), when `next_phase` might no longer be a review phase. Alternatively, add validation as a pre-check in step 5 (before running the review), which would be a design change.

### 5. The hook doesn't update `state.json` atomically with file write

Step 5 of the hook flow says:
> b. Verify the review file was written to disk
> c. Update `state.json`

But what if the hook process is killed between writing the review file and updating `state.json`? The review file exists but the state still says `next_phase: "code-review"`. On next stop, the hook would run another review (overwriting the file) and then update state. This is wasteful but not catastrophic.

The reverse is worse but can't happen in this order (state updated before review written).

**Verdict:** This is acceptable. The plan's risk #6 already covers crash recovery. Not a real issue.

### 6. `all-code-review` has no clear trigger in the automation flow

The plan lists `all-code-review` as a valid `next_phase` value that the hook handles. But the state transition diagrams never show when it gets set. The implementation flows go:
```
next-task → code-review → ... → next-task (next task) → ... → complete
```

There's no transition to `all-code-review`. Who sets `next_phase: "all-code-review"`?

Looking at the existing `all-code-review.md` action, it's a cross-task review of ALL code. It makes sense as a final step after all tasks are done but before marking complete.

**Recommendation:** Add an explicit transition: after the last task's code review passes, set `next_phase: "all-code-review"` instead of `"complete"`. After all-code-review passes, then set `phase: "complete"`. Or, document that `all-code-review` is always a manual/standalone command and remove it from the hook's list of recognized review phases.

### 7. `--allowedTools` flag format may be wrong

The plan shows:
```bash
--allowedTools "Read Grep Glob Write Bash"
```

But looking at the `claude --help` output:
```
--allowedTools, --allowed-tools <tools...>   Comma or space-separated list of tool names
```

The flag takes a variadic argument (`<tools...>`). Wrapping all tools in a single quoted string may pass them as one argument rather than five. The correct format might be:
```bash
--allowedTools Read Grep Glob Write Bash
```
(without quotes, so each is a separate arg) or:
```bash
--allowedTools "Read,Grep,Glob,Write,Bash"
```
(comma-separated in one string).

**Recommendation:** Test the exact format during implementation. The plan should note that the flag format needs validation against the actual CLI behavior. Both space-separated and comma-separated should be tested.

### 8. Missing: what happens when `continue-plan` is invoked while in a `complete-task` automated workflow?

The `continue-plan` action routes based on `phase`. But during an automated `complete-task` workflow, the agent is cycling through implementation → review → post-review automatically. If the user interrupts (kills the session) and later invokes `/taskie:continue-plan`, the state might say:
- `phase: "code-review"`, `next_phase: "post-code-review"` (hook ran a review, agent was about to do post-review)

`continue-plan` would route to `code-review.md` (since `phase` = `"code-review"`). But the review file already exists — the agent should be doing post-review, not another review. The routing should look at `next_phase`, not `phase`.

**Recommendation:** `continue-plan` should route based on `next_phase` when it's non-null (that's the action the agent should do next). Only fall back to `phase` when `next_phase` is null.

### 9. No mechanism for the user to opt out of auto-review mid-workflow

Once `complete-task` starts the automation loop, the only way to stop it is hitting `max_reviews`. What if the user realizes after 2 review cycles that the reviews are going in circles and wants to stop? They'd have to either:
- Manually edit `state.json` to set `next_phase: null`
- Kill the agent and wait for it to stop
- Change `max_reviews` to 0

None of these are documented.

**Recommendation:** Document the escape hatch: the user can edit `state.json` and set `next_phase: null` to stop the loop. Or add a small note in the block message template that tells the user how to break the loop.

## Summary

The plan is in good shape. The remaining issues are:

- **Design contradiction** (#1): Planning flow can't be triggered by complete-task. Need to decide which commands set `next_phase` automatically.
- **Off-by-one risk** (#2): `phase_iteration` 0-based vs 1-based needs explicit ordering of increment vs. compare.
- **Hook needs PLUGIN_ROOT** (#3): Resolve via `BASH_SOURCE` relative path.
- **Test #6 is wrong** (#4): Auto-review and validation are mutually exclusive paths in one hook execution.
- **all-code-review untriggered** (#6): No transition in the automation flow sets it.
- **CLI flag format** (#7): `--allowedTools` quoting needs verification.
- **continue-plan routing** (#8): Should route on `next_phase`, not `phase`.
- **No user escape hatch** (#9): Need to document how to break the loop.
