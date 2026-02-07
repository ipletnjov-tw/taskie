# Tasks Review 1 — Stateful Taskie Implementation

**Review Date**: 2026-02-07
**Review Scope**: Clean slate review of all task files and tasks.md against plan.md
**Methodology**: Deep subagent analysis of each task group

---

## Executive Summary

The task breakdown has **CRITICAL GAPS** that must be addressed before implementation begins. While most tasks correctly capture the plan's requirements, Tasks 1-3 have significant missing pieces, incorrect assumptions, and implementation risks.

**Overall Assessment**: 6/10 — Requires substantial revisions

**Critical Issues Found**: 7
**High-Priority Warnings**: 5
**Medium-Priority Gaps**: 4

---

## Task 1: Test Infrastructure — NEEDS REVISION (7.5/10)

### Strengths
✅ Perfect scope alignment with plan requirements
✅ All three infrastructure components covered (helpers, mock CLI, test runner)
✅ Actually FIXES an outdated code sample in plan.md (mock Claude verdict format)
✅ Comprehensive acceptance criteria

### Critical Issues

**ISSUE 1-1: Task ownership confusion** (CRITICAL)
- The plan states test infrastructure "should be its own task" (line 637)
- BUT: Task 2 (validation migration) depends on test-utils.sh existing
- Task 1 creates the infrastructure but Tasks 2-3 also reference creating it
- **Resolution needed**: Clarify that Task 1 MUST complete before Task 2 begins

**ISSUE 1-2: Mock Claude verdict format** (RESOLVED)
- Task file correctly notes the plan's code sample is outdated
- Acceptance criteria properly specify JSON verdict output: `{"result":{"verdict":"PASS"}}`
- This matches the plan's updated specification (lines 189-228)
- ✅ No action needed — task file is correct

### Recommendations
1. Add explicit note in Task 1: "This task MUST complete before any other tasks begin"
2. Consider adding acceptance criterion: Mock should gracefully handle `--print`, `--model`, `--output-format json`, `--json-schema` flags (currently implied)

---

## Task 2: Unified Stop Hook — Validation Migration — INCOMPLETE (5/10)

### Strengths
✅ Correctly focuses on validation migration only (auto-review deferred to Task 3)
✅ All 17 tests from suite 1 accounted for
✅ Validation rules 1-7 correctly ported

### Critical Issues

**ISSUE 2-1: Missing test infrastructure creation** (CRITICAL)
- Subtask 2.3 refactors tests to use `test-utils.sh`
- BUT: Nothing in Task 2 creates `test-utils.sh`
- Task 1 creates it, but there's no dependency chain enforcement
- **Resolution**: Add prerequisite note: "Requires Task 1 completion"

**ISSUE 2-2: Missing test runner updates** (CRITICAL)
- Plan explicitly requires (lines 408-421):
  - Update `run-tests.sh` to accept suite arguments
  - Add `make test-state` and `make test-validation` targets
- Task 2 completely omits these changes
- **Resolution**: Add subtask 2.6 for test runner/Makefile updates

**ISSUE 2-3: Missing tests/README.md update** (HIGH)
- Plan states: "tests/README.md — Updated with new test descriptions"
- Task 2 doesn't mention this
- **Resolution**: Add to subtask 2.5 acceptance criteria

**ISSUE 2-4: Incorrect version reference** (HIGH)
- Subtask 2.5 says: "2.2.1 → 2.3.0"
- Current version is 2.2.0 (per git history and README.md)
- **Resolution**: Change to "2.2.0 → 2.3.0"

**ISSUE 2-5: Subtask ordering problem** (HIGH)
- Subtask 2.3 refactors tests to use helpers
- But subtask 2.1 doesn't create the helpers
- **Resolution**: Either:
  - Move helper creation to Task 1 and add dependency (RECOMMENDED)
  - OR: Add subtask 2.0 to create helpers before 2.3

### Medium Issues

**ISSUE 2-6: Vague acceptance criteria**
- Subtask 2.5: "make test passes (all suites)"
- At this point only suite 1 exists
- Should say "make test-validation passes" instead

