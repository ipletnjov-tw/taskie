.PHONY: test test-hooks test-verbose help clean

# Default target
help:
	@echo "Taskie Test Targets:"
	@echo "  make test         - Run all tests"
	@echo "  make test-hooks   - Run hook tests only"
	@echo "  make test-verbose - Run tests with verbose output"
	@echo "  make clean        - Clean up test artifacts"
	@echo ""

# Run all tests
test:
	@bash ./run-tests.sh

# Run hook tests only
test-hooks:
	@bash ./run-tests.sh hooks

# Run tests with verbose output
test-verbose:
	@bash ./run-tests.sh --verbose

# Clean up test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "Done."
