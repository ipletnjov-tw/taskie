#!/bin/bash

# Taskie for Codex CLI - Installation Script
# This script installs Taskie prompts to ~/.codex/prompts/

set -e

CODEX_PROMPTS_DIR="${CODEX_HOME:-$HOME/.codex}/prompts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/codex"

echo "Installing Taskie prompts for Codex CLI..."
echo ""

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    exit 1
fi

# Create target directory if it doesn't exist
mkdir -p "$CODEX_PROMPTS_DIR"

# Copy all markdown files
echo "Copying prompts to $CODEX_PROMPTS_DIR..."
cp -v "$SOURCE_DIR"/*.md "$CODEX_PROMPTS_DIR/"

echo ""
echo "✓ Installation complete!"
echo ""
echo "Available Taskie prompts in Codex CLI:"
echo "  /prompts:taskie-new-plan              - Create a new implementation plan"
echo "  /prompts:taskie-continue-plan         - Continue an existing implementation plan"
echo "  /prompts:taskie-plan-review           - Review and critique the current plan"
echo "  /prompts:taskie-post-plan-review      - Address plan review comments"
echo "  /prompts:taskie-create-tasks          - Generate tasks from the current plan"
echo "  /prompts:taskie-tasks-review          - Review the task list and task files"
echo "  /prompts:taskie-post-tasks-review     - Address task review comments"
echo "  /prompts:taskie-next-task             - Start implementing the next task"
echo "  /prompts:taskie-continue-task         - Continue working on the current task"
echo "  /prompts:taskie-next-task-tdd         - Implement next task using strict TDD"
echo "  /prompts:taskie-code-review           - Critically review implemented code"
echo "  /prompts:taskie-post-code-review      - Apply code review feedback"
echo "  /prompts:taskie-complete-task         - Implement + review + fix in one command"
echo "  /prompts:taskie-complete-task-tdd     - TDD implementation with automatic review"
echo ""
echo "Note: You may need to restart Codex CLI or start a new session for the prompts to be recognized."
