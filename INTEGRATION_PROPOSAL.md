# Integration Proposal: wbern/claude-instructions ↔ ipletnjov-tw/taskie

## Executive Summary

This proposal outlines strategies for integrating **wbern/claude-instructions** (a TDD-focused workflow toolkit) with **ipletnjov-tw/taskie** (a plan-driven feature implementation framework). Both tools share similar philosophies around structured development but serve different primary use cases and developer mindsets.

**Recommendation**: Implement a **Complementary Integration** approach where both tools coexist and users can leverage the best of both worlds based on their project needs.

---

## 1. Comparative Analysis

### 1.1 Core Philosophy & Approach

| Aspect | wbern/claude-instructions | ipletnjov-tw/taskie |
|--------|--------------------------|---------------------|
| **Primary Focus** | Test-Driven Development (TDD) discipline | Plan-driven feature implementation |
| **Workflow Model** | Red-Green-Refactor cycle | Plan → Tasks → Implementation → Review |
| **Developer Mindset** | Test-first, iterative refinement | Upfront planning, structured execution |
| **Granularity** | Single test at a time | Tasks with multiple subtasks |
| **Documentation** | Minimal (relies on tests as documentation) | Extensive (plan.md, design.md, task files) |
| **Context Preservation** | Through test suite | Through markdown files in git |

### 1.2 Strengths

#### wbern/claude-instructions Strengths
1. **TDD Discipline**: Enforces proper test-first development with red-green-refactor
2. **Simplicity**: Lightweight, focused commands with minimal overhead
3. **Rapid Iteration**: Quick feedback loops with `/cycle` command
4. **Git Workflow Integration**: Built-in shipping commands (`/ship`, `/show`, `/ask`) for different merge strategies
5. **Modularity**: 23+ specialized commands for specific development phases
6. **Customization**: Template system via `<claude-commands-template>` in CLAUDE.md/AGENTS.md
7. **Practice Tools**: `/kata` for generating TDD practice challenges
8. **Quality Gates**: `/tdd-review` evaluates tests against FIRST principles
9. **Worktree Management**: Built-in branch management utilities

#### ipletnjov-tw/taskie Strengths
1. **Comprehensive Planning**: Detailed upfront design and planning phase
2. **Context Resilience**: Extensive markdown documentation prevents context loss
3. **Task Decomposition**: Structured breakdown of complex features into manageable subtasks
4. **Multi-phase Reviews**: Plan review, task review, code review cycles
5. **Progress Tracking**: `tasks.md` provides clear overview of implementation status
6. **Complexity Management**: Handles large-scale features spanning many files
7. **Persona System**: Experimental role-based guidance (reviewer, SWE, designer, etc.)
8. **Recovery Mechanism**: `/continue-plan` allows resumption after context loss
9. **Quality Verification**: Must-run commands enforce verification at each step

### 1.3 Weaknesses

#### wbern/claude-instructions Weaknesses
1. **Limited Planning**: No comprehensive upfront planning for complex features
2. **Context Fragility**: Relies primarily on tests; less resilient to context loss in non-TDD scenarios
3. **Not All Problems Fit TDD**: Some features (config, infrastructure, documentation) don't naturally fit test-first
4. **No Task Decomposition**: Lacks structured breakdown of complex features
5. **Minimal Documentation**: May struggle with projects requiring detailed design docs
6. **Learning Curve**: Requires TDD discipline and mindset shift

#### ipletnjov-tw/taskie Weaknesses
1. **Heavy Process**: Extensive markdown generation may feel like overhead for small features
2. **No TDD Enforcement**: Doesn't enforce test-first development
3. **Manual Git Operations**: Requires explicit git commits (though guided)
4. **No Built-in Shipping**: Lacks PR/merge workflow automation
5. **Verbose**: Multiple review cycles can slow down simple changes
6. **No Quality Tools**: Missing test quality evaluation (FIRST principles, etc.)
7. **File Management**: Manual management of .taskie directory structure

### 1.4 Architecture Comparison

