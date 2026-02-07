# Taskie Plugin

Taskie is a prompt framework plugin for Claude Code. See @README.md for details.

## Versioning

**IMPORTANT: Every change must include a version bump.** Both JSON files must be updated together:

- `.claude-plugin/marketplace.json` — the `plugins[0].version` field
- `taskie/.claude-plugin/plugin.json` — the `version` field

Follow [SemVer](https://semver.org/) for the plugin version (currently in the `MAJOR.MINOR.PATCH` format):

- **MAJOR** — breaking changes that require users to update their setup or workflows (e.g., removing/renaming commands, changing hook behavior, restructuring the plugin directory layout)
- **MINOR** — new functionality that is backwards-compatible (e.g., adding new actions, commands, personas, or optional features)
- **PATCH** — backwards-compatible bug fixes, typo corrections, prompt wording improvements, or documentation updates

## Testing

Run all tests before committing: `make test`
