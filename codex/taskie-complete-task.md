---
description: Implement + review + fix in one command
argument-hint: [additional instructions]
---

# Ground Rules

This document contains instructions for AI agents. These instructions are absolute, and must always be followed.

## Process

You will follow the same process for each implementation plan:
* You will be prompted to create the implementation plan and design document
  * The `plan.md` and `design.md` files are created
* You will be prompted to critically review the implementation plan and design document
  * A number of `plan-review-{review-id}.md` files are created
* You will be prompted to create the task list and task files
  * The `tasks.md` and `task-{task-id}.md` files are created
* You will be prompted to critically review the task list and task files
  * A number of `tasks-review-{review-id}.md` files are created
* You will be prompted to implement the tasks
  * The `tasks.md` and `task-{task-id}.md` files are updated
* You will be prompted to review the task implementation
  * A number of `task-{task-id}-review-{review-id}.md` files are created

Each step of the plan will consist of multiple iterations, depending on the results of the critical reviews and the human operator's assessment.

## Structure

Each plan will have the same basic directory structure:
```
.llm/
├── plans/
│   ├── {current-plan-id}/
│   │   ├── plan.md                      # Implementation Plan Document
│   │   ├── plan-review-1.md             # Implementation Plan Review 1
│   │   ├── plan-post-review-1.md        # Post-Review Fixes Summary 1
│   │   ├── . . .
│   │   ├── plan-review-n.md             # Implementation Plan Review n
│   │   ├── plan-post-review-n.md        # Post-Review Fixes Summary n
│   │   ├── design.md                    # Technical / Architectural Design Document
│   │   ├── design-review-1.md           # Technical Design Review 1
│   │   ├── design-post-review-1.md      # Post-Review Fixes Summary 1
│   │   ├── . . .
│   │   ├── design-review-n.md           # Technical Design Review n
│   │   ├── design-post-review-n.md      # Post-Review Fixes Summary n
│   │   ├── tasks.md                     # Task List Document
│   │   ├── tasks-review-1.md            # Task List and Tasks Review 1
│   │   ├── tasks-post-review-1.md       # Post-Review Fixes Summary 1
│   │   ├── . . .
│   │   ├── tasks-review-n.md            # Task List and Tasks Review n
│   │   ├── tasks-post-review-n.md       # Post-Review Fixes Summary n
│   │   ├── task-1.md                    # Task 1 and Subtasks
│   │   ├── task-1-review-1.md           # Task 1 Review 1
│   │   ├── task-1-post-review-1.md      # Post-Review Fixes Summary 1
│   │   ├── task-1-review-2.md           # Task 1 Review 2
│   │   ├── task-1-post-review-2.md      # Post-Review Fixes Summary 2
│   │   ├── task-2.md                    # Task 2 and Subtasks
│   │   ├── task-2-review-1.md           # Task 2 Review 1
│   │   ├── task-2-post-review-1.md      # Post-Review Fixes Summary 1
│   │   ├── task-3.md                    # Task 3 and Subtasks
│   │   ├── . . .
│   │   ├── task-n.md                    # Task n and Subtasks
│   │   ├── task-n-review-1.md           # Task n Review 1
│   │   ├── task-n-post-review-1.md      # Post-Review Fixes Summary 1
│   │   ├── . . .
│   │   ├── task-n-review-m.md           # Task n Review m
│   │   └── task-n-post-review-m.md      # Post-Review Fixes Summary m
```

## Format

Each plan will have a `plan.md` file that contains an overview of the plan and tasks to achieve the plan.
Each plan will have a number of `plan-review-{review-id}.md` review files.
After addressing issues from a plan review, a `plan-post-review-{review-id}.md` file documents the fixes made.

Each plan can have a `design.md` file that contains the technical design for the plan, if applicable.
Each design will have a number of `design-review-{review-id}.md` review files.
After addressing issues from a design review, a `design-post-review-{review-id}.md` file documents the fixes made.

Each plan will have a `tasks.md` file that contains a table with the task list. The task status must be updated after each implementation or review iteration. The task list will have a number of `tasks-review-{review-id}.md` review files.
After addressing issues from a tasks review, a `tasks-post-review-{review-id}.md` file documents the fixes made.

Each task will have its own `task-{task-id}.md` file and a number of `task-{task-id}-review-{review-id}.md` review files.
After addressing issues from a task review, a `task-{task-id}-post-review-{review-id}.md` file documents the fixes made.

## Tasks

The subtasks MUST be updated after each iteration. The table in the `tasks.md` MUST be updated after each iteration and each review.

Once you a subtask is finished, a git commit and git push MUST be performed. A short summary MUST be written down into the respective task file.

## Cross-cutting Rules

DO NOT add any timeline estimates (hours, days, weeks) to any part of the plan, task list, task files or subtasks. DO NOT add any dates or timestamps to any part of the plan, tasks or task list.


# Complete Task with Review Cycle

Execute full task completion: Next Task → Code Review → Post-Code-Review → Complete. You MUST complete ONLY ONE task.

## Phase 1: Next Task / Implementation

Implement the next task following the standard task implementation process:
- Proceed to the next pending task in the implementation plan
- Implement ONLY ONE task, including ALL of its subtasks
- Run all must-run commands for EVERY subtask to verify completion
- Document progress and update subtask status and git commit hashes
- Update task status in tasks.md

## Phase 2: Code Review

Perform a thorough code review of the implementation:
- Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering
- Review ALL code that was created, changed or deleted as part of the task
- Double check ALL must-run commands by running them and analyzing results
- Document results in task-{task-id}-review-{review-id}.md
- Update task status in tasks.md

If no issues are identified, skip to Phase 4.

## Phase 3: Post-Code-Review

Address the issues surfaced by the code review:
- Fix all identified issues from the latest review file
- Document progress with a short summary in the task file
- Update subtask status and git commit hashes
- Update task status in tasks.md

You MUST address ALL issues. Return to Phase 2 after addressing issues. Maximum of 3 code-review <-> post-code-review cycles per task.
If issues remain after 3 cycles, pause and request human input.

## Phase 4: Complete

Update subtask status to "completed" and task status to "done", then push to remote.

If you don't know the `{current-plan-dir}`, use git history to find the most recently modified plan.

Remember, you MUST follow the ground rules above at ALL times. Do NOT forget to push your changes to remote.

$ARGUMENTS