### Recommendations
1. **BLOCK IMPLEMENTATION** until test infrastructure dependency is resolved
2. Add subtask 2.6: "Update test runner and Makefile"
3. Fix version reference in subtask 2.5
4. Add tests/README.md to subtask 2.5 acceptance criteria

---

## Task 3: Unified Stop Hook — Auto-Review Logic — CRITICAL GAPS (4/10)

### Strengths
✅ Correct test count (51 tests across suites 2-5)
✅ Atomic state write pattern correctly described
✅ Four distinct CLI prompts recognized

### Critical Issues

**ISSUE 3-1: Missing Hook Steps 1-3** (CRITICAL — BLOCKING)
- Task jumps directly to "step 5" implementation
- Steps 1-3 are MANDATORY prerequisites:
  - Step 1: Check `stop_hook_active` (infinite loop prevention)
  - Step 2: Check if `.taskie/plans` exists
  - Step 3: Find most recently modified plan directory
- Plan explicitly states hook follows steps 1-6 sequentially (line 162)
- **Impact**: Without step 1, infinite loops are possible
- **Resolution**: Add subtask 3.0 to implement steps 1-3

**ISSUE 3-2: Missing Step 6 (Validation Fallback)** (CRITICAL)
- Plan step 6 (lines 178-183): Run validation when NOT a review phase
- Task only mentions "fall through to validation" abstractly
- No subtask explicitly implements step 6 logic
- **Impact**: Validation may not run when it should
- **Resolution**: Add subtask 3.6 or integrate into 3.1

**ISSUE 3-3: CLI Schema Not Specified** (CRITICAL)
- Plan line 190 specifies exact `--json-schema` argument
- Task 3.2 only says "CLI invoked with... `--json-schema`"
- Without exact schema, verdict extraction (step 5f) will fail
- **Resolution**: Add exact schema to subtask 3.2 acceptance criteria:
  ```bash
  --json-schema '{"type":"object","properties":{"verdict":{"type":"string","enum":["PASS","FAIL"]}},"required":["verdict"]}'
  ```

**ISSUE 3-4: Auto-Advance Logic Contradiction** (CRITICAL)
- Plan line 176: code-review with no tasks remaining → `next_phase: "all-code-review"` with fresh review cycle init
- Task 3.3 says: all-code-review → `phase: "complete"`, `next_phase: null`
- These describe DIFFERENT transitions (TO vs FROM all-code-review)
- Task is missing the code-review → all-code-review transition entirely
- **Resolution**: Fix subtask 3.3 acceptance criteria to include both:
  - code-review (no tasks remain) → enter all-code-review cycle
  - all-code-review advance target → complete

**ISSUE 3-5: TDD Field Check Not Explicit** (HIGH)
- Plan line 176: Hook reads `tdd` field to determine complete-task variant
- Task 3.3 mentions "based on `tdd`" but not explicit enough
- Could lead to always using `complete-task`, ignoring `tdd: true`
- **Resolution**: Make TDD field check explicit in acceptance criteria

**ISSUE 3-6: Timeout Implementation Issue** (HIGH)
- Task 3.2 suggests using shell `timeout` command
- `timeout` is NOT available on macOS by default (BSD userland)
- Better approach: Rely on Claude Code's 600s hook timeout
- **Resolution**: Remove `timeout 540` suggestion, rely on hook system timeout

**ISSUE 3-7: Hard Stop UX Unclear** (MEDIUM)
- Plan: hard stop when `phase_iteration > max_reviews`
- Task 3.2: "Output `systemMessage` warning user"
- But WHAT should the message say? What should user do?
- **Resolution**: Specify message content: "Max review limit reached. Edit state.json to adjust max_reviews or set next_phase manually."

### Medium Issues

**ISSUE 3-8: Remaining Tasks Check Pattern Missing**
- Subtask 3.3: "check `tasks.md` for remaining pending tasks"
- No grep pattern specified
- **Resolution**: Add pattern to acceptance criteria:
  ```bash
  grep '^|' tasks.md | grep 'pending' | wc -l
  ```

**ISSUE 3-9: Test Coverage Gap**
- No explicit tests for steps 1-3 implementation
- Plan test suite 6 test 1 covers plan detection, but hook implementation is missing
- **Resolution**: Note in subtask 3.5 that tests verify steps 1-3 behavior

