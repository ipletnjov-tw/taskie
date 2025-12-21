# Code Review: TDD Integration Implementation

## Review Summary

| Severity | Count |
|----------|-------|
| Blocking | 2 |
| Advisory | 5 |

---

## Blocking Issues

### 1. `next-task-tdd.md` - Missing explicit must-run commands instruction

**File**: `.llm/actions/next-task-tdd.md`, `taskie/actions/next-task-tdd.md`

The original `next-task.md` explicitly states:
> "You MUST run all must-run commands for EVERY subtask to verify completion."

The new `next-task-tdd.md` only mentions running tests during the TDD cycle but doesn't emphasize running **all must-run commands** (which may include linters, type checks, etc.) for each subtask.

**Fix**: Add explicit instruction to run all must-run commands after each subtask, not just tests.

---

### 2. `complete-task.md` - Missing explicit push reminder in final line

**File**: `.llm/actions/complete-task.md`

The original `next-task.md` ends with:
> "Do NOT forget to push your changes to remote."

The new `complete-task.md` mentions pushing in Phase 4 but lacks the explicit reminder in the final line. This inconsistency could lead to forgotten pushes.

**Fix**: Add "Do NOT forget to push your changes to remote." to the final reminder.

---

## Advisory Issues

### 3. Inconsistent variable naming in `complete-task.md`

**File**: Both `complete-task.md` versions

Uses `{id}` and `{n}` instead of `{current-task-id}` and `{review-id}` as used elsewhere in the codebase (e.g., `ground-rules.md`).

**Recommendation**: Use consistent variable names: `{current-task-id}`, `{review-id}`.

---

### 4. TDD persona references React-specific testing patterns

**File**: `.llm/personas/tdd.md`, `taskie/personas/tdd.md`

References `data-testid`, `waitFor`, `findBy*` which are specific to React Testing Library. These may confuse or mislead for non-React projects.

**Recommendation**: Generalize or remove framework-specific references, or clarify they are examples.

---

### 5. TDD persona uses different voice than other personas

**File**: `.llm/personas/tdd.md`, `taskie/personas/tdd.md`

Other personas use "I will", "I must", "I should" (future/modal). TDD persona uses "I write", "I follow" (present declarative). Minor stylistic inconsistency.

**Recommendation**: Align voice with existing personas for consistency.

---

### 6. `complete-task.md` Phase 1 lacks detail compared to `next-task.md`

**File**: Both `complete-task.md` versions

Original `next-task.md` mentions:
- Documenting progress "with a short summary"
- Updating "status and git commit hash of the subtask(s)"

`complete-task.md` Phase 1 is more terse and doesn't mention reading the task file first.

**Recommendation**: Add detail about reading task file and writing summaries.

---

### 7. `next-task-tdd.md` missing "You MUST NOT implement more than ONE task"

**File**: Both `next-task-tdd.md` versions

Original `next-task.md` has both positive and negative constraints:
> "You MUST implement ONLY ONE task... You MUST NOT implement more than ONE task."

The TDD version only has the positive constraint. The redundancy in the original is intentional emphasis.

**Recommendation**: Add the explicit negative constraint for emphasis.

---

## Files Reviewed

| File | Status |
|------|--------|
| `.llm/personas/tdd.md` | Advisory issues |
| `taskie/personas/tdd.md` | Advisory issues |
| `.llm/actions/next-task-tdd.md` | Blocking + Advisory |
| `taskie/actions/next-task-tdd.md` | Blocking + Advisory |
| `taskie/commands/next-task-tdd.md` | OK |
| `.llm/actions/complete-task.md` | Blocking + Advisory |
| `taskie/actions/complete-task.md` | Advisory |
| `taskie/commands/complete-task.md` | OK |
| `.llm/actions/create-tasks.md` | OK |
| `taskie/actions/create-tasks.md` | OK |
