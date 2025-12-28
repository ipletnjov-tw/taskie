# Taskie for OpenAI Codex CLI

This guide explains how to use Taskie prompts with the OpenAI Codex CLI.

## What is Taskie?

Taskie is a framework of reusable prompts that makes it easy to use LLMs to implement features and projects of almost any level of complexity while maintaining a high level of code quality. It provides a structured workflow for planning, task management, implementation, and code review.

## Installation

### Prerequisites

- OpenAI Codex CLI installed and configured
- Git repository initialized in your project

### Install Taskie Prompts

1. Clone or download the Taskie repository
2. Run the installation script from the Taskie directory:

```bash
./install-codex.sh
```

This will copy all Taskie prompts to `~/.codex/prompts/taskie/` and set up the necessary directory structure.

3. Restart Codex CLI or start a new session to load the prompts

## Available Prompts

Once installed, you'll have access to these prompts via `/prompts:taskie/<command>`:

### Planning Commands
- `/prompts:taskie/new-plan` - Create a new implementation plan
- `/prompts:taskie/continue-plan` - Continue an existing plan from git history
- `/prompts:taskie/plan-review` - Review and critique the current plan
- `/prompts:taskie/post-plan-review` - Address plan review comments

### Task Management Commands
- `/prompts:taskie/create-tasks` - Generate tasks from the current plan
- `/prompts:taskie/tasks-review` - Review the task list and task files
- `/prompts:taskie/post-tasks-review` - Address task review comments
- `/prompts:taskie/next-task` - Start implementing the next task
- `/prompts:taskie/continue-task` - Continue working on the current task

### Code Review Commands
- `/prompts:taskie/code-review` - Critically review implemented code
- `/prompts:taskie/post-code-review` - Apply code review feedback

### TDD Commands
- `/prompts:taskie/next-task-tdd` - Implement next task using strict TDD (red-green-refactor)
- `/prompts:taskie/complete-task-tdd` - TDD implementation with automatic review cycle

### Unified Workflow Commands
- `/prompts:taskie/complete-task` - Implement + review + fix in one command
- `/prompts:taskie/complete-task-tdd` - TDD variant of complete-task

## Usage

All prompts support appending additional instructions using standard Codex CLI syntax:

```
/prompts:taskie/new-plan I need to implement feature X, it needs to be A, B, and C
```

Or simply invoke the prompt without arguments:

```
/prompts:taskie/next-task
```

### Workflow Example

#### 1. Kick off a new implementation plan

```
/prompts:taskie/new-plan I need to implement a user authentication system with JWT tokens, email verification, and password reset functionality
```

The LLM will create a detailed plan in `.llm/plans/{plan-dir}/plan.md`.

#### 2. Review the plan

```
/prompts:taskie/plan-review
```

This will create a critical review of the plan, identifying issues and improvements.

#### 3. Address review comments

```
/prompts:taskie/post-plan-review
```

Repeat steps 2-3 until the plan is solid. 🔁

#### 4. Create tasks from the plan

```
/prompts:taskie/create-tasks
```

This generates a `tasks.md` file and individual task files with subtasks.

#### 5. Review the tasks

```
/prompts:taskie/tasks-review
```

Then address the review:

```
/prompts:taskie/post-tasks-review
```

Repeat until tasks are well-defined. 🔁

#### 6. Implement tasks

```
/prompts:taskie/next-task
```

This implements the first task and all its subtasks.

#### 7. Review the implementation

```
/prompts:taskie/code-review
```

Then apply fixes:

```
/prompts:taskie/post-code-review
```

Repeat 7 until the implementation is solid. 🔁

#### 8. Continue with remaining tasks

```
/prompts:taskie/next-task
```

Repeat steps 6-8 for each task until complete! 🚀

## Alternative Workflows

### TDD Workflow

For strict test-driven development:

```
/prompts:taskie/next-task-tdd
```

This enforces red-green-refactor cycles for each subtask.

### Unified Workflow

To combine implementation, review, and fixes in one prompt:

```
/prompts:taskie/complete-task
```

Or with TDD:

```
/prompts:taskie/complete-task-tdd
```

## Directory Structure

Taskie uses a specific directory structure to maintain context:

```
.llm/
├── ground-rules.md          # Workflow conventions and rules
└── plans/
    └── {plan-name}/
        ├── plan.md          # Implementation plan
        ├── tasks.md         # Task list overview
        ├── task-1.md        # Task 1 with subtasks
        ├── task-2.md        # Task 2 with subtasks
        ├── task-1-review-1.md    # Code reviews
        └── ...
```

## Key Features

### Context Preservation

All plan, task, and review information is stored in markdown files tracked by git. This means:
- You never lose context when switching between tools
- You can continue work from any point using `/prompts:taskie/continue-plan`
- Multiple team members can work on the same plan

### Quality Assurance

The review cycle ensures:
- Critical evaluation of plans before implementation
- Thorough code review after each task
- Iterative refinement until quality standards are met

### No Timeline Estimates

Taskie intentionally avoids time estimates. Focus on what needs to be done, not when. Let humans decide scheduling.

## FAQ

### Why so much markdown?

This solves two problems: **loss of context** and **context window size**.

If Codex crashes, loses context, or you switch tools, simply run:

```
/prompts:taskie/continue-plan
```

And continue right where you left off with full context.

### Can I customize the prompts?

Yes! The prompts are installed to `~/.codex/prompts/taskie/`. You can:
- Edit existing prompts to fit your workflow
- Add new custom prompts
- Modify YAML frontmatter (descriptions, argument hints)

Changes require restarting Codex or starting a new session.

### How do I add additional instructions?

All Taskie prompts support the `$ARGUMENTS` placeholder. Simply append your instructions:

```
/prompts:taskie/next-task Make sure to add comprehensive error handling
```

### What if I want to use different LLM tools?

Taskie prompts are tool-agnostic. The same workflow works with:
- Claude Code CLI (use `/taskie:command` format)
- Cursor IDE (use "Perform action .llm/actions/command.md")
- Any LLM that can read markdown files

See [PROMPTS.md](./PROMPTS.md) for generic usage instructions.

## Troubleshooting

### Prompts not showing up

1. Verify installation: `ls ~/.codex/prompts/taskie/`
2. Restart Codex CLI or start a new session
3. Type `/prompts:taskie/` to see available prompts

### Ground rules not found

If the LLM can't find `.llm/ground-rules.md`:

```bash
mkdir -p .llm
cp {taskie-repo}/.llm/ground-rules.md .llm/
```

### Git push issues

Taskie prompts include git push commands. Ensure:
- Remote repository is configured
- You have push permissions
- Branch exists on remote (or use `git push -u origin <branch>`)

## Additional Resources

- [Main README](./README.md) - Claude Code installation
- [PROMPTS.md](./PROMPTS.md) - Generic usage for any LLM tool
- [OpenAI Codex CLI Documentation](https://developers.openai.com/codex)
- [Custom Prompts Guide](https://developers.openai.com/codex/guides/slash-commands/)