#### wbern/claude-instructions Architecture
- **Distribution**: npm package with CLI installer
- **Structure**: `.claude/commands/` directory with markdown command files
- **Customization**: Template injection via CLAUDE.md/AGENTS.md
- **Installation**: User-level or project-level via `npx @wbern/claude-instructions`
- **Variants**: With/without Beads MCP integration
- **Technology**: TypeScript, fs-extra, clack prompts
- **Build System**: tsup bundling, vitest testing, semantic-release

#### ipletnjov-tw/taskie Architecture
- **Distribution**: Claude Code plugin via marketplace
- **Structure**:
  - `taskie/commands/` - Command wrappers pointing to actions
  - `taskie/actions/` - Actual command prompts
  - `taskie/ground-rules.md` - Core workflow rules
  - Legacy `.llm/` directory for non-plugin usage
- **Customization**: Via additional instructions appended to commands
- **Installation**: `/plugin marketplace add` → `/plugin install`
- **Technology**: Pure markdown prompts, no build system
- **Working Directory**: `.taskie/plans/{plan-id}/` structure

---

## 2. Integration Strategies

### Strategy A: Complementary Integration (RECOMMENDED)

**Concept**: Both tools coexist, allowing developers to choose based on project phase and nature.

#### Implementation
1. **Create a unified plugin** that includes both toolsets
2. **Namespace commands clearly**:
   - Keep `/taskie:*` for plan-driven workflow
   - Add `/tdd:*` namespace for claude-instructions commands
3. **Provide workflow guidance** in README explaining when to use each
4. **Enable hybrid workflows** (detailed below)

#### Hybrid Workflow Examples

**A. TDD Within Taskie Tasks**
```bash
# Start with Taskie planning
/taskie:new-plan Implement user authentication system

# Review and refine plan
/taskie:plan-review
/taskie:post-plan-review

# Create tasks
/taskie:create-tasks

# Start a task with TDD discipline
/taskie:next-task
# Now switch to TDD for this task
/tdd:red    # Write failing test
/tdd:green  # Implement
/tdd:refactor  # Clean up

# Review the task
/taskie:code-review
/taskie:post-code-review
```

**B. Taskie Planning + TDD Execution**
```bash
# Use Taskie for upfront planning
/taskie:new-plan Refactor payment processing module
/taskie:create-tasks

# Use TDD commands for implementation
/tdd:cycle  # Execute red-green-refactor for each subtask

# Use Taskie for comprehensive reviews
/taskie:code-review
```

**C. TDD for Small Features**
```bash
# Skip Taskie overhead for simple features
/tdd:red    # Write test
/tdd:green  # Implement
/tdd:refactor  # Clean up
/tdd:commit  # Commit changes
```

#### Pros
- Flexibility to choose appropriate tool for the task
- Preserves strengths of both approaches
- Low migration risk (no breaking changes)
- Users can gradually adopt TDD within Taskie workflow
- Supports different project types and developer preferences

#### Cons
- Increased command surface area
- Potential confusion about which tool to use
- Requires clear documentation and guidance

---

### Strategy B: Merge into Enhanced Taskie

**Concept**: Integrate claude-instructions TDD commands as optional phases within Taskie tasks.

#### Implementation
1. Add new commands to Taskie:
   - `/taskie:tdd-subtask` - Implements one subtask using TDD cycle
   - `/taskie:tdd-review` - Evaluates test quality (FIRST principles)
   - `/taskie:ship` - Automates PR creation with context from plan
2. Enhance task files with TDD tracking:
   ```md
   ### Subtask 1.1: Add login endpoint
   - **Status**: completed
   - **TDD Cycle**:
     - Red: ✓ (commit: abc123)
     - Green: ✓ (commit: def456)
     - Refactor: ✓ (commit: ghi789)
   - **Test Quality Score**: 8/10 (FIRST principles)
   ```
3. Update ground-rules.md to include TDD best practices
4. Add git workflow automation from claude-instructions

#### Pros
- Single unified workflow
- TDD becomes natural part of task execution
- Reduces cognitive overhead of choosing tools
- Comprehensive tracking includes TDD steps

#### Cons
- Forces TDD even when not appropriate
- May make Taskie feel too heavyweight
- Loss of claude-instructions' simplicity
- Requires significant refactoring of both tools

---

### Strategy C: TDD-First with Taskie Planning Layer

**Concept**: Use claude-instructions as the primary workflow, add Taskie's planning commands as optional "macro" phase.

