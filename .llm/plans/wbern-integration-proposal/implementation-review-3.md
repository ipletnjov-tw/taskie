# Code Review: TDD Integration (Review 3 - Multi-Angle)

## Review Summary

| Severity | Count |
|----------|-------|
| Blocking | 3 |
| Advisory | 4 |

---

## Review Angles

1. Documentation completeness
2. Plugin distribution completeness
3. Ground-rules compliance
4. Workflow recovery/continuity
5. Naming and discoverability

---

## Blocking Issues

### 1. README.md not updated with new commands

**Angle**: Documentation completeness

The README.md documents 11 commands under "Available Commands" but does not include:
- `/taskie:next-task-tdd`
- `/taskie:complete-task`
- `/taskie:complete-task-tdd`

Users installing the plugin will not know these commands exist.

**Fix**: Update README.md "Available Commands" section.

---

### 2. PROMPTS.md not updated with new actions

**Angle**: Documentation completeness

PROMPTS.md (for non-Claude Code usage) documents actions but does not mention:
- `.llm/actions/next-task-tdd.md`
- `.llm/actions/complete-task.md`
- `.llm/actions/complete-task-tdd.md`

**Fix**: Update PROMPTS.md with new action references.

---

### 3. Plugin missing 5 existing personas

**Angle**: Plugin distribution completeness

The `taskie/personas/` directory only contains `tdd.md`. The 5 existing personas are missing:
- `designer.md`
- `qa.md`
- `reviewer.md`
- `swe.md`
- `writer.md`

The plugin's `ground-rules.md` references `.taskie/personas` but most personas don't exist there. This was an existing gap that our implementation exposed but didn't fix.

**Fix**: Copy all personas from `.llm/personas/` to `taskie/personas/`.

---

## Advisory Issues

### 4. No recovery path for interrupted `complete-task`

**Angle**: Workflow recovery/continuity

If the AI crashes mid-`complete-task` (e.g., during Phase 2 self-review), there's no dedicated recovery command. The user would need to:
1. Check task status manually
2. Determine which phase was interrupted
3. Run the appropriate individual command

Compare to `continue-plan.md` which handles recovery intelligently.

**Recommendation**: Consider adding `continue-complete-task.md` or document the recovery process.

---

### 5. Ground-rules references `tasks-review-{review-id}.md` for task reviews

**Angle**: Ground-rules compliance

Ground-rules.md states:
> "A number of `tasks-review-{review-id}.md` files are created"

But our `complete-task.md` Phase 2 creates `task-{current-task-id}-review-{review-id}.md` which is correct per the Structure section. This is a minor inconsistency in ground-rules.md itself (not our code), but worth noting.

**Recommendation**: No action needed for our implementation; ground-rules.md has internal inconsistency.

---

### 6. `complete-task` commands create new task status value

**Angle**: Ground-rules compliance

Phase 4 sets status to `"awaiting-human-review"` but ground-rules.md and create-tasks.md only define these subtask statuses:
- pending
- awaiting-review
- review-changes-requested
- completed
- postponed

`"awaiting-human-review"` is a new status not in the official list.

**Recommendation**: Either add this status to ground-rules.md or use existing `"awaiting-review"` instead.

---

### 7. TDD commands not grouped in README

**Angle**: Naming and discoverability

When documented, TDD commands should be grouped together for discoverability:
- Standard commands: `next-task`, `complete-task`
- TDD variants: `next-task-tdd`, `complete-task-tdd`

**Recommendation**: Create a "TDD Commands" section in README.md.

---

## Files Reviewed

| File | Status |
|------|--------|
| `.llm/actions/complete-task.md` | OK |
| `.llm/actions/complete-task-tdd.md` | OK |
| `.llm/actions/next-task-tdd.md` | OK |
| `taskie/actions/complete-task.md` | OK |
| `taskie/actions/complete-task-tdd.md` | OK |
| `taskie/actions/next-task-tdd.md` | OK |
| `taskie/commands/*.md` | OK |
| `.llm/personas/tdd.md` | OK |
| `taskie/personas/tdd.md` | OK |
| `README.md` | Missing new commands |
| `PROMPTS.md` | Missing new actions |
| `taskie/personas/` | Missing 5 personas |
| `.llm/ground-rules.md` | Reference only |

---

## Conclusion

Three blocking documentation/distribution issues must be addressed before the implementation is complete. The advisory issues are minor and can be deferred.
