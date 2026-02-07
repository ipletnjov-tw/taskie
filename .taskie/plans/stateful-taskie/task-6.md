# Task 6: Ground Rules, Codex CLI Updates, and Edge Case Tests

**Prerequisites**: Tasks 1-3 (hook must be fully implemented for edge case tests). Subtasks 6.1-6.2 (ground-rules, Codex updates) can run in parallel with Tasks 4-5 since they don't depend on action file changes.

Update `ground-rules.md` with state.json documentation, update Codex CLI prompts where practical, write test suite 6 (12 edge case & integration tests).

## Subtasks

### Subtask 6.1: Update `ground-rules.md`
- **Short description**: Add state.json to the documented directory structure, document that `state.json` must be updated after every phase transition, add state file schema reference, note that `state.json` is the authoritative source for "where we are" — not git history.
- **Status**: pending
- **Sample git commit message**: Update ground-rules.md with state.json documentation
- **Git commit hash**:
- **Priority**: medium
- **Complexity**: 3
- **Test approach**: Manual: verify ground-rules mentions state.json in directory structure and documents the state-first approach. `make test` still passes (validation rules unchanged).
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - `state.json` appears in the documented directory structure
  - Phase transition state update requirement is documented
  - Schema reference or summary is included
  - `state.json` described as authoritative source over git history
  - Existing ground rules content preserved (additive changes only)

### Subtask 6.2: Update Codex CLI prompts
- **Short description**: Update `taskie-new-plan.md` to initialize `state.json` after plan creation (same as Claude Code variant). Update `taskie-continue-plan.md` to read `state.json` for continuation routing (primary benefit for Codex users). Other Codex prompts are NOT updated — without hooks to enforce state updates, making every prompt manually update `state.json` is fragile.
- **Status**: pending
- **Sample git commit message**: Update Codex CLI prompts for state.json support
- **Git commit hash**:
- **Priority**: medium
- **Complexity**: 3
- **Test approach**: Manual: verify both Codex prompt files have state.json instructions. Run `./install-codex.sh` and verify prompts are copied correctly.
- **Must-run commands**: `./install-codex.sh` (if Codex is installed)
- **Acceptance criteria**:
  - `taskie-new-plan.md` initializes `state.json` with all 8 fields
  - `taskie-continue-plan.md` reads `state.json` for routing (same logic as Claude Code variant)
  - Other Codex prompts remain unchanged
  - Both files reference `~/.codex/prompts/taskie-ground-rules.md` for ground rules

### Subtask 6.3: Write test suite 6 (edge cases & integration)
- **Short description**: Implement all 12 tests from suite 6: multiple plan directories, unknown fields, null phase_iteration, unexpected review_model, concurrent plan creation, auto-review precedence over validation, empty plan directory, max_reviews=0, backwards compatibility (no state.json), full model alternation across 4 iterations, two consecutive clean integration, atomic write cleanup.
- **Status**: pending
- **Sample git commit message**: Add test suite 6 for edge cases and integration tests
- **Git commit hash**:
- **Priority**: medium
- **Complexity**: 6
- **Test approach**: Run `make test` and verify all 12 tests pass.
- **Must-run commands**: `make test`
- **Acceptance criteria**:
  - `tests/hooks/test-stop-hook-edge-cases.sh` contains 12 tests matching plan specification
  - Test 1: validates most-recent-plan selection with multiple plan dirs
  - Test 5: state.json exists with `next_phase: null` (or non-review phase) but plan.md missing (crash during initialization) — validation blocks for missing plan.md (rule 1), auto-review doesn't run because next_phase isn't a review phase
  - Test 8: verifies `max_reviews: 0` advances state without CLI invocation
  - Test 10: full model alternation integration (4 iterations, mock CLI)
  - Test 11: two consecutive clean reviews integration (2 hook invocations)
  - Test 12: no temp files left behind after atomic write
  - All tests use shared helpers and mock claude
  - `make test` passes with all 80 tests green across all suites