#### Implementation
1. Fork claude-instructions and add Taskie planning commands:
   - `/plan:create` - Creates implementation plan
   - `/plan:decompose` - Generates task breakdown
   - `/plan:review` - Reviews plan quality
2. Enhance `/issue` command to generate Taskie-style plans
3. Link TDD cycles to task tracking in tasks.md
4. Maintain `.taskie/plans/` structure for context preservation

#### Pros
- TDD remains the core discipline
- Planning becomes available when needed
- Lighter weight than full Taskie integration
- Appeals to TDD practitioners

#### Cons
- Loses Taskie's comprehensive review cycles
- Less suitable for non-TDD projects
- May fragment the Taskie user base
- Requires forking and maintaining claude-instructions

---

## 3. Detailed Recommendation: Strategy A Implementation

### 3.1 Plugin Structure

```
taskie/
├── .claude-plugin/
│   └── plugin.json                    # Updated with both namespaces
├── commands/
│   ├── taskie:new-plan.md
│   ├── taskie:next-task.md
│   ├── taskie:code-review.md
│   ├── ... (existing taskie commands)
│   ├── tdd:red.md                     # New TDD commands
│   ├── tdd:green.md
│   ├── tdd:refactor.md
│   ├── tdd:cycle.md
│   ├── tdd:commit.md
│   ├── tdd:ship.md
│   ├── tdd:show.md
│   ├── tdd:ask.md
│   ├── tdd:review.md
│   ├── tdd:kata.md
│   └── tdd:spike.md
├── actions/
│   ├── taskie/                        # Existing taskie actions
│   └── tdd/                          # New TDD actions
│       ├── red.md
│       ├── green.md
│       ├── refactor.md
│       └── ... (TDD action prompts)
├── ground-rules.md                    # Enhanced with TDD principles
└── workflows/                         # New directory
    ├── hybrid-tdd-taskie.md          # Workflow guides
    ├── pure-tdd.md
    └── pure-taskie.md
```

### 3.2 Enhanced Ground Rules

Update `ground-rules.md` to include:

```markdown
# Development Approaches

You have two complementary approaches available:

## Plan-Driven Development (Taskie)
Use `/taskie:*` commands for:
- Complex multi-task features
- Projects requiring detailed upfront design
- Features spanning many files/systems
- When context preservation is critical
- When extensive documentation is needed

## Test-Driven Development (TDD)
Use `/tdd:*` commands for:
- Clear, testable requirements
- Refactoring existing code
- Bug fixes with reproducible tests
- Small to medium features
- When rapid iteration is desired

## Hybrid Approach
Combine both:
1. Use `/taskie:new-plan` for overall planning
2. Use `/tdd:cycle` for implementing individual subtasks
3. Use `/taskie:code-review` for comprehensive reviews
4. Use `/tdd:ship` or `/taskie:*` shipping commands as appropriate
```

### 3.3 Command Integration

#### TDD Commands (New)

**`tdd:red.md`**
```markdown
---
description: Write one failing test (TDD Red phase)
---

# Write One Failing Test

You are in the RED phase of the TDD cycle.

## Rules
1. Write EXACTLY ONE failing test
2. The test should be for the smallest possible increment of functionality
3. Run the test to verify it fails
4. Do NOT write implementation code
5. Do NOT write multiple tests

## Context Awareness
If you're working within a Taskie task:
- Reference `.taskie/plans/{plan-id}/task-{task-id}.md` for context
- This test should advance one subtask
- Update the task file with test commit hash when complete

## Output
- Show the test code
- Show the test failure output
- Explain what functionality this test expects

$ARGUMENTS
```

**`tdd:green.md`**
```markdown
---
description: Implement minimal code to pass the test (TDD Green phase)
---

# Implement Minimal Code to Pass

You are in the GREEN phase of the TDD cycle.

## Rules
1. Write the MINIMUM code needed to pass the failing test
2. Do NOT add extra features or "nice to haves"
3. Do NOT refactor yet - keep it simple
4. Run the test to verify it passes
5. Do NOT write new tests

## Context Awareness
If you're working within a Taskie task:
- Update `.taskie/plans/{plan-id}/task-{task-id}.md` with implementation commit hash
- Mark subtask status as 'awaiting-review' if complete

## Output
- Show the implementation code
- Show all tests passing
- Confirm you're ready for refactor phase

$ARGUMENTS
```

