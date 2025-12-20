# Implementation Plan: TDD Integration

This plan integrates wbern/claude-instructions TDD concepts into Taskie without changing the distribution model or adopting fragment architecture.

---

## Overview

### New Commands (3)
| Command | Purpose |
|---------|---------|
| `/taskie:complete-task` | Unified: implement → review → fix in one shot |
| `/taskie:tdd-task` | TDD-enforced implementation (red-green-refactor) |
| `/taskie:cycle` | Fine-grained: single red-green-refactor iteration |

### Modified Files (3)
| File | Change |
|------|--------|
| `.llm/actions/create-tasks.md` | Add TDD acceptance criteria to subtask template |
| `.llm/actions/next-task.md` | Add optional TDD guidance section |
| `.llm/ground-rules.md` | Add TDD principles section (optional enforcement) |

### New Files (6)
| File | Purpose |
|------|---------|
| `.llm/actions/complete-task.md` | Unified implementation cycle action |
| `.llm/actions/tdd-task.md` | TDD-enforced task implementation |
| `.llm/actions/cycle.md` | Single TDD iteration action |
| `.llm/personas/tdd.md` | TDD engineer persona |
| `taskie/commands/complete-task.md` | Command wrapper |
| `taskie/commands/tdd-task.md` | Command wrapper |
| `taskie/commands/cycle.md` | Command wrapper |

---

## File Changes

### 1. New File: `.llm/personas/tdd.md`

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

### 2. New File: `.llm/actions/cycle.md`

```markdown
# Execute Single TDD Cycle

Perform exactly ONE red-green-refactor iteration for the given requirement.

## RED Phase

1. Write exactly ONE failing test that describes the desired behavior
2. The test MUST fail for the right reason (not syntax/import errors)
3. Run the test suite to confirm failure
4. DO NOT write any implementation code yet
5. DO NOT write multiple tests

## GREEN Phase

1. Write the MINIMAL code to make the failing test pass
2. Address only the specific failure message
3. Run the test suite to confirm all tests pass
4. DO NOT add extra functionality beyond what the test requires
5. DO NOT refactor yet

## REFACTOR Phase

1. Only proceed if ALL tests are passing
2. Improve code structure (both implementation and test code)
3. Run tests after each change to ensure they stay green
4. Allowed: rename variables, extract methods, improve clarity
5. NOT allowed: add new functionality, change behavior

## Violations to Avoid

- Adding multiple tests at once
- Implementing beyond current test requirements
- Refactoring with failing tests
- Writing implementation before a failing test exists

## Output

After completing the cycle, report:
1. What test was written (RED)
2. What code was added (GREEN)
3. What was improved (REFACTOR)
4. Current test suite status

$ARGUMENTS contains the specific requirement for this cycle.
```

---

### 3. New File: `.llm/actions/tdd-task.md`

```markdown
# Implement Task Using TDD

Implement the next pending task using strict test-driven development. You MUST implement ONLY ONE task, including ALL of its subtasks. Each subtask MUST follow the TDD cycle.

## For Each Subtask

### Step 1: Understand
- Read the subtask requirements and acceptance criteria
- Identify what tests need to exist for the subtask to be complete

### Step 2: RED-GREEN-REFACTOR Loop
Repeat until subtask functionality is complete:

**RED**: Write ONE failing test
- Test must describe desired behavior from acceptance criteria
- Test must fail for the right reason
- Run test suite to confirm failure

**GREEN**: Write MINIMAL passing code
- Only address the specific test failure
- No extra features or error handling beyond test scope
- Run test suite to confirm all tests pass

**REFACTOR**: Improve structure
- Only when tests are green
- Improve both implementation and test code
- Run tests after each change

### Step 3: Verify & Commit
- Run ALL must-run commands from subtask definition
- Create git commit with descriptive message
- Update subtask status and git commit hash

## After All Subtasks Complete

1. Update task status in `.llm/plans/{current-plan-dir}/tasks.md`
2. Document progress summary in task file
3. Push changes to remote

## Violations That MUST Be Avoided

- Writing implementation before a failing test
- Adding multiple tests simultaneously
- Implementing beyond what current test requires
- Refactoring when tests are failing
- Skipping the test verification step

If you don't know what the `{current-plan-dir}` is, use git history to find the most recently modified plan.

Remember, you MUST follow `.llm/ground-rules.md` at ALL times.
```

---

### 4. New File: `.llm/actions/complete-task.md`

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

### 5. New File: `taskie/commands/cycle.md`

```markdown
---
description: Execute single TDD cycle (red-green-refactor). DO NOT use a subagent unless you are explicitly prompted to do so.
disable-model-invocation: true
---

Perform the action described in @${CLAUDE_PLUGIN_ROOT}/actions/cycle.md

$ARGUMENTS
```

---

### 6. New File: `taskie/commands/tdd-task.md`

