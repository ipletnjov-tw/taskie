# Manual Usage (Non-Claude Code)

## Structure

The frameworks consists of **[actions](./.llm/actions)** and **[personas](./.llm/personas)**. These two tools are used to design and execute **implementation plans**. Each plan consists of a number of **tasks**, and each task consists of a number of **subtasks**.

The [ground-rules.md](https://github.com/ipletnjov-tw/prompts/blob/main/.llm/ground-rules.md#structure) file contains a more detailed overview of how each plan must be structured. This overview is primarily used to ensure that the LLM sticks to the desired format.

## Usage

All you really need to do is point the LLM at the right action file, like so:
```
Perform the action described in .llm/actions/{action}.md.
```

Most of the time, every one of your prompts will look **exactly** like this.

### Kick off a new implementation plan

Your first prompt should look like this:
```
Perform the action described in .llm/actions/new-plan.md. I need you to implement feature X, it needs to be A, B, and C. You will have to use Y and please make sure you don't forget X.
```

You will want to read the generated plan and refine the details with the LLM. In addition, you can prompt `Perform the action described in .llm/actions/plan-review.md` to get the LLM to critically review and scrutinize the plan.

After the review is written, prompt `.llm/actions/post-plan-review.md` for the LLM to address the review comments. You may want to add what review comments it should leave unaddressed, in case you disagree with any of them.

Repeat the review & post-review cycle until the plan and design are in good shape. 🔁

### Create the tasks for the plan

```
Perform the action described in .llm/actions/create-tasks.md.
```

This will create the `tasks.md` table along with a number of task files. You will then want to `Perform the action described in .llm/actions/tasks-review.md.` to ensure the tasks actually correspond to the plan.

After the review is written, prompt `Perform the action described in .llm/actions/post-tasks-review.md.` for the LLM to address the review comments.

Repeat the review & post-review cycle until the tasks are in good shape. 🔁

#### Add a task to an existing plan

If you need to add a new task to an in-progress implementation plan:
```
Perform the action described in .llm/actions/add-task.md.
```

This will add a new task to the existing `tasks.md` table and create the corresponding `task-{id}.md` file.

### Let's write some code! ⌨️

After you're done iterating on the plan, design and tasks, we can move on to the meat of the work:
```
Perform the action described in .llm/actions/next-task.md.
```

The LLM will start implementing the first task and all of its subtasks. It will then stop and wait for your review before proceeding to the next one. You will then want to prompt:
```
Perform the action described in .llm/actions/code-review.md.
```

The LLM will very critically scrutinize its own implementation. You will then want to `Perform the action described in .llm/actions/post-code-review.md.` to apply the review comments to the implementation.

**Refine each task as much as possible using the review & post-review cycle until you achieve your desired level of completion and quality.** 🔁

Note: This does **not** mean that you get to skip reviewing the code yourself. You need to review **everything**, every step of the way.

Once the first task is done, move to the next one using `Perform the action described in .llm/actions/next-task.md.`. Repeat until every task is done! 🚀

### TDD Workflow

For strict test-driven development, use:
```
Perform the action described in .llm/actions/next-task-tdd.md.
```

This enforces the red-green-refactor cycle for each subtask.

### Unified Workflow

To combine implementation, review, and fixes in one action:
```
Perform the action described in .llm/actions/complete-task.md.
```

Or with TDD:
```
Perform the action described in .llm/actions/complete-task-tdd.md.
```

## FAQ

### What are personas used for?

They're highly experimental at the moment. The idea is that we get to guide the LLM's behavior according to what we're trying to achieve in the current plan or task by prompting `Perform the action described in .llm/actions/action.md using .llm/personas/persona.md`.

So far the only persona with a good track record is `writer.md`, the rest are still a work-in-progress.

### Why do we need to generate so much Markdown?

This solves two problems: **loss of context** and **context window size**.

#### Loss of context

The LLM can crash and lose context, the background agent could stop working and lose context, you may decide to switch tools at some point, etc.

The big advantage is that **you will never lose context**, no matter what tool you're using and what happens to it. If something goes wrong, you can simply point the LLM at the branch you were working on and prompt:
```
Perform the action described in .llm/actions/continue-plan.md
```
And it will continue right where it left off, with all the context it needs to continue progressing at the same pace and same level of quality.

#### Context window size

The `tasks.md` file and individual task files are structured the way they are to ensure the LLM is able to accurately keep track of **its current task** and the **overall progression of the plan** without overloading its context window and leading to sudden amnesia.

Trust me, all tasks in one file does not work well. All tasks in individual files without an overview / status tracker does not work well either. I've tried both.
