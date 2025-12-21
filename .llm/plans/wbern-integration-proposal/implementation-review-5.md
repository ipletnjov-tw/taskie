# Implementation Review 5 - Comprehensive 30-Angle Review

## Summary

Brutal, ruthless review of all TDD integration changes from 30 distinct angles.

**Files reviewed**: 23 files changed, 729 insertions, 5 deletions

---

## Angle 1: Variable Naming Consistency

**Status**: 🚨 BLOCKING

**Issues**:
1. `next-task.md` uses `{next-task-id}` but `next-task-tdd.md` uses `{current-task-id}` - inconsistent naming for the same concept
2. `complete-task.md` references `{current-plan-dir}` but doesn't define `{current-task-id}` even though it calls actions that use it

**Files**:
- `.llm/actions/next-task.md:5` vs `.llm/actions/next-task-tdd.md:17`

---

## Angle 2: Plugin Persona Distribution

**Status**: 🚨 BLOCKING

**Issue**: `taskie/personas/` only contains `tdd.md`. Missing 5 personas that exist in `.llm/personas/`:
- `swe.md`
- `writer.md`
- `qa.md`
- `designer.md`
- `reviewer.md`

Plugin users cannot use any persona except TDD.

**Files**: `taskie/personas/` directory

---

## Angle 3: TDD Persona Not Discoverable

**Status**: ⚠️ ADVISORY

**Issue**: The TDD persona exists but is never referenced anywhere:
- Not mentioned in README.md
- Not mentioned in PROMPTS.md
- Not referenced in TDD commands
- Users won't know it exists or how to use it

---

## Angle 4: README Organization

**Status**: ⚠️ ADVISORY

**Issues**:
1. TDD Commands section is separated from Task Management Commands but `next-task-tdd` is conceptually a task management command
2. `complete-task-tdd` appears in BOTH "TDD Commands" and "Unified Workflow Commands" - redundant listing
3. No explanation of what TDD is or when to use TDD vs non-TDD

---

## Angle 5: PROMPTS.md Incomplete

**Status**: 🚨 BLOCKING

**Issue**: PROMPTS.md documents `complete-task.md` and `complete-task-tdd.md` but never mentions these are NEW actions. No indication they're different from `next-task`.

Also missing: any mention of how to use the TDD persona with these actions.

---

## Angle 6: Acceptance Criteria Orphaned

**Status**: ⚠️ ADVISORY

**Issue**: Added "Acceptance criteria" to `create-tasks.md` subtask template, but:
1. No existing subtasks have this field
2. `next-task-tdd.md` says "Write ONE failing test based on acceptance criteria" but doesn't handle missing criteria
3. The escape hatch for untestable subtasks doesn't apply when acceptance criteria is missing (different problem)

---

## Angle 7: Test Frequency Ambiguity

**Status**: ⚠️ ADVISORY

**Issue**: `next-task-tdd.md` says "Run tests to confirm failure/success" but:
1. Doesn't specify WHICH tests (all? just related? just the new one?)
2. Doesn't specify what to do if OTHER tests fail
3. No guidance on test isolation

---

## Angle 8: Commit Timing

**Status**: ⚠️ ADVISORY

**Issue**: `next-task-tdd.md` step 4 says "REPEAT until subtask is complete, then run all must-run commands and commit."

This means ONE commit per subtask. But the existing `next-task.md` also commits per subtask. So this is consistent, but the TDD action implies commits should happen after RED→GREEN→REFACTOR cycles, not after each cycle.

Ambiguity: When exactly should commits happen during TDD?

---

## Angle 9: Refactor Step Too Vague

**Status**: ⚠️ ADVISORY

**Issue**: REFACTOR step says "Improve structure only when tests pass. Run tests after each change."

Questions unanswered:
1. How much refactoring? Minimal? Comprehensive?
2. What counts as "structure"?
3. When is refactoring done?

---

## Angle 10: Silent Methodology Contradiction

**Status**: 🚨 BLOCKING

**Issue**: TDD persona says "I will never mention TDD in code, comments, commits, or documentation."

But:
- `next-task-tdd.md` exists (TDD in filename)
- Commands are named `next-task-tdd`, `complete-task-tdd` (TDD in names)
- README mentions "TDD Commands"
- The user requested TDD and will see TDD everywhere

The persona's "silent" instruction contradicts the entire implementation.

---

## Angle 11: Review Cycle Limit

**Status**: ⚠️ ADVISORY

**Issue**: `complete-task.md` says "Maximum 3 review-fix cycles. If issues remain, pause and request human input."

Questions:
1. What counts as a "cycle"? Just the review, or review+fix?
2. Should the cycle count be tracked anywhere?
3. What if 4th cycle is needed for trivial issue?

---

## Angle 12: Phase 4 Redundancy

**Status**: ⚠️ ADVISORY

**Issue**: `complete-task.md` Phase 4 says "Update subtask status to 'completed' and task status to 'done', then push to remote."

