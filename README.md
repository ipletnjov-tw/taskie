# Taskie

This is a simple framework of reusable prompts that makes it easy to use LLMs to implement features & projects of almost any level of complexity while maintaining a high level of code quality.

Works well with **Anthropic Claude Sonnet** 3.7, 4.0 and 4.5. Tested using the Cursor IDE (VSCode), Cursor Background Agents, Claude Code CLI and Claude Code Web.

Packaged and distributed as a Claude Code plugin. For usage outside of Claude Code, please refer to [PROMPTS.md](./PROMPTS.md).

## Installation

### Add the Taskie marketplace

```bash
/plugin marketplace add github:ipletnjov-tw/prompts
```

### Install the plugin

```bash
/plugin install taskie@taskie
```

## Available Commands

Once installed, you'll have access to these slash commands:

### Planning Commands
- `/taskie/new-plan` - Create a new implementation plan
- `/taskie/continue-plan` - Continue an existing plan from git history
- `/taskie/plan-review` - Review and critique the current plan
- `/taskie/post-plan-review` - Address plan review comments

### Task Management Commands
- `/taskie/create-tasks` - Generate tasks from the current plan
- `/taskie/tasks-review` - Review the task list and task files
- `/taskie/post-tasks-review` - Address task review comments
- `/taskie/next-task` - Start implementing the next task
- `/taskie/continue-task` - Continue working on the current task

### Code Review Commands
- `/taskie/code-review` - Critically review implemented code
- `/taskie/post-code-review` - Apply code review feedback

## Usage

All commands support appending additional instructions:

```bash
/taskie/new-plan I need to implement feature X with A, B, and C
/taskie/code-review Focus on error handling
```

## Workflow

1. **Plan** - Create and refine your implementation plan using `/taskie/new-plan` and review cycles
2. **Task** - Break down the plan into tasks with `/taskie/create-tasks` and review them
3. **Code** - Implement each task using `/taskie/next-task`, review with `/taskie/code-review`, and refine
4. **Iterate** - Repeat review cycles until you achieve your desired quality level

## For Non-Claude Code Users

If you're not using Claude Code, see [PROMPTS.md](./PROMPTS.md) for instructions on using the raw prompt files directly with any LLM tool.
