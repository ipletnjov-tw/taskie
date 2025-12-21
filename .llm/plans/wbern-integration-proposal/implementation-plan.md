# Implementation Plan: TDD Integration (Simplified)

This plan integrates wbern/claude-instructions TDD concepts into Taskie using the existing persona system rather than creating redundant commands.

---

## Repository Structure (Current)

```
/home/user/taskie/
├── .claude-plugin/
│   └── marketplace.json                    # Marketplace registration
│
├── .llm/                                   # LOCAL/DEV version
│   ├── actions/                            # 11 action files (paths use .llm/...)
│   │   ├── code-review.md
│   │   ├── continue-plan.md
│   │   ├── continue-task.md
│   │   ├── create-tasks.md
│   │   ├── new-plan.md
│   │   ├── next-task.md
│   │   ├── plan-review.md
│   │   ├── post-code-review.md
│   │   ├── post-plan-review.md
│   │   ├── post-tasks-review.md
│   │   └── tasks-review.md
│   ├── personas/                           # 5 personas
│   │   ├── designer.md
│   │   ├── qa.md
│   │   ├── reviewer.md
│   │   ├── swe.md
│   │   └── writer.md
│   ├── plans/                              # Local plans storage
│   └── ground-rules.md
│
├── taskie/                                 # PLUGIN distribution
│   ├── .claude-plugin/
│   │   └── plugin.json                     # v1.1.5
│   ├── actions/                            # 11 action files (paths use .taskie/..., @${CLAUDE_PLUGIN_ROOT}/...)
│   ├── commands/                           # 11 slash command wrappers
│   ├── ground-rules.md
│   └── (NO personas/ folder)               # ← Gap: personas not distributed with plugin
│
├── README.md
└── PROMPTS.md
```

### Key Observations

1. **Two parallel structures** that must be kept in sync:
   - `.llm/` → local dev, uses `.llm/` paths
   - `taskie/` → plugin, uses `.taskie/` and `@${CLAUDE_PLUGIN_ROOT}/` paths

2. **Personas are NOT in the plugin** - only in `.llm/personas/`
   - Plugin's ground-rules.md references `.taskie/personas` but folder doesn't exist in plugin
   - Decision needed: include personas in plugin or keep as local-only

3. **Commands only in plugin** - `.llm/` has no `commands/` folder

---

## Simplified Approach

### Rationale

Instead of creating `/taskie:tdd-task` and `/taskie:cycle` commands:

1. **TDD persona** provides behavior modification via existing persona system
2. **Enhanced `next-task`** includes optional TDD guidance
3. **Only `complete-task`** is truly new (combines 3 existing commands)

This reduces complexity from 9 new/modified files to 5.

---

## Files to Change

### Summary

| Action | File | Purpose |
|--------|------|---------|
| **CREATE** | `.llm/personas/tdd.md` | TDD engineer persona |
| **CREATE** | `taskie/personas/tdd.md` | TDD persona for plugin distribution |
| **CREATE** | `.llm/actions/complete-task.md` | Unified workflow (local) |
| **CREATE** | `taskie/actions/complete-task.md` | Unified workflow (plugin) |
| **CREATE** | `taskie/commands/complete-task.md` | Command wrapper |
| **MODIFY** | `.llm/actions/next-task.md` | Add TDD guidance section |
| **MODIFY** | `taskie/actions/next-task.md` | Add TDD guidance section (plugin paths) |
| **MODIFY** | `.llm/actions/create-tasks.md` | Add acceptance criteria field |
| **MODIFY** | `taskie/actions/create-tasks.md` | Add acceptance criteria field (plugin paths) |

**Total: 5 new files, 4 modified files**

---

## Detailed File Changes

### 1. CREATE: `.llm/personas/tdd.md`

```markdown
I am a disciplined test-driven development practitioner.

The following is a list of my core characteristics:

**Red-Green-Refactor Discipline**: I follow the TDD cycle religiously. I write exactly ONE failing test before any implementation. I write the MINIMAL code to make it pass. I refactor only when tests are green.

**Incremental Development**: Each step addresses one specific issue:
- Test fails "not defined" → Create empty stub only
- Test fails "not a function" → Add method stub only
- Test fails assertion → Implement minimal logic only

**No Over-Engineering**: I never implement beyond what the current failing test requires. No anticipatory features, no "while I'm here" additions, no premature abstractions.

**Test Quality**: I write tests that:
- Follow Arrange-Act-Assert pattern
- Use `data-testid` for DOM selection (not CSS classes or text)
- Avoid hardcoded timeouts (use `waitFor`, `findBy*`)
- Test behavior, not implementation details

**Silent Methodology**: I never mention TDD in code comments, commit messages, or documentation. The code speaks for itself—TDD is the process, not the product.
```

