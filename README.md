# Taskie

This is a simple framework of reusable prompts that makes it easy to use LLMs to implement features & projects of almost any level of complexity while maintaining a high level of code quality.

Works well with **Anthropic Claude Sonnet** 3.7, 4.0 and 4.5. Tested using the Cursor IDE (VSCode), Cursor Background Agents, Claude Code CLI and Claude Code Web.

Packaged and distributed as a Claude Code plugin. Also works with OpenAI Codex CLI and other LLM tools. For usage outside of Claude Code and Codex CLI, please refer to [PROMPTS.md](./PROMPTS.md).

Heavily inspired by [Taskmaster](https://github.com/eyaltoledano/claude-task-master) and [wbern/claude-instructions](https://github.com/wbern/claude-instructions).

## Installation

### For Claude Code

#### Add the Taskie marketplace

```bash
/plugin marketplace add ipletnjov-tw/taskie
```

#### Install the plugin

```bash
/plugin install taskie@taskie
```

Latest version: **v3.1.7**

### For OpenAI Codex CLI

Run the installation script from the Taskie directory:

```bash
./install-codex.sh
```

This copies all prompts to `~/.codex/prompts/` with `taskie-` prefix. Restart Codex CLI or start a new session to load the prompts.

#### Codex CLI Technical Details

The Codex installation includes 18 files:
- **17 user-invocable prompts** (`taskie-new-plan.md`, `taskie-continue-plan.md`, etc.)
- **1 shared ground rules file** (`taskie-ground-rules.md`)

All prompts reference `~/.codex/prompts/taskie-ground-rules.md` to load shared ground rules at runtime. This design:
- **Maintains DRY**: Ground rules exist in one place
- **Enables updates**: Change ground rules once, affects all prompts
- **Reduces file size**: Each prompt is ~90 lines smaller

**Note:** Task-specific workflow instructions (like the phases in `complete-task` prompts) remain inlined since they're unique to those workflows, not cross-cutting concerns.

**CODEX_HOME Limitation:** If using a custom `CODEX_HOME` environment variable, you must manually edit all prompt files to update the ground rules path from `~/.codex/prompts/taskie-ground-rules.md` to your custom location.

## Available Commands

### Command Syntax by Tool

| Tool | Syntax Pattern | Example |
|------|----------------|---------|
| **Claude Code** | `/taskie:command-name` | `/taskie:new-plan` |
| **Codex CLI** | `/prompts:taskie-command-name` | `/prompts:taskie-new-plan` |

### Planning Commands
- `new-plan` - Create a new implementation plan
- `continue-plan` - Continue an existing plan from state.json (with git history fallback)
- `plan-review` - Review and critique the current plan
- `post-plan-review` - Address plan review comments

### Task Management Commands
- `create-tasks` - Generate tasks from the current plan
- `add-task` - Add a new task to an existing implementation plan
- `tasks-review` - Review the task list and task files
- `post-tasks-review` - Address task review comments
- `next-task` - Start implementing the next task
- `continue-task` - Continue working on the current task

### Code Review Commands
- `code-review` - Critically review implemented code
- `post-code-review` - Apply code review feedback
- `all-code-review` - Review ALL code across ALL tasks in the plan
- `post-all-code-review` - Apply complete implementation review feedback

### TDD Commands
- `next-task-tdd` - Implement next task using strict TDD (red-green-refactor)
- `complete-task-tdd` - TDD implementation with automatic review cycle

### Unified Workflow Commands
- `complete-task` - Implement + review + fix in one command
- `complete-task-tdd` - TDD variant of complete-task

## Usage

### Claude Code

All commands support appending additional instructions. Most of the time, your prompts will look **exactly** like this:

```bash
/taskie:command-name
```

Or with additional context:

```bash
/taskie:command-name Additional instructions here
```

### Codex CLI

For Codex CLI, use the `/prompts:taskie-` prefix:

```bash
/prompts:taskie-command-name
```

Or with additional instructions:

```bash
/prompts:taskie-command-name Additional instructions here
```

The workflow is identical to Claude Code. Examples below use Claude Code syntax; for Codex CLI, replace `/taskie:` with `/prompts:taskie-`.

### Kick off a new implementation plan

Your first prompt should look like this:

```bash
/taskie:new-plan I need to implement feature X, it needs to be A, B, and C. You will have to use Y and please make sure you don't forget X.
```

You will want to read the generated plan and refine the details with the LLM. In addition, you can prompt `/taskie:plan-review` to get the LLM to critically review and scrutinize the plan.

After the review is written, use `/taskie:post-plan-review` for the LLM to address the review comments. You may want to add what review comments it should leave unaddressed, in case you disagree with any of them.

Repeat the review & post-review cycle until the plan and design are in good shape. 🔁

### Create the tasks for the plan

```bash
/taskie:create-tasks
```

This will create the `tasks.md` table along with a number of task files. You will then want to `/taskie:tasks-review` to ensure the tasks actually correspond to the plan.

After the review is written, prompt `/taskie:post-tasks-review` for the LLM to address the review comments.

Repeat the review & post-review cycle until the tasks are in good shape. 🔁

### Let's write some code! ⌨️

After you're done iterating on the plan, design and tasks, we can move on to the meat of the work:

```bash
/taskie:next-task
```

The LLM will start implementing the first task and all of its subtasks. It will then stop and wait for your review before proceeding to the next one. You will then want to prompt:

```bash
/taskie:code-review
```

The LLM will very critically scrutinize its own implementation. You will then want to `/taskie:post-code-review` to apply the review comments to the implementation.

**Refine each task as much as possible using the review & post-review cycle until you achieve your desired level of completion and quality.** 🔁

Note: This does **not** mean that you get to skip reviewing the code yourself. You need to review **everything**, every step of the way.

Once the first task is done, move to the next one using `/taskie:next-task`. Repeat until every task is done! 🚀

## FAQ

### Why do we need to generate so much Markdown?

This solves two problems: **loss of context** and **context window size**.

#### Loss of context

The LLM can crash and lose context, the background agent could stop working and lose context, your agent will compact the converation and lose context, you may decide to switch tools at some point, etc.

The big advantage is that **you will never lose context**, no matter what tool you're using and what happens to it. If something goes wrong, you can simply point the LLM at the branch you were working on and prompt:

```bash
/taskie:continue-plan
```

And it will continue right where it left off, with all the context it needs to continue progressing at the same pace and same level of quality.

#### Context window size

The `tasks.md` file and individual task files are structured the way they are to ensure the LLM is able to accurately keep track of **its current task** and the **overall progression of the plan** without overloading its context window and leading to sudden amnesia.

Trust me, all tasks in one file does not work well. All tasks in individual files without an overview / status tracker does not work well either. I've tried both.
