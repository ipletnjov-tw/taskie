# Perform Complete Implementation Review

Perform a thorough review of ALL code implemented across ALL tasks (completed or in-progress) in the current implementation plan. Be very critical, look for mistakes, inconsistencies, misunderstandings, shortcuts, negligence, overengineering and other cruft. Don't let ANYTHING slip, write down even the most minor issues. You MUST review ALL code that was created, changed or deleted as part of the entire plan implementation, NOT just recent changes.

Double check ALL the must-run commands from all tasks by running them and analyzing their results.

Document the results of your review in `.taskie/plans/{current-plan-dir}/all-code-review-{review-id}.md`. If you don't know what the `{current-plan-dir}` is, use git history to find out which plan was modified most recently.

Remember, you MUST follow the `.llm/ground-rules.md` at ALL times. Do NOT forget to push your changes to remote.