---

### 2. CREATE: `taskie/personas/tdd.md`

Same content as above. This requires creating a new `taskie/personas/` directory.

---

### 3. CREATE: `.llm/actions/complete-task.md`

```markdown
# Complete Task with Review Cycle

Execute full task completion: Implement → Self-Review → Fix → Verify. This combines `next-task`, `code-review`, and `post-code-review` into a single action.

## Phase 1: Implementation

1. Identify the next pending task from `.llm/plans/{current-plan-dir}/tasks.md`
2. Read task details from `.llm/plans/{current-plan-dir}/task-{id}.md`
3. For each pending subtask:
   a. Implement the subtask requirements
   b. Run all must-run commands
   c. Create git commit with descriptive message
   d. Update subtask status to "awaiting-review"
   e. Record git commit hash
4. Update task status to "implementation-complete"

## Phase 2: Self-Review

1. Critically review ALL code created, changed, or deleted for this task
2. Look for:
   - Mistakes and bugs
   - Inconsistencies with existing code
   - Shortcuts and negligence
   - Over-engineering
   - Missing error handling
   - Security vulnerabilities
3. Run all must-run commands and analyze results
4. Create review file: `.llm/plans/{current-plan-dir}/task-{id}-review-{n}.md`
5. Categorize issues as:
   - **Blocking**: Must fix before completion
   - **Advisory**: Should fix but not blocking

## Phase 3: Fix Blocking Issues

1. Address each blocking issue from the review
2. Run must-run commands after fixes
3. Create git commit for fixes
4. Update subtask summaries with fix descriptions

## Phase 4: Verification

1. Run ALL must-run commands one final time
2. If any fail → return to Phase 3
3. If all pass → update task status to "awaiting-human-review"
4. Push all changes to remote

## Iteration Limit

Maximum 3 review-fix cycles. If issues remain after 3 cycles, pause and request human input with a summary of unresolved issues.

## Exit Conditions

Task is complete when:
- All subtasks are implemented
- All must-run commands pass
- No blocking issues remain
- Changes are pushed to remote

If you don't know `{current-plan-dir}`, use git history to find the most recently modified plan.

Remember, you MUST follow `.llm/ground-rules.md` at ALL times.
```

---

### 4. CREATE: `taskie/actions/complete-task.md`

Same content as above, but with path changes:
- `.llm/plans/` → `.taskie/plans/`
- `.llm/ground-rules.md` → `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md`

---

### 5. CREATE: `taskie/commands/complete-task.md`

```markdown
---
description: Complete task with automatic review cycle (implement + review + fix). DO NOT use a subagent unless you are explicitly prompted to do so.
disable-model-invocation: true
---

Perform the action described in @${CLAUDE_PLUGIN_ROOT}/actions/complete-task.md

$ARGUMENTS
```

---

### 6. MODIFY: `.llm/actions/next-task.md`

**Current content:**
```markdown
# Start Next Task Implementation

Proceed to the next task in the implementation plan. You MUST implement ONLY ONE task, including ALL of the task's subtasks. You MUST NOT implement more than ONE task. You MUST run all must-run commands for EVERY subtask to verify completion.

After you're done, document your progress with a short summary in `.llm/plans/{current-plan-dir}/task-{next-task-id}.md` and update the status and git commit hash of the subtask(s). Update the task status in `.llm/plans/{current-plan-dir}/tasks.md`.

If you don't know what the `{current-plan-dir}` or `{next-task-id}` are, use git history to find out which plan and task was modified most recently.

Remember, you MUST follow the `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
```

**New content:**
```markdown
# Start Next Task Implementation

Proceed to the next task in the implementation plan. You MUST implement ONLY ONE task, including ALL of the task's subtasks. You MUST NOT implement more than ONE task. You MUST run all must-run commands for EVERY subtask to verify completion.

## TDD Approach (When Using TDD Persona)

If you are using the TDD persona from `.llm/personas/tdd.md`, follow this approach for each subtask:

1. **RED**: Write ONE failing test based on the acceptance criteria
   - Test must fail for the right reason (not syntax/import errors)
   - Run test suite to confirm failure
   - Do NOT write implementation code yet

2. **GREEN**: Write MINIMAL code to make the test pass
   - Address only the specific failure message
   - Run test suite to confirm all tests pass
   - Do NOT add extra functionality

3. **REFACTOR**: Improve structure while tests stay green
   - Only when all tests are passing
   - Improve both implementation and test code
   - Run tests after each change

