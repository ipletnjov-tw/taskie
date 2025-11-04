# prompts

This is a simple framework that makes it easy to use LLMs to implement features and projects of almost any level of complexity.

Works well with **Anthropic Claude Sonnet** 3.7, 4.0 and 4.5. Tested using the Cursor IDE, Cursor Background Agents, Claude Code CLI and Claude Code Web Agents.

## Structure

The frameworks consists of **[actions](./.llm/actions)** and **[personas](./.llm/personas)**. These two tools are used to design and execute **implementation plans**. Each plan consists of a number of **tasks**, and each task consists of a number of **subtasks**.

The [ground-rules.md](https://github.com/ipletnjov-tw/prompts/blob/main/.llm/ground-rules.md#structure) file contains a more detailed overview of how each plan must be structured. This overview is primarily used to ensure that the LLM sticks to the desired format.

## Usage

All you really need to do is point the LLM at the right action file, like so:
```
Perform the action described in .llm/actions/{action}.md.
```

Most of the time, every prompt one of your prompts will look **exactly** like this.

### Kick off a new implementation plan

Your first prompt should look like this:
```
Perform the action described in .llm/actions/new-plan.md. I need you to implement feature X, it needs to be A, B, and C. You will have to use Y and please make sure you don't forget X.
```

You will want to read the generated plan and refine the details with the LLM. In addition, you can prompt `Perform the action described in .llm/actions/plan-review.md` to get the LLM to critically review and scrutinize the plan.

### Create the tasks for the plan

```
Perform the action described in .llm/actions/create-tasks.md.
```

This will create the `tasks.md` table along with a number of task files.