### Recommendations
1. **BLOCK IMPLEMENTATION** — This task is not implementable as written
2. Add subtask 3.0: "Implement hook initialization (steps 1-3)"
3. Add subtask 3.6: "Implement step 6 (validation fallback)" OR integrate into 3.1
4. Fix CLI schema specification in 3.2
5. Correct auto-advance logic contradiction in 3.3
6. Remove shell `timeout` recommendation (macOS incompatibility)
7. Specify hard stop systemMessage content

---

## Task 4: Action File Changes — Planning Actions — COMPLIANT (9/10)

### Strengths
✅ All 3 planning action files covered
✅ continue-plan.md routing table fully specified
✅ State.json initialization correct in new-plan.md
✅ create-tasks.md read-modify-write pattern correct

### Minor Issues
None found. Task 4 accurately reflects plan requirements.

### Recommendations
1. Consider adding note in 4.2 that continue-plan.md is the most complex rewrite (complexity 8 justified)

---

## Task 5: Action File Changes — Task & Review Actions — COMPLIANT (9/10)

### Strengths
✅ All 13 action files covered (4 implementation + 8 review/post-review + 1 add-task)
✅ complete-task inlining correctly specified
✅ Post-review loop-back logic correct
✅ Standalone vs automated detection via phase_iteration

### Minor Issues
None found. Task 5 accurately reflects plan requirements.

### Recommendations
1. Subtask 5.4 updates 8 files — consider noting this is acceptable due to pattern similarity
2. Add note that post-review actions ALWAYS loop back (reviewer decides exit, not implementer)

---

## Task 6: Ground Rules, Codex CLI Updates, and Edge Case Tests — COMPLIANT (9/10)

### Strengths
✅ Ground rules updates complete
✅ Codex CLI scope correctly limited to 2 files
✅ All 12 edge case tests specified
✅ Correctly notes other Codex prompts NOT updated

### Minor Issues
None found. Task 6 accurately reflects plan requirements.

### Recommendations
1. Test suite 6 defers all edge cases to end — acceptable since full system needed, but note dependency on Tasks 1-5 completion

---

## Cross-Task Issues

### Dependency Chain Problems

**ISSUE CT-1: Task ordering ambiguity** (CRITICAL)
- Task 1 creates test infrastructure
- Task 2 requires test infrastructure (subtask 2.3)
- But tasks.md shows them as parallel (both "pending")
- **Resolution**: Make Task 1 a hard prerequisite for Task 2

**ISSUE CT-2: Test distribution strategy mismatch** (MEDIUM)
- Plan line 637: "tests should be written alongside feature implementation"
- Task 6 defers all edge case tests to the end
- **Verdict**: Acceptable — edge cases need full system, infrastructure tests are in Task 1

### Coverage Analysis

**Action Files**: 17 total, all covered ✅
- Planning: 3 (Task 4)
- Implementation: 5 (Task 5)
- Review: 8 (Task 5)
- Other: 1 (Task 5)

**Test Suites**: 6 total, all planned ✅
- Suite 1 (17 tests): Task 2
- Suite 2 (15 tests): Task 3
- Suite 3 (16 tests): Task 3
- Suite 4 (14 tests): Task 3
- Suite 5 (6 tests): Task 3
- Suite 6 (12 tests): Task 6
- **Total: 80 tests** (matches plan line 631)

**Hook Logic Steps**: 6 total, coverage gaps ❌
- Step 1: ❌ MISSING from tasks
- Step 2: ❌ MISSING from tasks
- Step 3: ❌ MISSING from tasks
- Step 4: ✅ Task 2 (read state.json)
- Step 5: ✅ Task 3 (auto-review logic)
- Step 6: ⚠️ MENTIONED but not explicit subtask

---

## Priority Fixes Required Before Implementation

### BLOCKING (Must fix immediately):
1. **Task 1**: Add explicit prerequisite note for Task 2
2. **Task 2**: Add subtask 2.6 for test runner/Makefile updates
3. **Task 2**: Fix version reference (2.2.0 → 2.3.0, not 2.2.1)
4. **Task 3**: Add subtask 3.0 for hook steps 1-3 implementation
5. **Task 3**: Specify exact CLI `--json-schema` in subtask 3.2
6. **Task 3**: Fix auto-advance logic contradiction in subtask 3.3
7. **Task 3**: Add step 6 validation fallback (new subtask or integrate)