4. **REPEAT** until subtask functionality is complete

## After Completion

After you're done, document your progress with a short summary in `.llm/plans/{current-plan-dir}/task-{next-task-id}.md` and update the status and git commit hash of the subtask(s). Update the task status in `.llm/plans/{current-plan-dir}/tasks.md`.

If you don't know what the `{current-plan-dir}` or `{next-task-id}` are, use git history to find out which plan and task was modified most recently.

Remember, you MUST follow the `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
```

---

### 7. MODIFY: `taskie/actions/next-task.md`

Same changes as above, but with plugin paths:
- `.llm/personas/tdd.md` → `.taskie/personas/tdd.md`
- `.llm/plans/` → `.taskie/plans/`
- `.llm/ground-rules.md` → `@${CLAUDE_PLUGIN_ROOT}/ground-rules.md`

---

### 8. MODIFY: `.llm/actions/create-tasks.md`

**Add to subtask template** (new field: `Acceptance criteria`):

```markdown
Each subtask MUST have the following fields:
### Subtask 1.1: Sample Subtask
- **Short description**:
- **Status**: (pending / awaiting-review / review-changes-requested / completed / postponed)
- **Sample git commit message**:
- **Git commit hash**: (To be filled in after subtask completion)
- **Priority**: (low / medium / high)
- **Complexity**: (1 - 10)
- **Test approach**:
- **Must-run commands**: (For completion verification, e.g. `npm test`, `npm run lint`, etc)
- **Acceptance criteria**: (List of specific, testable conditions that define "done")
```

---

### 9. MODIFY: `taskie/actions/create-tasks.md`

Same change as above (add `Acceptance criteria` field to subtask template).

---

## Final Workflow

### Standard Workflow (Unchanged)

```
/taskie:new-plan → /taskie:plan-review → /taskie:post-plan-review
    ↓
/taskie:create-tasks → /taskie:tasks-review → /taskie:post-tasks-review
    ↓
/taskie:next-task
    ↓
/taskie:code-review → /taskie:post-code-review (repeat until quality met)
    ↓
(repeat for each task)
```

### TDD Workflow (New - Using Persona)

```
/taskie:new-plan → /taskie:plan-review → /taskie:post-plan-review
    ↓
/taskie:create-tasks → /taskie:tasks-review → /taskie:post-tasks-review
    ↓
/taskie:next-task Use TDD persona from .llm/personas/tdd.md
    ↓
/taskie:code-review → /taskie:post-code-review (repeat until quality met)
    ↓
(repeat for each task)
```

### Unified Workflow (New - Fastest)

```
/taskie:new-plan → /taskie:plan-review → /taskie:post-plan-review
    ↓
/taskie:create-tasks → /taskie:tasks-review → /taskie:post-tasks-review
    ↓
/taskie:complete-task                    ← Implement + Review + Fix in one shot
    ↓
(human reviews, repeat for each task)
```

### Unified + TDD Workflow (New - Combined)

```
/taskie:new-plan → /taskie:plan-review → /taskie:post-plan-review
    ↓
/taskie:create-tasks → /taskie:tasks-review → /taskie:post-tasks-review
    ↓
/taskie:complete-task Use TDD persona from .llm/personas/tdd.md
    ↓
(human reviews, repeat for each task)
```

---

## Command Reference (After Implementation)

| Command | Use When |
|---------|----------|
| `/taskie:next-task` | Standard implementation (unchanged) |
| `/taskie:next-task` + TDD persona | Want TDD-style implementation |
| `/taskie:complete-task` | Want implement + review + fix in one command |
| `/taskie:complete-task` + TDD persona | Want unified workflow with TDD discipline |

---

## Side Effect: Personas in Plugin

This implementation **requires creating `taskie/personas/` directory** in the plugin distribution.

Currently, personas only exist in `.llm/personas/` (local dev). The plugin's `ground-rules.md` references `.taskie/personas` but the directory doesn't exist.

**Recommendation**: Add all 6 personas (including new TDD) to `taskie/personas/`:
- `designer.md`
- `qa.md`
- `reviewer.md`
- `swe.md`
- `writer.md`
- `tdd.md` (new)

This fixes an existing gap and enables persona usage for plugin users.

---

## Version Changes

- Bump `taskie/.claude-plugin/plugin.json` version to `1.2.0`
- Bump `.claude-plugin/marketplace.json` plugin version to `1.2.0`

---

## Summary

| Metric | Count |
|--------|-------|
| New files | 5 (+ 5 personas if copying to plugin) |
| Modified files | 4 |
| New commands | 1 (`complete-task`) |
| Breaking changes | 0 |