**`tdd:cycle.md`**
```markdown
---
description: Execute complete red-green-refactor cycle
---

# Execute Full TDD Cycle

Run one complete iteration of:
1. RED: Write one failing test
2. GREEN: Implement minimal code to pass
3. REFACTOR: Improve code while maintaining green tests

## Context Awareness
If working within Taskie:
- Check current subtask from tasks.md
- Complete one subtask per cycle
- Update task file after each phase
- Run all must-run commands from subtask definition

$ARGUMENTS
```

**`tdd:ship.md`**
```markdown
---
description: Ship changes directly to main (for obvious changes)
---

# Ship to Main

Use this for obvious, low-risk changes that don't need PR review.

## Process
1. Verify all tests pass
2. Check git status
3. Create commit with conventional commit format
4. Push directly to main branch
5. Notify team (optional)

## Context Awareness
If working within Taskie plan:
- Include plan ID and task ID in commit message
- Example: `feat(plan-123/task-5): add user authentication`
- Update task status to 'completed'

## Safety Checks
- Confirm this is NOT a breaking change
- Confirm test coverage is adequate
- Confirm this follows team conventions

$ARGUMENTS
```

#### Enhanced Taskie Commands

**`taskie:next-task.md` (Enhanced)**
```markdown
---
description: Implement next task (optionally with TDD)
---

Perform the action described in @${CLAUDE_PLUGIN_ROOT}/actions/next-task.md

## TDD Option Available
After reading the task, you can choose to:
1. Implement with TDD: Use `/tdd:cycle` for each subtask
2. Implement traditionally: Follow normal Taskie workflow

Consider using TDD if:
- The task has clear testable requirements
- The task involves algorithmic logic
- The task is refactoring existing code

$ARGUMENTS
```

### 3.4 Plugin Metadata

Update `plugin.json`:
```json
{
  "name": "taskie",
  "description": "Framework for high-quality feature implementation with optional TDD workflows",
  "version": "2.0.0",
  "author": {
    "name": "Igor Pletnjov",
    "url": "https://github.com/ipletnjov-tw"
  },
  "keywords": [
    "task-management",
    "planning",
    "workflow",
    "tdd",
    "test-driven-development",
    "engineering",
    "quality"
  ],
  "workflows": {
    "plan-driven": {
      "commands": [
        "taskie:new-plan",
        "taskie:plan-review",
        "taskie:create-tasks",
        "taskie:next-task",
        "taskie:code-review"
      ]
    },
    "tdd-driven": {
      "commands": [
        "tdd:red",
        "tdd:green",
        "tdd:refactor",
        "tdd:cycle",
        "tdd:commit",
        "tdd:ship"
      ]
    },
    "hybrid": {
      "description": "Use Taskie planning with TDD execution",
      "commands": [
        "taskie:new-plan",
        "taskie:create-tasks",
        "tdd:cycle",
        "taskie:code-review",
        "tdd:ship"
      ]
    }
  }
}
```

### 3.5 Documentation Updates

**README.md additions**:

```markdown
## Workflows

Taskie now supports multiple development workflows:

### 1. Pure Plan-Driven (Traditional Taskie)
Best for: Complex features, large refactors, projects requiring extensive documentation

[Existing Taskie workflow documentation]

### 2. Pure Test-Driven Development (TDD)
Best for: Clear requirements, bug fixes, algorithmic features, refactoring

```bash
# Write a failing test
/tdd:red Write test for user login validation

# Implement minimal solution
/tdd:green

# Refactor while keeping tests green
/tdd:refactor

# Or run all three phases
/tdd:cycle Implement password hashing
```

### 3. Hybrid: Planning + TDD Execution
Best for: Complex features that benefit from both upfront planning and test discipline

```bash
# Phase 1: Plan
/taskie:new-plan Implement OAuth2 authentication
/taskie:plan-review
/taskie:create-tasks

# Phase 2: Execute with TDD
/taskie:next-task  # Read the task
/tdd:cycle         # Implement first subtask with TDD
/tdd:cycle         # Implement second subtask with TDD

