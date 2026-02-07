# Plan Review 5 — Stateful Taskie

The plan has been through four review cycles and is in excellent shape. The VERDICT: PASS/FAIL structured output, simplified hook logic, and concrete CLI prompts for all four review types resolve the major implementation ambiguities. This review is a final scrutiny focused on correctness of the complete system, edge cases in the interaction between components, and anything a developer would get wrong on first implementation attempt.

## Issues

### 1. The `max_reviews: 0` auto-advance path doesn't update state correctly

Step 5b says: increment `phase_iteration` to 1, check `1 <= 0` = false, skip to step 6. Step 6a says: `phase_iteration > max_reviews AND max_reviews > 0` — since `max_reviews` is 0, this is false. So the hook falls through to step 6b (validation).

But the state is now inconsistent. The hook incremented `phase_iteration` to 1 in step 5a, but never wrote it back (step 5g is the write path for `consecutive_clean < 2`, and step 5f is the write path for auto-advance). The hook jumped from 5b directly to 6. If the hook doesn't write `state.json` in this path, `phase_iteration` remains 0 on disk but the in-memory value was 1.

More importantly: `next_phase` is still `"code-review"`. The hook approves the stop, the agent stops, and on the next stop attempt the hook fires again — incrementing `phase_iteration` to 1 again, failing the `<= 0` check again, approving again. This is an infinite cycle of the agent stopping and restarting. The state never advances.

**Recommendation:** When `max_reviews` is 0 and the hook skips the review in step 5b, the hook should also clear `next_phase` (set it to null or to the advance target) before approving. Otherwise the review trigger persists in state and will fire on every subsequent stop. Add an explicit early-return path: if `max_reviews == 0`, set `next_phase` to the advance target (same as step 5f auto-advance targets), write state, and approve. This way `max_reviews: 0` genuinely means "skip reviews and proceed."

### 2. Step 5f auto-advance writes `phase` to the review phase — should it?

Step 5f says: "Set `phase` to the review phase, update `next_phase` to the advance target."

So after two consecutive clean code reviews, the state becomes:
```json
{"phase": "code-review", "next_phase": "next-task", ...}
```

Then the hook approves the stop. When the agent resumes (or the user runs `continue-plan`), `continue-plan` routes on `next_phase: "next-task"` and executes `next-task`. This works.

But `phase: "code-review"` is misleading — the code review is done. The last *completed* action was "code review passed." A more accurate `phase` would be something like `"post-code-review"` (the last thing the agent did before the reviews passed) or even `"code-review-passed"`. However, introducing new phase values would complicate the phase enum.

**Verdict:** This is cosmetic. The routing logic keys on `next_phase`, not `phase`, during `continue-plan`. Leaving `phase` as `"code-review"` is acceptable since it represents "the last review cycle that ran" and `next_phase` is what drives the workflow forward. No change needed, but worth noting for documentation: `phase` represents "the last review cycle context" when auto-advance fires, not "what the agent is currently doing."

### 3. Block message templates instruct the agent to set `next_phase: "code-review"` but this conflicts with the `continue-plan` routing

The code review block message says: `set next_phase to "code-review"`.

Meanwhile, `continue-plan` routing says:
> `next_phase` = `"code-review"` → the hook will handle this on the next stop. The agent should verify whether the current task/phase has outstanding work. If there is outstanding work, execute `continue-task.md`. If all work is already committed, the agent should simply stop to trigger the hook.

So the flow is: hook blocks → agent reads review → agent fixes code → agent writes `next_phase: "code-review"` → agent stops → hook fires → hook runs next review.

But what if the agent crashes between writing state and stopping? State now shows `phase: "post-code-review"`, `next_phase: "code-review"`. The user runs `continue-plan`. It sees `next_phase: "code-review"` and tries to determine if there's outstanding work. How? It checks git status? It reads the task file? The plan doesn't specify the mechanism for "verify whether the current task/phase has outstanding work."

This is a crash recovery path that will be hit in practice (agent context windows fill up, sessions time out, etc.). The `continue-plan` routing for review phases needs a concrete heuristic.

