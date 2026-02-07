# Taskie Test Suite

This directory contains automated tests for the Taskie framework components.

## Usage

```bash
./run-tests.sh              # Run all tests
./run-tests.sh hooks        # Run only hook tests
./run-tests.sh --verbose    # Run with verbose output
make test                   # Run all tests via Make
```

## Test Organization

```
tests/
├── README.md
└── hooks/
    └── test-validate-ground-rules.sh
```

## Hook Tests

The `test-validate-ground-rules.sh` script validates the Claude Code Stop hook that enforces Taskie plan structure:

1. **Dependency Check** - Verifies jq is installed
2. **Invalid JSON Input** - Tests malformed JSON handling (exit 2)
3. **Invalid Directory** - Tests non-existent directory handling (exit 2)
4. **Infinite Loop Prevention** - Tests stop_hook_active flag
5. **Non-Taskie Projects** - Tests graceful skip when no .taskie directory
6. **Valid Plan Structure** - Tests successful validation
7. **Invalid Plan Structure** - Tests missing plan.md and invalid filename
8. **Nested Directories** - Tests files in subdirectories of a plan
9. **Review Without Base File** - Tests review file without its base document
10. **Post-Review Without Review** - Tests post-review without matching review
11. **Task Files Without tasks.md** - Tests task files present but tasks.md missing
12. **Non-Table tasks.md** - Tests tasks.md containing prose instead of a table
13. **Empty tasks.md** - Tests tasks.md with no table rows

### Expected Behavior

| Test Scenario | Exit Code | Output Type | Decision |
|---------------|-----------|-------------|----------|
| Missing jq | 2 | stderr | Operational error |
| Invalid JSON | 2 | stderr | Operational error |
| Invalid directory | 2 | stderr | Operational error |
| stop_hook_active | 0 | JSON (suppressOutput) | Allow stop |
| No .taskie dir | 0 | JSON (suppressOutput) | Allow stop |
| Valid plan | 0 | JSON (systemMessage) | Allow stop |
| Invalid plan | 0 | JSON (decision: block) | Block stop |
| Nested directories | 0 | JSON (decision: block) | Block stop |
| Review without base | 0 | JSON (decision: block) | Block stop |
| Post-review without review | 0 | JSON (decision: block) | Block stop |
| Tasks without tasks.md | 0 | JSON (decision: block) | Block stop |
| Non-table tasks.md | 0 | JSON (decision: block) | Block stop |
| Empty tasks.md | 0 | JSON (decision: block) | Block stop |