But Phase 1 executes `next-task.md` which ALREADY updates status and pushes. This creates potential for double-updates or confusion about what Phase 4 actually needs to do.

---

## Angle 13: Ground Rules Reference

**Status**: ✅ PASS

Both `.llm/` and `taskie/` versions correctly reference their respective ground-rules paths.

---

## Angle 14: Complete-Task Missing Task ID Reference

**Status**: ⚠️ ADVISORY

**Issue**: `complete-task.md` mentions `{current-plan-dir}` in Phase 4 fallback text but never mentions `{current-task-id}`. Yet Phase 1 calls an action that uses task IDs.

The action doesn't fully specify what context the LLM needs.

---

## Angle 15: No continue-task-tdd

**Status**: ⚠️ ADVISORY

**Issue**: There's a `continue-task.md` action for resuming interrupted work. But there's no `continue-task-tdd.md`. If TDD work is interrupted mid-cycle (say, after RED), how does the LLM resume?

The TDD cycle state is not persisted anywhere.

---

## Angle 16: Untestable Escape Hatch Vagueness

**Status**: ⚠️ ADVISORY

**Issue**: "For untestable subtasks (docs, config), skip directly to implementation and note in commit why TDD was skipped."

Problems:
1. What about other untestable scenarios? (UI-only changes, third-party integrations, infrastructure)
2. "Note in commit" - where exactly? Commit message? Commit body?
3. No structured format for the note

---

## Angle 17: TDD Persona Characteristics Overlap

**Status**: ⚠️ ADVISORY

**Issue**: TDD persona has overlapping characteristics:

- "Red-Green-Refactor": "I will write MINIMAL code"
- "No Over-Engineering": "I will never implement beyond what the current failing test requires"

These say the same thing twice. The persona could be more concise.

---

## Angle 18: Missing Test Examples

**Status**: ⚠️ ADVISORY

**Issue**: `next-task-tdd.md` doesn't provide any examples of what a "failing test" looks like or how to structure tests. The persona mentions "Arrange-Act-Assert" but the action doesn't reinforce this.

---

## Angle 19: Inconsistent Use of "MUST"

**Status**: ⚠️ ADVISORY

**Issue**: Inconsistent emphasis patterns:
- `next-task-tdd.md`: "You MUST implement ONLY ONE task"
- `next-task-tdd.md`: "You MUST NOT implement more than ONE task"
- `complete-task.md`: "You MUST complete ONLY ONE task"
- `complete-task.md`: "You MUST address ALL issues"

But:
- `complete-task.md`: "Maximum 3 review-fix cycles" (no MUST)
- `next-task-tdd.md`: "Do NOT write implementation yet" (different emphasis)

Inconsistent emphasis reduces clarity.

---

## Angle 20: README Doesn't Explain When to Use Each Command

**Status**: ⚠️ ADVISORY

**Issue**: README lists commands but doesn't explain:
1. When to use `next-task` vs `complete-task`
2. When to use TDD vs non-TDD variants
3. Why you'd choose one workflow over another

Users are left to guess.

---

## Angle 21: No Rollback Guidance

**Status**: ⚠️ ADVISORY

**Issue**: If `complete-task` fails after Phase 1 (implementation done) but during Phase 2/3 (review loop), there's no guidance on how to rollback or abandon.

---

## Angle 22: Version Bump Without Changelog

**Status**: ⚠️ ADVISORY

**Issue**: Version bumped from 1.1.5 to 1.2.0 but:
1. No CHANGELOG.md file exists
2. No release notes
3. Users can't see what changed between versions

---

## Angle 23: Subtask Status Values

**Status**: ⚠️ ADVISORY

**Issue**: `create-tasks.md` defines subtask statuses as:
`(pending / awaiting-review / review-changes-requested / completed / postponed)`

But the TDD workflow has implicit statuses not listed:
- "RED" (test written, failing)
- "GREEN" (test passing, minimal code)
- "REFACTOR" (improving structure)

TDD state not captured in status schema.

---

## Angle 24: Post-Review Fixes Scope

**Status**: ⚠️ ADVISORY

**Issue**: `complete-task.md` Phase 3 says "Execute action `.llm/actions/post-code-review.md`" and "You MUST address ALL issues."

But `post-code-review.md` says "Address the issues surfaced by the latest code review." It doesn't say "ALL issues" - it's actually ambiguous about scope.

The emphasis on "ALL" in `complete-task.md` may conflict with how `post-code-review.md` is interpreted.

---

## Angle 25: Command Descriptions Inconsistent

**Status**: ⚠️ ADVISORY

**Issue**: Command descriptions have inconsistent formats:
- `next-task-tdd.md`: "Implement next task using strict TDD (red-green-refactor)."
- `complete-task.md`: "Complete task with automatic review cycle (implement + review + fix)."
- `complete-task-tdd.md`: "Complete task with TDD and automatic review cycle."