**Recommendation:** Define the "outstanding work" check. A simple approach: if `phase` is `"post-code-review"` (or any post-review phase) AND `next_phase` is a review phase, the post-review was completed (the agent set `next_phase` as its last act). The agent can simply stop to trigger the hook. If `phase` is NOT a post-review phase but `next_phase` is a review phase, the agent was in the middle of implementation when it crashed (e.g., `complete-task` set `next_phase: "code-review"` but the agent hasn't finished implementing). In this case, run `continue-task`. The distinction is: **was `phase` already set to a post-review value?** If yes, the work is done; if no, it's still in progress.

### 4. The `all-code-review` CLI prompt doesn't read the actual source code

The all-code-review prompt says:
> "Read the ground rules..., then read .taskie/plans/${PLAN_ID}/plan.md, .taskie/plans/${PLAN_ID}/tasks.md, and all .taskie/plans/${PLAN_ID}/task-*.md files. Perform the all-code-review action..."

But this only reads the plan documents and task descriptions. The whole point of `all-code-review` is to review the **code** across all tasks. The current `all-code-review.md` action (from the codebase) says "Review ALL of the code written as part of implementing all tasks." Reading task files gives context on what was implemented, but the reviewer subprocess also needs to read the actual source files.

The code review prompt has the same issue — it reads `task-${CURRENT_TASK}.md` but doesn't explicitly instruct the CLI to read the source files. However, the existing `code-review.md` action already says to review the code, and the `claude` CLI with `--dangerously-skip-permissions` can read any file. The action file itself should guide the subprocess to find and read the relevant source code.

**Verdict:** This is acceptable as-is. The action file (`code-review.md` / `all-code-review.md`) tells the reviewer what to do, and the reviewer subprocess has full tool access to read source files. The CLI prompt provides context (ground rules, plan, tasks), and the action file provides instructions. The subprocess will use its tools to read whatever code it needs. No change needed to the CLI prompt — but the action file instructions must be clear that the reviewer should read and review the actual source code, not just the task descriptions.

### 5. The `new-plan.md` action initializes `max_reviews` but there's no way to specify it

Action item #2 says `new-plan` initializes `state.json` with `max_reviews: 8`. But what if the user wants a different default? The user can change it mid-plan by editing `state.json`, but there's no way to specify it upfront.

The current design says `max_reviews` defaults to 8 and "can be changed mid-plan." This works — the user edits `state.json` after `new-plan` runs. But this is a poor UX for a setting that many users will want to customize. The user has to remember to edit JSON manually after every `new-plan`.

**Recommendation:** Minor UX improvement (can be deferred to a future version): allow `max_reviews` to be specified as an argument to `new-plan`, e.g., `/taskie:new-plan max_reviews=4 <description>`. The action parses it and uses it instead of the default. If not specified, defaults to 8. This is a nice-to-have, not a blocker.

### 6. The hook's step 5a increments `phase_iteration` unconditionally but step 5f uses the *unwritten* incremented value

Walk through the auto-advance path carefully:

1. State: `{phase_iteration: 3, consecutive_clean: 1, next_phase: "code-review"}`
2. Step 5a: increment `phase_iteration` to 4 (in-memory only, not yet written)
3. Step 5b: `4 <= 8` = true, continue
4. Step 5c: run `claude` CLI, writes review file `*-review-4.md`
5. Step 5e: check VERDICT. It's PASS. `consecutive_clean` becomes 2 (in-memory).
6. Step 5f: `consecutive_clean >= 2` — auto-advance! Set `phase: "code-review"`, `next_phase: "next-task"`.

Now: what value of `phase_iteration` is written? Step 5f says to update `next_phase` to the advance target and approve, but doesn't explicitly say to write `phase_iteration: 4` or `consecutive_clean: 2`. If the hook only writes `phase` and `next_phase` in step 5f, the on-disk state still shows `phase_iteration: 3` and `consecutive_clean: 1`.

Step 5g is the write path for the `consecutive_clean < 2` case, and it explicitly lists: "write the incremented `phase_iteration`, toggle `review_model`, write `consecutive_clean`."

But step 5f has no such explicit write list. It says "Set `phase` to the review phase, update `next_phase` to the advance target" — that's only 2 fields.

**Recommendation:** Step 5f should explicitly state which fields to write. At minimum: `phase`, `next_phase`, `phase_iteration` (incremented), `review_model` (toggled), `consecutive_clean` (incremented). The full atomic write should include all modified fields. Otherwise the auto-advance path leaves stale values in `phase_iteration`, `review_model`, and `consecutive_clean`.

### 7. Block message templates have inconsistent `keep all other fields` phrasing

Code review template:
> Keep all other fields (max_reviews, current_task, phase_iteration, review_model, consecutive_clean) unchanged.

All-code-review template:
> Keep all other fields (max_reviews, current_task, phase_iteration, review_model, consecutive_clean) unchanged.

Plan review template:
> Keep all other fields unchanged.

Tasks review template:
> Keep all other fields unchanged.

The plan review and tasks review templates don't enumerate which fields to keep. While "all other fields" is technically unambiguous, the explicit enumeration in the code review and all-code-review templates is better — it prevents the agent from accidentally omitting a field it didn't know about.

**Recommendation:** Add the explicit field list to all four block message templates for consistency: `(max_reviews, current_task, phase_iteration, review_model, consecutive_clean)`.

### 8. Test suite 3 test 11 expects `next_phase: "next-task"` but the action that discovers no remaining tasks hasn't run yet

Test 11: "Two clean reviews → auto-advance state" expects `next_phase: "next-task"`.

This is correct for the hook's behavior — the hook always sets `next_phase: "next-task"` for code review auto-advance (per issue #2 fix in post-review-4). But the test description in Suite 6, test 11 says: "sets next_phase to advance target."

For plan review auto-advance, the advance target is `"create-tasks"`. For tasks review, it's `"next-task"`. For code review, it's `"next-task"`. For all-code-review, it's `"complete"`.

Suite 3 test 11 only tests code review auto-advance. There are no tests for auto-advance from other review types. Suite 6 test 11 tests the integration flow but also only for the generic "advance target."

**Recommendation:** Add auto-advance state transition tests for each review type: plan review → `"create-tasks"`, tasks review → `"next-task"`, all-code-review → `"complete"`. Suite 3 should have tests 13-15 covering these, ensuring the hook maps each review type to the correct advance target. Currently the mapping is only described in step 5f prose — without tests, it's easy to get wrong during implementation.

## Summary

The plan is implementation-ready with a few precision fixes needed:

- **`max_reviews: 0` state persistence** (#1): The skip path doesn't write state, leaving `next_phase` stuck in a loop. Needs an explicit early-return that advances state.
- **Step 5f auto-advance incomplete write** (#6): Only writes `phase` and `next_phase`, leaving `phase_iteration`, `review_model`, and `consecutive_clean` stale. Needs the full field list.
- **`continue-plan` crash recovery heuristic undefined** (#3): "Verify outstanding work" has no concrete mechanism. Use `phase` value to distinguish.
- **Block message field lists inconsistent** (#7): Plan/tasks templates don't enumerate preserved fields.
- **Missing auto-advance tests per review type** (#8): Only code review auto-advance is tested.
- **Cosmetic / deferrable**: Step 5f `phase` value (#2), all-code-review source code reading (#4), `max_reviews` as argument (#5).

VERDICT: FAIL
