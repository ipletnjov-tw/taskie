# Perform Task List and Task Files Review

Perform a thorough review of the proposed task list defined in `.llm/plans/{current-plan-dir}/tasks.md` and the corresponding task files `.llm/plans/{current-plan-dir}/task-{task-id}.md`. Be very critical, look for mistakes, inconsistencies, misunderstandings, misconceptions, scope creep, over-engineering and other cruft.

**Your review must be a clean slate. Do not look at any prior review files.**

If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Document the results of your review in `.llm/plans/{current-plan-dir}/tasks-review-{review-id}.md`.

Remember, you MUST follow the `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.