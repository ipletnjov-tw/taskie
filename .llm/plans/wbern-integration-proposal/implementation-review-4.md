# Implementation Review 4 - Ten New Angles

## Summary

Comprehensive review of TDD integration from 10 previously unexplored angles.

---

## Angle 1: Cross-file Consistency

**Status**: ⚠️ ADVISORY

**Issue**: Variable name mismatch between `.llm/actions/next-task.md` and `.llm/actions/next-task-tdd.md`

- `next-task.md` uses `{next-task-id}` on line 5
- `next-task-tdd.md` uses `{current-task-id}` on line 15

Both refer to the same concept. This inconsistency could confuse agents.

**Files**: `.llm/actions/next-task.md:5`, `.llm/actions/next-task-tdd.md:15`

---

## Angle 2: Instruction Clarity

**Status**: ✅ PASS

Both `next-task-tdd.md` and `complete-task.md` have clear, actionable instructions:
- Explicit MUST/MUST NOT constraints
- Numbered steps with bold phases
- Clear termination conditions

---

## Angle 3: Edge Case Handling

**Status**: ⚠️ ADVISORY

**Issue**: `next-task-tdd.md` assumes acceptance criteria always exist

Line 7: "Write ONE failing test based on acceptance criteria"

But acceptance criteria was only added to `create-tasks.md` recently. Existing plans/tasks created before this change won't have acceptance criteria.

**Recommendation**: Add fallback: "based on acceptance criteria (or subtask description if criteria not specified)"

**File**: `.llm/actions/next-task-tdd.md:7`

---

## Angle 4: Command Interaction

**Status**: ✅ PASS

Commands compose correctly:
- `complete-task` → `next-task` → `code-review` → `post-code-review`
- `complete-task-tdd` → `next-task-tdd` → `code-review` → `post-code-review`
- TDD and non-TDD share code-review and post-code-review phases

---

## Angle 5: Backward Compatibility

**Status**: ✅ PASS

All new functionality is additive:
- New commands don't modify existing ones
- New persona doesn't affect existing personas
- New `Acceptance criteria` field in create-tasks.md is optional (no changes to existing tasks)

---

## Angle 6: Error Modes

**Status**: ⚠️ ADVISORY

**Issue**: No guidance for when TDD is impossible

Some scenarios where TDD cannot be applied:
- Pure documentation tasks
- Configuration file changes
- Third-party integration setup

The `next-task-tdd.md` action doesn't provide escape hatch for untestable subtasks.

**Recommendation**: Consider adding: "For subtasks that cannot be tested (config, docs), skip directly to implementation and note in commit why TDD was skipped."

---

## Angle 7: Cognitive Load

**Status**: ✅ PASS

The command naming is intuitive:
- `next-task` vs `next-task-tdd` - clear distinction
- `complete-task` vs `complete-task-tdd` - consistent pattern
- Users can choose standard or TDD variant easily

---

## Angle 8: DRY Principle

**Status**: ⚠️ ADVISORY

**Issue**: Duplication between `complete-task.md` and `complete-task-tdd.md`

The only difference is Phase 1 action reference. 95% of content is identical.

**Current**:
- `complete-task.md`: references `next-task.md`
- `complete-task-tdd.md`: references `next-task-tdd.md`

This is acceptable given the simplicity, but any future changes to the review cycle must be applied to both files.

---

## Angle 9: Completeness of TDD Integration

**Status**: 🚨 BLOCKING

**Issue**: TDD persona not mentioned in TDD action files

The `next-task-tdd.md` and `complete-task-tdd.md` actions don't reference the TDD persona at all. The persona exists (`taskie/personas/tdd.md`) but users won't know to use it.

**Recommendation**: Add to TDD commands: "For best results, combine with the TDD persona."

Or update action files to explicitly suggest persona usage.

**Files**:
- `taskie/actions/next-task-tdd.md`
- `taskie/actions/complete-task-tdd.md`

---

## Angle 10: Semantic Correctness

**Status**: 🚨 BLOCKING

**Issue**: `complete-task.md` Phase 4 says "Update task status to 'completed'"

But `tasks.md` schema uses `done` not `completed`:
- `create-tasks.md` line 9: "Status (pending / done / cancelled / postponed)"

The subtask schema uses different statuses:
- `create-tasks.md` line 22: "(pending / awaiting-review / review-changes-requested / completed / postponed)"

Phase 4 should update:
- Task status in `tasks.md` to "done"
- Subtask status in `task-{id}.md` to "completed"

**Files**:
- `.llm/actions/complete-task.md:23`
- `taskie/actions/complete-task.md:23`
- `.llm/actions/complete-task-tdd.md:23`
- `taskie/actions/complete-task-tdd.md:23`

---

## Summary Table

| # | Angle | Status | Severity |
|---|-------|--------|----------|
| 1 | Cross-file consistency | ⚠️ | Advisory |
| 2 | Instruction clarity | ✅ | Pass |
| 3 | Edge case handling | ⚠️ | Advisory |
| 4 | Command interaction | ✅ | Pass |
| 5 | Backward compatibility | ✅ | Pass |
| 6 | Error modes | ⚠️ | Advisory |
| 7 | Cognitive load | ✅ | Pass |
| 8 | DRY principle | ⚠️ | Advisory |
| 9 | TDD integration completeness | 🚨 | Blocking |
| 10 | Semantic correctness | 🚨 | Blocking |

**Blocking Issues**: 2
**Advisory Issues**: 4
**Passed**: 4