The TDD command doesn't mention red-green-refactor in its description like `next-task-tdd` does.

---

## Angle 26: $ARGUMENTS Not Documented

**Status**: ⚠️ ADVISORY

**Issue**: All command files include `$ARGUMENTS` but:
1. README doesn't explain what additional arguments are useful
2. No examples of TDD-specific arguments
3. No documentation on how arguments affect TDD behavior

---

## Angle 27: Complete-Task Doesn't Update Task File Summary

**Status**: 🚨 BLOCKING

**Issue**: `next-task.md` says: "document your progress with a short summary in `.llm/plans/{current-plan-dir}/task-{next-task-id}.md`"

But `complete-task.md` Phase 4 only says: "Update subtask status to 'completed' and task status to 'done', then push to remote."

It forgets to mention writing the summary! The summary step is lost.

---

## Angle 28: TDD + Review Redundancy

**Status**: ⚠️ ADVISORY

**Issue**: TDD already includes running tests after every step. Then `complete-task-tdd` runs code-review which "Double check ALL the must-run commands."

This is redundant - tests were already run during TDD. The review phase doesn't add value for test verification in TDD workflow.

---

## Angle 29: Persona Format Inconsistency

**Status**: ⚠️ ADVISORY

**Issue**: Comparing TDD persona to existing personas:

TDD persona line 11:
"**Test Quality**: I should follow Arrange-Act-Assert. I will use stable selectors over brittle ones."

Other personas (swe.md line 13):
"**High Quality**: I should write clean, readable code with comprehensive tests."

TDD persona mixes concrete techniques (AAA, selectors) with vague statements. Other personas are more consistent in abstraction level.

---

## Angle 30: No Integration with Existing Workflows

**Status**: ⚠️ ADVISORY

**Issue**: `continue-plan.md` dispatches based on task state:
- "If the task is in-progress, execute action `.llm/actions/continue-task.md`."
- "If the task's latest review is positive, execute action `.llm/actions/next-task.md`."

It has no awareness of TDD variants. A user who was using TDD and lost context would be resumed with non-TDD workflow.

---

## Summary Table

| # | Angle | Status | Count |
|---|-------|--------|-------|
| 1 | Variable naming consistency | 🚨 | 2 issues |
| 2 | Plugin persona distribution | 🚨 | 5 missing files |
| 3 | TDD persona not discoverable | ⚠️ | 1 issue |
| 4 | README organization | ⚠️ | 3 issues |
| 5 | PROMPTS.md incomplete | 🚨 | 2 issues |
| 6 | Acceptance criteria orphaned | ⚠️ | 3 issues |
| 7 | Test frequency ambiguity | ⚠️ | 3 issues |
| 8 | Commit timing | ⚠️ | 1 issue |
| 9 | Refactor step vague | ⚠️ | 3 issues |
| 10 | Silent methodology contradiction | 🚨 | 1 major issue |
| 11 | Review cycle limit | ⚠️ | 3 issues |
| 12 | Phase 4 redundancy | ⚠️ | 1 issue |
| 13 | Ground rules reference | ✅ | Pass |
| 14 | Complete-task missing task ID | ⚠️ | 1 issue |
| 15 | No continue-task-tdd | ⚠️ | 1 issue |
| 16 | Untestable escape hatch vague | ⚠️ | 3 issues |
| 17 | TDD persona overlap | ⚠️ | 1 issue |
| 18 | Missing test examples | ⚠️ | 1 issue |
| 19 | Inconsistent MUST usage | ⚠️ | Multiple |
| 20 | README doesn't explain when to use | ⚠️ | 3 issues |
| 21 | No rollback guidance | ⚠️ | 1 issue |
| 22 | Version bump without changelog | ⚠️ | 1 issue |
| 23 | Subtask status values | ⚠️ | 1 issue |
| 24 | Post-review fixes scope | ⚠️ | 1 issue |
| 25 | Command descriptions inconsistent | ⚠️ | 1 issue |
| 26 | $ARGUMENTS not documented | ⚠️ | 3 issues |
| 27 | Complete-task missing summary | 🚨 | 1 major issue |
| 28 | TDD + review redundancy | ⚠️ | 1 issue |
| 29 | Persona format inconsistency | ⚠️ | 1 issue |
| 30 | No integration with existing workflows | ⚠️ | 1 issue |

---

## Final Tally

**🚨 BLOCKING**: 5 issues (angles 1, 2, 5, 10, 27)
**⚠️ ADVISORY**: 24 angles with multiple issues each
**✅ PASS**: 1 angle

---

## Critical Blocking Issues Summary

1. **Variable naming** - `{next-task-id}` vs `{current-task-id}` inconsistency
2. **Plugin personas missing** - 5 of 6 personas not in plugin
3. **PROMPTS.md incomplete** - New actions not properly documented
4. **Silent TDD contradiction** - Persona says "never mention TDD" but TDD is in all names
5. **Summary step lost** - `complete-task.md` forgets to write progress summary

