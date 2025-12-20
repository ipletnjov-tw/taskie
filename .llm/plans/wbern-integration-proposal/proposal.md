# Integration Proposal: wbern/claude-instructions into ipletnjov-tw/taskie

## Executive Summary

This proposal analyzes the integration of [wbern/claude-instructions](https://github.com/wbern/claude-instructions) (a TDD-focused slash command generator for Claude Code) into [ipletnjov-tw/taskie](https://github.com/ipletnjov-tw/taskie) (a Markdown-driven task planning and review framework).

The two tools have complementary strengths:
- **Taskie** excels at high-level planning, task breakdown, and review cycles
- **wbern** excels at disciplined TDD execution within implementation phases

---

## Part 1: Comparative Analysis

### 1.1 Architecture Comparison

| Aspect | Taskie | wbern/claude-instructions |
|--------|--------|---------------------------|
| **Distribution** | Claude Code plugin (marketplace) | npm package with CLI installer |
| **Command Format** | Markdown wrappers → action files | Fragment-based templates with INCLUDE directives |
| **State Storage** | Markdown files in `.llm/plans/` | Beads (SQLite+JSONL) or git worktrees |
| **Context Persistence** | External Markdown files | External Beads DB or conversation summaries |
| **Update Mechanism** | Manual marketplace updates | npm postinstall automation |
| **Customization** | Personas in `.llm/personas/` | `<claude-commands-template>` blocks in CLAUDE.md |

### 1.2 Workflow Philosophy

**Taskie's Approach:**
```
Plan → Review → Tasks → Review → Implement Task → Code Review → Post-Review → Next Task
```
- Focus: High-level planning with iterative refinement
- Review-centric: Every phase has a review/post-review cycle
- Granularity: Task-level (one task with all subtasks per iteration)

**wbern's Approach:**
```
Issue/Plan → Red → Green → Refactor → (repeat) → Commit → Ship/Show/Ask
```
- Focus: Test-first discipline at the code level
- TDD-centric: Red-Green-Refactor cycle is atomic
- Granularity: Test-level (one test at a time)

### 1.3 Strengths & Weaknesses

#### Taskie Strengths
1. **Rich planning phase** - Detailed plan.md, design.md, tasks.md structure
2. **Persistent context** - Full state externalized to git-tracked Markdown
3. **Review discipline** - Mandatory code review cycles catch issues early
4. **Recovery mechanism** - `/continue-plan` resumes from any failure point
5. **Personas** - Role-based guidance for different phases

#### Taskie Weaknesses
1. **No TDD enforcement** - "Test approach" is documented but not enforced
2. **Review-after-implementation** - Tests written after code, if at all
3. **Coarse granularity** - Implements full task before feedback
4. **No incremental verification** - Must-run commands are advisory

#### wbern Strengths
1. **TDD discipline** - Red-Green-Refactor enforced by command structure
2. **Fine granularity** - One test at a time prevents over-implementation
3. **Cycle command** - Complete TDD iteration in one shot
4. **Modern tooling** - npm distribution, feature flags, template injection
5. **Shipping workflow** - ship/show/ask pattern for deployment

#### wbern Weaknesses
1. **Light planning** - `/plan` is basic compared to Taskie's structure
2. **Ephemeral state** - Relies on Beads or conversation context
3. **No review cycle** - `/tdd-review` exists but no post-review workflow
4. **Complex setup** - Requires npm, optional Beads MCP

---

## Part 2: Specific Questions Answered

### Question 1: How to Integrate wbern TDD Cycle into Taskie Execution Commands?

#### Current Taskie Execution Flow
```
/taskie:next-task
    ↓
Implement ALL subtasks of ONE task
    ↓
Run must-run commands
    ↓
Git commit + push
    ↓
/taskie:code-review
    ↓
/taskie:post-code-review
    ↓
Repeat until satisfactory
```

#### Proposed TDD-Enhanced Flow

**Option A: TDD Phase Within Subtask (Recommended)**

Modify the `next-task.md` action to enforce TDD per subtask:

```markdown
# Start Next Task Implementation

For EACH subtask, follow the TDD cycle:

## RED Phase
1. Write ONE failing test that describes the subtask's acceptance criteria
2. Run the test suite to confirm it fails for the right reason
3. DO NOT write implementation code yet

## GREEN Phase
1. Write MINIMAL code to make the failing test pass
2. Run the test suite to confirm all tests pass
3. DO NOT add extra functionality beyond what the test requires

## REFACTOR Phase
1. Improve code structure while keeping tests green
2. Run tests after each refactoring step
3. Commit only when tests are passing

After completing RED-GREEN-REFACTOR for a subtask:
- Update the subtask status and git commit hash
- Move to the next subtask

After ALL subtasks are complete:
- Update task status in tasks.md
- Push to remote
```

**Option B: New `/taskie:tdd-task` Command**

Create a parallel execution path for TDD-minded projects:

```
/taskie:tdd-task → TDD-enforced implementation with cycle structure
/taskie:next-task → Original implementation style (for legacy/non-TDD projects)
```

**Option C: Fragment Injection Pattern**

Adopt wbern's fragment system. Create a `.llm/fragments/` directory:

```
.llm/
├── fragments/
│   ├── tdd-cycle.md         # Red-Green-Refactor instructions
│   ├── tdd-violations.md    # What NOT to do
│   └── incremental-dev.md   # Step-by-step guidance
├── actions/
│   └── next-task.md         # Uses INCLUDE directives
```

This makes TDD guidance modular and optional.

#### Implementation Recommendation

**Phase 1: Enhance existing actions (minimal change)**
- Add TDD guidance to `next-task.md` as a recommended practice
- Update `create-tasks.md` to generate test-first acceptance criteria per subtask

**Phase 2: Create optional TDD mode (medium change)**
- Add `/taskie:tdd-next-task` command
- Add `/taskie:red`, `/taskie:green`, `/taskie:refactor` for granular control
- Add TDD persona in `.llm/personas/tdd.md`

**Phase 3: Full TDD integration (significant change)**
- Adopt fragment-based architecture
- Make TDD the default, non-TDD the exception

---

### Question 2: Could Beads (via CLI) Replace Markdown? Gains and Losses?

#### What is Beads?

Beads is a lightweight issue tracking system by Steve Yegge designed for AI agents:
- **Storage**: SQLite database + JSONL files for git sync
- **CLI**: `bd` commands (`bd ready`, `bd create`, `bd dep add`, etc.)
- **Persistence**: Survives context compaction and session restarts
- **Querying**: SQL-like targeted queries vs full-file loading

#### Comparison: Beads CLI vs Taskie Markdown

| Aspect | Taskie Markdown | Beads CLI |
|--------|-----------------|-----------|
| **Human Readability** | Excellent (standard Markdown) | Poor (requires `bd` commands) |
| **Git Integration** | Native (Markdown is git-friendly) | Via JSONL sync (less human-readable diffs) |
| **Context Efficiency** | Full file loading | Targeted queries save tokens |
| **Learning Curve** | Minimal | Requires learning `bd` commands |
| **Dependencies** | None | Go binary + optional MCP |
| **Recovery** | Open any Markdown file | Run `bd state` |
| **Collaboration** | Universal (any text editor) | Requires Beads installation |
| **Query Flexibility** | Grep/search patterns | SQL-like structured queries |
| **Dependency Tracking** | Manual in Markdown | Built-in `bd dep` commands |

#### What We Would GAIN with Beads

1. **Token Efficiency**
   - Instead of loading entire tasks.md (potentially 1000+ lines), query only relevant tasks
   - `bd ready` returns just the next actionable item

2. **Dependency Management**
   - `bd dep add task-1 task-2` creates explicit blockers
   - Beads enforces execution order automatically

3. **Cross-Session Continuity**
   - After context compaction, Beads state persists
   - Agent can reconstruct full context from DB queries

4. **Distributed Collaboration**
   - Multiple agents/branches can sync via git
   - Conflict resolution built into Beads design

5. **Audit Trail**
   - Full history of state changes
   - Database compaction preserves completed work

#### What We Would LOSE with Beads

1. **Human Accessibility**
   - Markdown is universally readable; Beads requires CLI
   - Review meetings can't just open tasks.md in browser

2. **Git Diff Quality**
   - Markdown diffs are human-friendly
   - JSONL diffs are technically valid but harder to review

3. **Zero Dependencies**
   - Taskie requires nothing beyond Claude
   - Beads requires Go binary installation

4. **Transparency**
   - Markdown plans are fully inspectable
   - Beads state requires queries to understand

5. **Tool Agnosticism**
   - Taskie works in Claude Code, Cursor, ChatGPT
   - Beads MCP is Claude-specific (CLI works everywhere but less integrated)

6. **Documentation Value**
   - plan.md and design.md serve as living documentation
   - Beads issues are ephemeral work items

#### Recommendation

**Do NOT replace Markdown with Beads. Use them together.**

Proposed hybrid architecture:

```
Planning Layer (Markdown)          Execution Layer (Optional Beads)
├── plan.md                        ├── bd create "subtask-1.1"
├── design.md                      ├── bd ready → next work item
├── tasks.md (overview)            ├── bd done → complete item
└── task-{n}.md (details)          └── bd dep → track blockers
```

Benefits of hybrid:
- Plans remain human-readable and git-friendly
- Execution gains token efficiency for long-running tasks
- Beads becomes optional enhancement, not requirement

---

### Question 3: How is the wbern "cycle" Command Structured? How to Utilize for Single-Task Completion?

#### Anatomy of wbern's /cycle Command

The `/cycle` command is deceptively simple but powerful. Here's its structure:

```markdown
# /cycle - Complete TDD Cycle

Execute the full Red-Green-Refactor cycle in sequence.

## Included Content:
- INCLUDE(universal-guidelines.md)    # Output style, no TDD mentions
- INCLUDE(tdd-fundamentals.md)        # Core R-G-R instructions
- INCLUDE(beads-awareness.md)         # Optional beads integration
- INCLUDE(fallback-arguments.md)      # Handle missing context

## Execution Flow:
1. Receive feature/requirement from user argument
2. RED: Write one failing test
3. GREEN: Write minimal passing code
4. REFACTOR: Improve structure, tests stay green
5. Return to step 2 if more tests needed
6. Exit when feature is complete
```

#### Key Design Principles

1. **Single Entry Point**: User invokes `/cycle` once, all phases execute sequentially
2. **Fragment Composition**: Content is assembled from reusable fragments via INCLUDE
3. **Conditional Content**: Feature flags enable/disable sections (e.g., beads integration)
4. **Self-Terminating**: Cycle continues until the feature is complete

#### Applying This Pattern to Taskie

**Current Taskie Workflow (3 commands per task review cycle):**
```
/taskie:next-task → implement
/taskie:code-review → review
/taskie:post-code-review → fix issues
(repeat review/post-review until done)
```

**Proposed `/taskie:complete-task` Command (unified workflow):**

```markdown
# Complete Task Implementation

Execute full task completion cycle: Implement → Review → Fix → Verify

## Phase 1: Implementation
1. Read current task from tasks.md
2. For each pending subtask:
   a. [If TDD enabled] Execute RED → GREEN → REFACTOR
   b. [If TDD disabled] Implement subtask directly
   c. Run must-run commands
   d. Commit with summary
   e. Update subtask status

## Phase 2: Self-Review
1. Critically review ALL implemented code
2. Check for: mistakes, inconsistencies, shortcuts, over-engineering
3. Document issues in task-{id}-review-{n}.md
4. Determine if issues are blocking or advisory

## Phase 3: Fix Review Issues
1. Address all blocking issues
2. Run must-run commands again
3. Commit fixes with summary
4. Update task status

## Phase 4: Verification
1. Run final verification (all must-run commands)
2. If tests fail → return to Phase 3
3. If tests pass → update task to "awaiting-human-review"

## Exit Conditions:
- All subtasks complete AND
- All must-run commands pass AND
- No blocking review issues remain
```

#### Implementation Structure

Create new files:

**`.llm/actions/complete-task.md`**
```markdown
# Complete Task with Full Review Cycle

This action implements, reviews, and fixes a single task in one invocation.

## Prerequisites
- tasks.md exists with at least one pending task
- All previous tasks are completed

## Execution Phases

### Phase 1: Implementation
[Read from fragments/implementation-phase.md]

### Phase 2: Self-Review
[Read from fragments/review-phase.md]

### Phase 3: Fix Issues
[Read from fragments/fix-phase.md]

### Phase 4: Verification
[Read from fragments/verify-phase.md]

## Iteration
If Phase 4 fails, return to Phase 2 and repeat.
Maximum iterations: 3 (then pause for human input)

Remember: Follow .llm/ground-rules.md at ALL times.
```

**`.llm/fragments/implementation-phase.md`**
```markdown
## Implementation Phase

1. Read the current pending task from tasks.md
2. Read the task details from task-{id}.md
3. For each subtask with status=pending:
   a. Understand the subtask requirements
   b. [IF TDD ENABLED] Execute TDD cycle:
      - Write ONE failing test
      - Write MINIMAL code to pass
      - Refactor with tests green
   c. [IF TDD DISABLED] Implement directly
   d. Run all must-run commands
   e. Create git commit with descriptive message
   f. Update subtask status to "awaiting-review"
   g. Record git commit hash
4. Update task status to "implementation-complete"
```

#### Benefits of Unified Completion Command

1. **Reduced User Interaction**: One command instead of 3+ for simple tasks
2. **Consistent Quality**: Review always happens, not optional
3. **Self-Healing**: Fixes are applied automatically before requesting human review
4. **Clear Exit State**: Task is either fully complete or explicitly blocked

#### Suggested Command Matrix

| Command | Use Case |
|---------|----------|
| `/taskie:next-task` | Original behavior (implement only) |
| `/taskie:complete-task` | Full cycle (implement + review + fix) |
| `/taskie:tdd-task` | TDD-enforced implementation |
| `/taskie:review-cycle` | Just review + fix (no implementation) |

---

## Part 3: Detailed Integration Roadmap

### Phase 1: Minimal Integration (Low Risk)

**Goal**: Adopt wbern's TDD concepts without changing architecture

Changes:
1. Add TDD guidance to `next-task.md` action
2. Update `create-tasks.md` to require test-first criteria in subtasks
3. Add `.llm/personas/tdd.md` with TDD engineer characteristics
4. Update ground-rules.md with TDD principles (optional, configurable)

Effort: Small
Breaking Changes: None

### Phase 2: Fragment Architecture (Medium Risk)

**Goal**: Adopt reusable fragment pattern for maintainability

Changes:
1. Create `.llm/fragments/` directory
2. Extract common patterns into fragments:
   - `tdd-cycle.md`
   - `review-principles.md`
   - `git-discipline.md`
3. Update actions to use INCLUDE-like references
4. Add fragment resolution logic to command wrappers

Effort: Medium
Breaking Changes: Action file format (requires plugin update)

### Phase 3: Unified Commands (Medium Risk)

**Goal**: Add wbern-style composite commands

Changes:
1. Add `/taskie:complete-task` (implement + review + fix)
2. Add `/taskie:tdd-task` (TDD-enforced implementation)
3. Add `/taskie:red`, `/taskie:green`, `/taskie:refactor` (granular TDD)
4. Keep original commands for backward compatibility

Effort: Medium
Breaking Changes: None (additive only)

### Phase 4: Optional Beads Integration (Higher Risk)

**Goal**: Token efficiency for long-running tasks

Changes:
1. Add optional Beads CLI integration
2. Create `.llm/beads/` for Beads-specific instructions
3. Add beads-aware variants of key actions
4. Document hybrid Markdown+Beads workflow

Effort: High
Breaking Changes: None (optional feature)

---

## Part 4: Recommended First Steps

### Immediate Actions (This Session)

1. **Create TDD persona**: `.llm/personas/tdd.md`
2. **Update create-tasks.md**: Add requirement for test-first acceptance criteria
3. **Create fragment prototype**: `.llm/fragments/tdd-cycle.md`

### Next Session

1. **Create complete-task action**: `.llm/actions/complete-task.md`
2. **Add command wrapper**: `taskie/commands/complete-task.md`
3. **Test with sample project**

### Future Work

1. npm-based distribution option (like wbern)
2. Feature flags for TDD enforcement level
3. Optional Beads integration
4. Worktree management commands

---

## Appendix: Source Links

- [wbern/claude-instructions](https://github.com/wbern/claude-instructions) - TDD workflow toolkit
- [steveyegge/beads](https://github.com/steveyegge/beads) - AI agent memory system
- [Introducing Beads](https://steve-yegge.medium.com/introducing-beads-a-coding-agent-memory-system-637d7d92514a) - Steve Yegge's Medium article
- [npx @wbern/claude-instructions](https://www.npmjs.com/package/@wbern/claude-instructions) - npm package