### HIGH PRIORITY (Should fix before Task 3 implementation):
1. **Task 2**: Add tests/README.md to subtask 2.5
2. **Task 3**: Remove shell `timeout` command (macOS incompatibility)
3. **Task 3**: Make TDD field check explicit in 3.3
4. **Task 3**: Specify hard stop systemMessage content
5. **Task 3**: Add remaining tasks grep pattern to 3.3

### MEDIUM PRIORITY (Nice to have):
1. **Task 2**: Change "make test passes (all suites)" to "make test-validation passes"
2. **Task 3**: Note that tests verify steps 1-3 behavior in subtask 3.5
3. **Task 6**: Add dependency note (requires Tasks 1-5 completion)

---

## Complexity Re-assessment

| Task | Original | Revised | Justification |
|------|----------|---------|---------------|
| Task 1 | 4+3+3=10 | 10 ✅ | Correct |
| Task 2 | 4+5+4+4+2=19 | 21 ⚠️ | Add +2 for test runner updates (new subtask) |
| Task 3 | 5+7+7+5+8=32 | 40 🔴 | Add +3 for steps 1-3, +2 for step 6, +3 for fixing contradictions |
| Task 4 | 3+8+3=14 | 14 ✅ | Correct |
| Task 5 | 3+5+2+5+2=17 | 17 ✅ | Correct |
| Task 6 | 3+3+6=12 | 12 ✅ | Correct |
| **Total** | **104** | **114** | +10 complexity from fixes |

**Task 3 is significantly more complex than estimated.** The missing steps 1-3 and step 6 add substantial implementation burden.

---

## Risk Assessment

### Implementation Risks

**HIGH RISK** — Task 3:
- Missing hook initialization (steps 1-3) creates infinite loop vulnerability
- Missing validation fallback (step 6) could skip validation entirely
- CLI schema mismatch will break verdict extraction
- Auto-advance contradiction will cause incorrect state transitions

**MEDIUM RISK** — Task 2:
- Dependency on Task 1 not enforced
- Test runner updates missing could cause test execution issues

**LOW RISK** — Tasks 4, 5, 6:
- Requirements clear and complete
- No major gaps detected

### Mitigation Strategies

1. **For Task 3**: REQUIRE revision before implementation begins
2. **For Task 2**: Add explicit Task 1 prerequisite
3. **For all tasks**: Consider adding a "prerequisites" section to tasks.md

---

## Recommendations Summary

### Immediate Actions (Before Any Implementation):
1. ✅ **Revise Task 3** with fixes for all BLOCKING issues
2. ✅ **Revise Task 2** to add test runner updates and fix version
3. ✅ **Update tasks.md** to show Task 1 → Task 2 dependency
4. ✅ **Add prerequisites section** to each task file

### Process Improvements:
1. Consider adding a "depends on" field to task files
2. Add complexity buffer (10-15%) for tasks with many subtasks
3. Run tasks review earlier in planning cycle (after task creation, before implementation)

### Testing Strategy:
1. Task 1 tests should verify mock Claude works correctly (JSON verdict output)
2. Task 2 tests should fail if Task 1 incomplete (dependency enforcement)
3. Task 3 tests should explicitly cover steps 1-3 and step 6

---

## Verdict

**TASKS ARE NOT READY FOR IMPLEMENTATION** without revisions to Tasks 2 and 3.

**Severity Breakdown**:
- 🔴 **CRITICAL**: 7 issues (Tasks 2, 3) — BLOCK implementation
- 🟡 **HIGH**: 5 issues (Tasks 2, 3) — Address before Task 3
- 🟢 **MEDIUM**: 4 issues (Tasks 2, 3, 6) — Nice to have

**Action Required**: Address all CRITICAL and HIGH priority issues before proceeding with implementation.

---

## Sign-off

**Reviewer**: Claude Sonnet 4.5 (tasks-review agent)
**Review Methodology**: Deep subagent analysis with clean-slate approach
**Next Steps**: Post-tasks-review action to address all CRITICAL and HIGH issues
