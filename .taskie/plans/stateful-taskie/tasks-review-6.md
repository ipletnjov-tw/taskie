# Tasks Review 6 — Clean Slate

This is a clean-slate review of `tasks.md` and all 6 task files, verified against `plan.md`. No prior review files were consulted.

## Summary

The task list and task files are in excellent shape after 5 rounds of review. The structure is well-organized, prerequisites are correct, acceptance criteria are detailed and actionable, and the tasks faithfully map to the plan. I found **0 blocking issues**, **0 critical issues**, and **4 minor issues**.

---

## Issues

### Issue #1 — Minor: Task 3 subtask 3.3 remaining-tasks grep pattern has a fragile match

**File**: `task-3.md`, line 70

**Details**: The remaining-tasks check is:
```bash
grep '^|' tasks.md | grep -v "^| *${CURRENT_TASK} " | awk -F'|' '{print $3}' | grep -i 'pending' | wc -l
```

The `grep -v "^| *${CURRENT_TASK} "` pattern assumes the current task ID is followed by a space. If `CURRENT_TASK=1`, the pattern `^| *1 ` will also exclude rows for task IDs 10, 11, 12, etc. (since `1 ` matches the beginning of `10 `, `11 `, etc. depending on whitespace). For plans with more than 9 tasks, this is a real bug.

Additionally, this grep command is exactly the same as what's in the plan (plan.md step 5g describes this same logic at a higher level but delegates the exact implementation to the task file). Since the plan doesn't prescribe the exact shell command, the task file should fix this pattern.

**Recommendation**: Use a more precise match that anchors to the Id column boundaries:
```bash
grep '^|' tasks.md | tail -n +3 | awk -F'|' -v cur="${CURRENT_TASK}" '{gsub(/[[:space:]]/, "", $2); if ($2 != cur) print $3}' | grep -i 'pending' | wc -l
```
This uses `tail -n +3` to skip header/separator (consistent with `TASK_FILE_LIST` construction), and uses awk to compare the stripped Id column exactly, avoiding partial matches.

### Issue #2 — Minor: Task 2 subtask 2.5 version bump claim may be premature

**File**: `task-2.md`, subtask 2.5, acceptance criteria

**Details**: The acceptance criteria says "MAJOR: 2.2.1 → 3.0.0". However, per CLAUDE.md versioning rules, a MAJOR bump is for "breaking changes that require users to update their setup or workflows." While replacing the validation hook with a unified stop hook is a significant internal change, the user-facing behavior for the validation-only path is preserved unchanged. The MAJOR-breaking change is the stateful workflow itself, which spans multiple tasks (not just Task 2).

Doing a MAJOR bump in Task 2 (before the stateful features are actually functional) means users who install v3.0.0 after Task 2 get a version that implies breaking changes but doesn't yet deliver the new workflow. The version bump should arguably happen in the LAST task (Task 6) or as a separate final step, once all features are integrated and working.

That said, this is really a project management decision for the human operator, not a correctness issue. The task file correctly flags it as a MAJOR bump, which is directionally correct.

**Recommendation**: Consider moving the version bump to Task 6 (subtask 6.3 or a new subtask) so the MAJOR version reflects the complete feature, not an intermediate state. Or accept the current approach if intermediate releases are not a concern (since this is a feature branch).

### Issue #3 — Minor: Task 3 subtask 3.5 test count allocation is ambiguous

**File**: `task-3.md`, subtask 3.5

**Details**: The subtask says to "write tests alongside implementation" in subtasks 3.1-3.4, but then subtask 3.5 is a separate subtask for "Write test suites 2-5" with 51 tests total. The acceptance criteria explicitly list all 4 test files and their counts (21 + 16 + 14 = 51). This creates ambiguity: should tests be committed with each implementation subtask (3.1-3.4 as the short description says) or as a separate subtask 3.5?

The subtask description says "Write tests alongside implementation: as you complete each implementation subtask (3.1-3.4), immediately write and commit the corresponding tests." But the subtask still exists as a separate entry, which could confuse the implementer about whether 3.5 is a real subtask or just a tracking placeholder.

**Recommendation**: Clarify that subtask 3.5 is a tracking/verification subtask that ensures all tests are present and passing after 3.1-3.4 are done, not a separate implementation phase. Or remove 3.5 and fold the test acceptance criteria into each of 3.1-3.4.

### Issue #4 — Minor: Task 6 subtask 6.3 test file name doesn't match plan

**File**: `task-6.md`, subtask 6.3, acceptance criteria

**Details**: The acceptance criteria says tests go in `tests/hooks/test-stop-hook-edge-cases.sh`. However, the plan's test infrastructure section (plan.md, Testing section, File Organization) does NOT list this file. The plan only lists:
```
test-stop-hook-validation.sh
test-stop-hook-auto-review.sh
test-stop-hook-state-transitions.sh
test-stop-hook-cli-invocation.sh
```

Suite 6 (edge cases & integration, 12 tests) is described in the plan but no specific file is assigned to it. The task file assigns it to `test-stop-hook-edge-cases.sh`, which is a reasonable choice but deviates from the plan's explicit file organization.

**Recommendation**: Either update the plan's file organization section to include `test-stop-hook-edge-cases.sh`, or note in the task file that this is an addition beyond what the plan's file tree shows. This is a very minor documentation consistency issue.

---

## Verification Checklist

| Check | Result |
|-------|--------|
| Task count matches plan scope | PASS — 6 tasks cover all plan sections: test infra, validation migration, auto-review, planning actions, task/review actions, ground rules/codex/edge cases |
| Prerequisites form a valid DAG | PASS — Task 1 → Task 2 → Tasks 3,4,5 (parallel) → Task 6 |
| No circular dependencies | PASS |
| All plan sections have corresponding tasks | PASS — State file design (Tasks 2-3), hook design (Tasks 2-3), action file changes (Tasks 4-5), ground rules (Task 6), Codex (Task 6), testing (Tasks 1,3,6), validation (Task 2) |
| Test counts match plan | PASS — 17 + 15 + 16 + 14 + 6 + 12 = 80 total across 6 suites |
| state.json schema (8 fields) consistently referenced | PASS — All task files that mention state initialization list all 8 fields |
| Atomic write pattern documented | PASS — Referenced in Tasks 2-5 where state writes occur |
| `TASK_FILE_LIST` construction matches plan | PASS — Task 3 subtask 3.2 reproduces the exact `grep | tail | awk` pipeline from plan.md |
| Hook steps mapped to tasks | PASS — Steps 1-4,6 in Task 2; Step 5 in Task 3 |
| All 12+ action files accounted for | PASS — Tasks 4-5 cover all action files mentioned in the plan |
| Version bump mentioned | PASS — Task 2 subtask 2.5 |
| Codex scope limited per plan | PASS — Only `taskie-new-plan.md` and `taskie-continue-plan.md` updated (Task 6) |
| No scope creep beyond plan | PASS — No tasks add features not described in the plan |
| No timeline estimates | PASS — No time estimates in any task file |

---

## Verdict

**PASS** — The task list and task files are well-structured and faithfully implement the plan. The 4 minor issues are non-blocking quality improvements that can be addressed at the implementer's discretion. No blocking or critical issues were found.
