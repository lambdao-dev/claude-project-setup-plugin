# project-setup

A Claude Code plugin that auto-discovers project tooling and configures `.claude/` accordingly.

Detects virtual environments, linters, test runners, IDE settings, and additional source directories, then writes the appropriate `.claude/settings.json` and `.claude/CLAUDE.md` configuration.

## Rationale

Your IDE already knows your project: the virtual environment, the linters, the test runner, the source roots. But Claude doesn't — without explicit configuration it falls back to generic assumptions, misses project-specific tooling, and can't access dependency sources sitting one directory over.

This plugin bridges that gap. It reads what your IDE and project files already declare, then writes the matching `.claude/` configuration so Claude uses the right interpreter, runs the right linter, and has access to the right directories — no manual setup required.

## Features

- **Environment detection** — Python venvs (standard, Poetry, Pipenv, PDM, uv), Node.js, Rust, Go
- **IDE settings** — Extracts hints from VSCode, PyCharm, Vim/Neovim, Emacs configs
- **Linter detection** — pre-commit, ruff, black, mypy, eslint, prettier, clippy, golangci-lint, and more
- **Test runner detection** — pytest, tox, nox, jest, vitest, cargo test, go test
- **Directory detection** — Monorepo workspaces, git submodules, IDE source roots, symlinks

## Installation

```bash
claude plugin add claude-code-project-setup
```

Or install from the repository directly:

```bash
claude plugin add /path/to/project-setup
```

## Usage

### Auto-configure a project

```
/project-setup
```

Runs all detectors, shows a summary of findings, and asks for approval before writing configuration files.

### Dry run (no writes)

```
/project-setup --dry-run
```

Runs detection and shows the proposed changes without writing any files.

### Validate existing configuration

```
/project-setup:check
```

Checks that all referenced paths, tools, and commands in `.claude/settings.json` and `.claude/CLAUDE.md` actually work.

## Configuration

Create `.claude/project-setup.local.md` to customize behavior:

```yaml
---
dir-permission-default: read
---
```

`dir-permission-default` controls what permissions are granted for discovered additional directories:
- `read` (default) — adds `Read(path/**)`
- `edit` — adds `Read`, `Edit`, `Write`
- `full` — adds `Read`, `Edit`, `Write`, `Bash(*)`

## What it writes

### `.claude/settings.json`

- `permissions.allow` — lint and test commands
- `permissions.additionalDirectories` — discovered external source directories
- `env.VIRTUAL_ENV` — Python virtual environment path
- `hooks.SessionStart` — PATH activation for venvs

Existing settings are merged, never overwritten. `permissions.deny` is never modified.

### `.claude/CLAUDE.md`

Appends concise sections (only if the `##` header doesn't already exist):
- `## Environment` — language version, venv location
- `## Linting` — canonical lint command
- `## Testing` — canonical test command, single-test pattern

## Submitting to the official directory

This plugin can be submitted to the [Anthropic Plugin Directory](https://github.com/anthropics/claude-plugins-official) for review and distribution.

## License

MIT
