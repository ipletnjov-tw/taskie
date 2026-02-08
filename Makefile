.PHONY: test test-hooks test-state test-validation help clean

# Default target
help:
	@echo "Taskie Test Targets:"
	@echo "  make test            - Run all tests"
	@echo "  make test-hooks      - Run all hook tests"
	@echo "  make test-state      - Run state/auto-review tests"
	@echo "  make test-validation - Run validation tests only"
	@echo "  make clean           - Clean up test artifacts"
	@echo ""

# Run all tests
test:
	@bash ./run-tests.sh all

# Run all hook tests
test-hooks:
	@bash ./run-tests.sh hooks

# Run state/auto-review tests
test-state:
	@bash ./run-tests.sh state

# Run validation tests only
test-validation:
	@bash ./run-tests.sh validation

# Clean up test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "Done."