```markdown
---
description: Implement next task using strict TDD. DO NOT use a subagent unless you are explicitly prompted to do so.
disable-model-invocation: true
---

Perform the action described in @${CLAUDE_PLUGIN_ROOT}/actions/tdd-task.md

$ARGUMENTS
```

---

### 7. New File: `taskie/commands/complete-task.md`

```markdown
---
description: Complete task with automatic review cycle. DO NOT use a subagent unless you are explicitly prompted to do so.
disable-model-invocation: true
---

Perform the action described in @${CLAUDE_PLUGIN_ROOT}/actions/complete-task.md

$ARGUMENTS
```

---

### 8. Modified: `.llm/actions/create-tasks.md`

Add to the subtask template (after existing fields):

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

The **Acceptance criteria** field is new. It provides clear targets for TDD test cases.

---

### 9. Modified: `.llm/actions/next-task.md`

Add optional TDD guidance section:

```markdown
# Start Next Task Implementation

Proceed to the next task in the implementation plan. You MUST implement ONLY ONE task, including ALL of the task's subtasks. You MUST NOT implement more than ONE task. You MUST run all must-run commands for EVERY subtask to verify completion.

## TDD Approach (Recommended)

For each subtask, consider following the test-first approach:
1. Write a failing test based on the acceptance criteria
2. Implement minimal code to pass the test
3. Refactor while keeping tests green
4. Repeat until subtask is complete

This is recommended but not mandatory. Use `/taskie:tdd-task` for strict TDD enforcement.

## After Completion

After you're done, document your progress with a short summary in `.llm/plans/{current-plan-dir}/task-{next-task-id}.md` and update the status and git commit hash of the subtask(s). Update the task status in `.llm/plans/{current-plan-dir}/tasks.md`.

If you don't know what the `{current-plan-dir}` or `{next-task-id}` are, use git history to find out which plan and task was modified most recently.

Remember, you MUST follow the `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
```

---

### 10. Modified: `.llm/ground-rules.md`

Add new section at the end:

```markdown
# TDD Principles (When Using TDD Commands)

When using `/taskie:tdd-task` or `/taskie:cycle`, the following rules apply:

## The Red-Green-Refactor Cycle

1. **RED**: Write exactly one failing test before any implementation
2. **GREEN**: Write minimal code to make the test pass
3. **REFACTOR**: Improve code structure only when tests are green

## Prohibited Actions

- Writing implementation code before a failing test exists
- Adding multiple tests simultaneously
- Implementing beyond what the current test requires
- Refactoring while tests are failing
- Mentioning TDD in code comments, commits, or documentation

## Incremental Development

Address one thing at a time:
- "Not defined" error → Create stub only
- "Not a function" error → Add method signature only
- Assertion failure → Implement minimal logic only
```

---

## Final Workflow

### Option A: Standard Workflow (Unchanged)

```
/taskie:new-plan "feature description"
    ↓
/taskie:plan-review → /taskie:post-plan-review (repeat)
    ↓
/taskie:create-tasks
    ↓
/taskie:tasks-review → /taskie:post-tasks-review (repeat)
    ↓
/taskie:next-task
    ↓
/taskie:code-review → /taskie:post-code-review (repeat)
    ↓
(repeat next-task cycle for each task)
```

### Option B: TDD Workflow (New)

```
/taskie:new-plan "feature description"
    ↓
/taskie:plan-review → /taskie:post-plan-review (repeat)
    ↓
/taskie:create-tasks
    ↓
/taskie:tasks-review → /taskie:post-tasks-review (repeat)
    ↓
/taskie:tdd-task                    ← TDD-enforced implementation
    ↓
/taskie:code-review → /taskie:post-code-review (repeat)
    ↓
(repeat tdd-task cycle for each task)
```

### Option C: Unified Workflow (New, Fastest)

```
/taskie:new-plan "feature description"
    ↓
/taskie:plan-review → /taskie:post-plan-review (repeat)
    ↓
/taskie:create-tasks
    ↓
/taskie:tasks-review → /taskie:post-tasks-review (repeat)
    ↓
/taskie:complete-task               ← Implement + Review + Fix in one shot
    ↓
(human reviews, then repeat for each task)
```

### Option D: Fine-Grained TDD (New, Most Control)

For maximum control during implementation:

```
/taskie:cycle "add email validation function"
    ↓
/taskie:cycle "add invalid email rejection"
    ↓
/taskie:cycle "add edge case handling"
    ↓
/taskie:code-review
```

---

## Command Reference (After Implementation)

| Command | Use When |
|---------|----------|
| `/taskie:next-task` | Standard implementation (existing behavior) |
| `/taskie:tdd-task` | Want strict TDD enforcement per subtask |
| `/taskie:complete-task` | Want implementation + review + fix in one command |
| `/taskie:cycle` | Want fine-grained control over each test iteration |

---

## Migration Notes

- All existing workflows continue to work unchanged
- New commands are additive, no breaking changes
- TDD guidance in `next-task.md` is optional/informational
- Ground-rules TDD section only applies when using TDD commands
- Version bump to 1.2.0 recommended
