# Taskie Test Suite

This directory contains automated tests for the Taskie framework components.

## Quick Start

### Run All Tests

```bash
# From project root
./run-tests.sh

# Or using Make
make test
```

### Run with Verbose Output

```bash
./run-tests.sh --verbose

# Or using Make
make test-verbose
```

### Run Specific Test Suites

```bash
# Hook tests only
./run-tests.sh hooks

# Or using Make
make test-hooks
```

## Test Organization

```
tests/
├── README.md                              # This file
└── hooks/
    └── test-validate-ground-rules.sh     # Hook validation tests
```

## Hook Tests

### What's Tested

The `test-validate-ground-rules.sh` script validates the Claude Code Stop hook that enforces Taskie plan structure:

1. **Dependency Check** - Verifies jq is installed
2. **Invalid JSON Input** - Tests malformed JSON handling (exit 2)
3. **Invalid Directory** - Tests non-existent directory handling (exit 2)
4. **Infinite Loop Prevention** - Tests stop_hook_active flag
5. **Non-Taskie Projects** - Tests graceful skip when no .taskie directory
6. **Valid Plan Structure** - Tests successful validation
7. **Invalid Plan Structure** - Tests validation failure and blocking
8. **Plan with Design** - Tests validation with optional design.md

### Exit Codes

- **0** - All tests passed
- **1** - One or more tests failed

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

## Running Tests Manually

### Direct Execution

```bash
# From project root
bash tests/hooks/test-validate-ground-rules.sh

# With verbose output
bash tests/hooks/test-validate-ground-rules.sh --verbose

# From tests directory
cd tests/hooks
./test-validate-ground-rules.sh
```

### Using Make

```bash
# From project root
make test              # All tests
make test-hooks        # Hook tests only
make test-verbose      # Verbose output
make help             # Show all targets
```

## CI/CD Integration

These tests are designed to be easily integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run Taskie Tests
  run: |
    chmod +x run-tests.sh
    ./run-tests.sh
```

```yaml
# Example GitLab CI
test:
  script:
    - bash run-tests.sh
```

## Adding New Tests

### Hook Tests

1. Open `tests/hooks/test-validate-ground-rules.sh`
2. Add your test following the existing pattern:

```bash
print_header "Test N: Your Test Description"
RESULT=$(echo '{"cwd": ".", "stop_hook_active": false}' | bash "$HOOK_SCRIPT" 2>&1)
EXIT_CODE=$?
if [[ condition ]]; then
    print_pass "Your success message"
else
    print_fail "Your failure message"
fi
```

3. Update the test count in the summary

### New Test Suites

1. Create a new directory under `tests/` (e.g., `tests/commands/`)
2. Add test scripts following the naming pattern `test-*.sh`
3. Update `run-tests.sh` to include your new suite
4. Update `Makefile` with new targets
5. Document your tests in this README

## Troubleshooting

### jq not installed

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# RHEL/CentOS
sudo yum install jq
```

### Permission denied

```bash
chmod +x run-tests.sh
chmod +x tests/hooks/test-validate-ground-rules.sh
```

### Tests fail in CI but pass locally

- Ensure jq is installed in CI environment
- Check working directory is project root
- Verify bash version compatibility (requires bash 4+)

## Best Practices

1. **Run tests before committing** - Catch issues early
2. **Use verbose mode for debugging** - See detailed output
3. **Add tests for new features** - Maintain test coverage
4. **Keep tests fast** - Test suite should complete in < 10 seconds
5. **Use descriptive test names** - Make failures easy to diagnose

## Support

For issues with tests:
1. Run with `--verbose` flag for detailed output
2. Check that all dependencies are installed
3. Verify you're running from the project root
4. Open an issue with test output if problem persists
