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
claude plugin install claude-code-project-setup
```

Or install from the repository directly:

```bash
claude plugin install /path/to/project-setup
```

### Try without installing (session-only)

To test the plugin without installing it, load it for a single session:

```bash
cd /your/project
claude --plugin-dir /path/to/project-setup
```

The plugin is active only for that session. Commands are namespaced by the plugin name, so run `/project-setup:project-setup` instead of `/project-setup`.

## Usage

### Testing with a PyCharm project

1. Open a terminal in your PyCharm project root (the folder containing `.idea/`)
2. Launch Claude with the plugin:
   ```bash
   cd /your/pycharm/project
   claude --plugin-dir /path/to/project-setup
   ```
3. Inside the session, run a dry run first:
   ```
   /project-setup:project-setup --dry-run
   ```

The plugin reads `.idea/*.iml` (source roots), `misc.xml` (Python interpreter), and `runConfigurations/*.xml` (test setup). If the output looks right, apply it:

```
/project-setup:project-setup
```

**Note:** The plugin only detects folders that PyCharm has registered as modules in `.idea/modules.xml`. If you have multiple folders open in PyCharm but they aren't configured as modules (e.g. you opened them informally alongside the main project), the plugin won't find them. In that case, add them manually — see [Manual directory configuration](#manual-directory-configuration) below.

### Auto-configure a project

```
/project-setup:project-setup
```

Runs all detectors, shows a summary of findings, and asks for approval before writing configuration files.

### Dry run (no writes)

```
/project-setup:project-setup --dry-run
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
- `read` (default) — adds `Read`, `Glob`, `Grep`
- `read-only` — adds `Read` only (no search tools)
- `edit` — adds `Read`, `Glob`, `Grep`, `Edit`, `Write`
- `full` — adds `Read`, `Glob`, `Grep`, `Edit`, `Write`, `Bash(*)`

## Manual directory configuration

If the plugin can't detect your extra directories automatically, create `.claude/settings.json` in your project root:

```json
{
  "permissions": {
    "additionalDirectories": [
      "../other-project",
      "../another-project"
    ]
  }
}
```

Paths are relative to the project root. Claude will have read access to these directories without prompting.

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

## Publishing to npm

The GitHub Actions workflow publishes to npm automatically when you push a version tag:

```bash
npm version patch  # or minor/major
git push --follow-tags
```

### Setup

1. Create an account on https://www.npmjs.com
2. Go to **Access Tokens** in your account settings
3. Generate a new **Automation** token
4. Add it as a GitHub repo secret named `NPM_TOKEN` under **Settings > Secrets and variables > Actions**

## Submitting to the official directory

This plugin can be submitted to the [Anthropic Plugin Directory](https://github.com/anthropics/claude-plugins-official) for review and distribution.

## License

MIT