# Phase 3: Review
/taskie:code-review
/taskie:post-code-review

# Phase 4: Ship
/tdd:ship  # For obvious changes
# or
/tdd:show  # For changes needing team visibility
# or
/tdd:ask   # For changes requiring review
```

## TDD Command Reference

- `/tdd:red` - Write one failing test
- `/tdd:green` - Implement minimal code to pass
- `/tdd:refactor` - Improve code while keeping tests green
- `/tdd:cycle` - Execute full red-green-refactor cycle
- `/tdd:spike` - Exploratory coding before formal TDD
- `/tdd:review` - Evaluate test quality (FIRST principles)
- `/tdd:commit` - Create commit following project standards
- `/tdd:ship` - Merge directly to main (obvious changes)
- `/tdd:show` - Create auto-merge PR with team notification
- `/tdd:ask` - Create PR requiring review
- `/tdd:kata` - Generate TDD practice challenge
```

### 3.6 Migration Path for Existing Users

1. **Backward Compatibility**: All existing `/taskie:*` commands work unchanged
2. **Opt-in TDD**: Users can start using `/tdd:*` commands whenever desired
3. **Documentation**: Clear guides for when to use which workflow
4. **Examples**: Provide example projects using each workflow pattern

### 3.7 Implementation Steps

1. **Phase 1**: Add TDD command files to `taskie/commands/tdd/` namespace
2. **Phase 2**: Create TDD action prompts in `taskie/actions/tdd/`
3. **Phase 3**: Update ground-rules.md with TDD principles
4. **Phase 4**: Add workflow guide documentation
5. **Phase 5**: Update README with hybrid workflow examples
6. **Phase 6**: Test integration with sample projects
7. **Phase 7**: Update plugin.json version to 2.0.0
8. **Phase 8**: Release and announce

---

## 4. Alternative Approaches

### 4.1 Minimal Integration

If full integration feels like too much overhead:

**Option**: Add just 2-3 core TDD commands to Taskie
- `/taskie:tdd-cycle` - Run red-green-refactor for current subtask
- `/taskie:test-review` - Evaluate test quality

**Pros**: Minimal changes, low risk
**Cons**: Misses shipping automation and other valuable commands

### 4.2 Separate Plugins

Keep tools completely separate but document interoperability:
- Maintain both as independent plugins
- Document hybrid workflows in both READMEs
- Provide scripts to install both together

**Pros**: Zero integration complexity, clean separation
**Cons**: Manual coordination, no seamless workflow

### 4.3 Template-Based Integration

Use claude-instructions' template system to inject Taskie planning:
- Create `<claude-commands-template>` blocks that reference Taskie plans
- claude-instructions commands check for `.taskie/plans/` and adapt
- Minimal code changes, mostly documentation

**Pros**: Lightweight, respects both architectures
**Cons**: Loose coupling, may feel disconnected

---

## 5. Recommended Next Steps

1. **Gather Feedback**: Share this proposal with stakeholders and users of both tools
2. **Build Prototype**: Implement Strategy A with 3-5 core TDD commands
3. **Test Hybrid Workflow**: Use on a real project to validate the approach
4. **Iterate**: Refine based on practical experience
5. **Document**: Create comprehensive guides for each workflow pattern
6. **Release**: Ship v2.0.0 with integrated TDD support
7. **Evangelize**: Write blog posts / tutorials showing hybrid workflow value

---

## 6. Conclusion

**wbern/claude-instructions** and **ipletnjov-tw/taskie** are philosophically aligned but tactically different. Rather than forcing a choice, the Complementary Integration approach (Strategy A) offers the best of both worlds:

- **Flexibility**: Choose the right tool for each situation
- **Gradual Adoption**: TDD practitioners can ease into planning; planners can adopt TDD incrementally
- **Risk Management**: No breaking changes to existing workflows
- **Maximum Value**: Leverage TDD discipline, planning rigor, and comprehensive reviews

The key insight is that these tools address different aspects of software quality:
- **claude-instructions** ensures code correctness through tests
- **Taskie** ensures feature completeness through planning and decomposition

Together, they create a comprehensive development framework suitable for projects of any complexity.
