#!/bin/bash

# Taskie for Codex CLI - Uninstallation Script
# This script removes Taskie prompts from ~/.codex/prompts/

set -e

CODEX_PROMPTS_DIR="${CODEX_HOME:-$HOME/.codex}/prompts"

echo "Uninstalling Taskie prompts for Codex CLI..."
echo ""

# Check if any taskie- prompts exist
if ! ls "$CODEX_PROMPTS_DIR"/taskie-*.md >/dev/null 2>&1; then
    echo "No Taskie prompts found in $CODEX_PROMPTS_DIR"
    echo "Nothing to uninstall."
    exit 0
fi

# Show what will be removed
echo "The following files will be removed from $CODEX_PROMPTS_DIR:"
ls -1 "$CODEX_PROMPTS_DIR"/taskie-*.md
echo ""

read -p "Continue with uninstallation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Remove all taskie- prompts
echo "Removing Taskie prompts..."
rm -v "$CODEX_PROMPTS_DIR"/taskie-*.md

echo ""
echo "✓ Uninstallation complete!"
echo ""
echo "All Taskie prompts have been removed from $CODEX_PROMPTS_DIR"
echo ""
echo "Note: You may need to restart Codex CLI or start a new session."
