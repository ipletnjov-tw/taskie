# prompts

This is a simple framework of reusable prompts that makes it easy to use LLMs to implement features & projects of almost any level of complexity while maintaining a high level of code quality.

Works well with **Anthropic Claude Sonnet** 3.7, 4.0 and 4.5. Tested using the Cursor IDE (VSCode), Cursor Background Agents, Claude Code CLI and Claude Code Web.

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

Once the first task is done, move to the next one using `Perform the action described in .llm/actions/next-task.md.`. Repeat until every task is done! 🚀 

