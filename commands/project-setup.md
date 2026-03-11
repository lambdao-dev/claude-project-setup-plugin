---
description: Auto-discover project tooling and configure .claude/ settings
argument-hint: "[--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Skill", "AskUserQuestion"]
---

# Project Setup - Auto-configure .claude/

Analyze the current project to discover tooling (virtual environments, linters, test runners, additional directories) and write the corresponding `.claude/settings.json` and `.claude/CLAUDE.md` configuration.

## Step 1: Read Existing Configuration

Read these files if they exist (store their contents — all changes must merge, never overwrite):

- `.claude/settings.json`
- `.claude/settings.local.json`
- `.claude/CLAUDE.md` or `CLAUDE.md`
- `.claude/project-setup.local.md` (plugin config with `dir-permission-default` in frontmatter)

If `.claude/project-setup.local.md` does not exist, the default directory permission level is `read`.

## Step 2: Run Detection

Run each detection phase. For each, read the relevant files and run commands as described below. Track all findings in a structured internal summary.

### 2a: IDE Settings (run first — feeds hints to other detectors)

Check for IDE configuration files and extract hints:

**VSCode** — read `.vscode/settings.json` if it exists:
- `python.defaultInterpreterPath` → venv path hint
- `python.testing.pytestEnabled`, `python.testing.pytestArgs` → test runner hint
- `python.linting.ruffEnabled`, `python.linting.flake8Enabled`, `python.linting.mypyEnabled` → linter hints
- `python.envFile` → env file location
- `eslint.*`, `editor.defaultFormatter` → JS linter hints
- Check for `*.code-workspace` files → multi-root workspace dirs

**PyCharm** — read `.idea/` contents if the directory exists:
- `*.iml` files → look for `<sourceFolder>` and `<excludeFolder>` XML elements → source roots
- `misc.xml` → `<component name="ProjectRootManager">` → SDK/interpreter path → venv hint
- `runConfigurations/*.xml` → `<configuration type="tests">` → test runner config

Store all hints for use in subsequent detection phases.

### 2b: Environment Detection

Detect language runtimes and virtual environments. Check in order:

**Python:**
1. Standard venv dirs: `.venv/`, `venv/`, `env/` (check if `bin/python` exists inside)
2. `poetry.lock` → run `poetry env info -p 2>/dev/null`
3. `Pipfile` → run `pipenv --venv 2>/dev/null`
4. `pdm.lock` → run `pdm venv --path in-project 2>/dev/null`
5. `uv.lock` → default `.venv/`
6. IDE hint from step 2a
7. Validate: run `<venv>/bin/python --version` to confirm
8. Record: venv path, Python version, package manager

**Node/JS:**
1. Check `package.json` exists
2. Detect package manager: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lockb` → bun, else npm
3. Check `.nvmrc` or `.node-version` for version pinning
4. Record: package manager, node version constraint

**Rust:**
1. Check `Cargo.toml` exists
2. Check `rust-toolchain.toml` or `rust-toolchain` for toolchain
3. Record: toolchain, edition

**Go:**
1. Check `go.mod` exists → extract module path and Go version
2. Record: Go version, module path

### 2c: Directory Detection

Find additional source directories that should be accessible:

1. **Monorepo configs**: `lerna.json`, `pnpm-workspace.yaml`, `package.json` `workspaces` field
2. **Git submodules**: run `git submodule status 2>/dev/null`
3. **Cargo workspaces**: `Cargo.toml` `[workspace]` section with `members`
4. **Go workspaces**: `go.work` file
5. **IDE source roots**: PyCharm `.iml` sourceFolder entries, VSCode `*.code-workspace` folders
6. **Symlinks**: check for symlinks pointing outside the project root

Only include directories that exist and are outside the current project root.

### 2d: Linter Detection

Find linters and formatters. Check these sources:

1. `.pre-commit-config.yaml` → parse repos/hooks for linter names (ruff, black, isort, flake8, mypy, pylint, eslint, prettier, etc.)
2. `pyproject.toml` → `[tool.ruff]`, `[tool.black]`, `[tool.mypy]`, `[tool.isort]`, `[tool.pylint]`
3. `setup.cfg` → `[flake8]`, `[mypy]`, `[isort]`
4. `package.json` → `scripts.lint`, `devDependencies` for eslint/prettier/biome
5. `biome.json` or `biome.jsonc`
6. `.eslintrc*`, `.prettierrc*`, `ruff.toml`, `.flake8`, `mypy.ini`, `.pylintrc`
7. `Cargo.toml` → clippy config; `rustfmt.toml`
8. `.golangci.yml` or `.golangci.yaml`
9. `Makefile` → `lint` or `format` targets
10. IDE hints from step 2a

Determine the canonical lint command (priority order):
- `pre-commit run --all-files` (if `.pre-commit-config.yaml` exists)
- `make lint` (if Makefile has lint target)
- `npm run lint` / `pnpm lint` / `yarn lint` (if package.json scripts.lint exists)
- `ruff check .` (if ruff configured)
- `cargo clippy` (if Rust project)
- `golangci-lint run` (if Go project)
- Individual linter commands as fallback

### 2e: Test Runner Detection

Find test runners and how to run tests:

1. `pyproject.toml` → `[tool.pytest.ini_options]`; also `pytest.ini`, `conftest.py`
2. `tox.ini` → `[testenv]` commands
3. `noxfile.py` or `nox.py`
4. `package.json` → `scripts.test`; also jest/vitest/mocha/playwright config files
5. `Cargo.toml` → `cargo test`
6. `go.mod` + `*_test.go` files → `go test ./...`
7. `Makefile` → `test` or `check` targets
8. IDE hints from step 2a (PyCharm run configurations)

Determine the canonical test command and detect test directory convention (`tests/`, `test/`, co-located, etc.).

## Step 3: Aggregate Findings

Build two proposed outputs:

### Proposed `.claude/settings.json` changes

Merge with existing settings using these rules:
- `permissions.allow`: union with existing (no duplicates)
- `permissions.deny`: **never modified**
- `permissions.additionalDirectories`: union with existing
- `env`: merge keys; **existing values take precedence**
- All other keys: left untouched

**Environment mapping:**

**CRITICAL: NEVER set `PATH` in the `env` object.** `env` values are NOT expanded — `$PATH` or `${PATH}` are passed as literal strings, completely replacing PATH and breaking all shell commands. Only set `VIRTUAL_ENV` in `env`. To prepend the venv bin to `PATH`, add a `SessionStart` hook:

- Python venv → `"env": {"VIRTUAL_ENV": "/absolute/path"}`
- PATH activation → `"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "export PATH=\"/absolute/path/bin:$PATH\""}]}]}`

When merging hooks, append to the existing `SessionStart` array if it already has entries.

**Directory mapping (based on `dir-permission-default` setting):**
- `read` → add `Read(path/**)` to `permissions.allow`
- `edit` → add `Read(path/**)`, `Edit(path/**)`, `Write(path/**)`
- `full` → add `Read(path/**)`, `Edit(path/**)`, `Write(path/**)`, `Bash(*)` scoped to path

**Linter mapping:**
- Add `permissions.allow` entries for lint commands (e.g. `Bash(pre-commit run *)`, `Bash(ruff check *)`)

**Test runner mapping:**
- Add `permissions.allow` entries for test commands (e.g. `Bash(pytest *)`, `Bash(cargo test *)`)

### Proposed `.claude/CLAUDE.md` additions

Only append sections whose `##` header does NOT already exist in the current CLAUDE.md. Sections to add:

- `## Environment` — language version, venv location, how to activate
- `## Linting` — canonical lint command, configured linters
- `## Testing` — canonical test command, how to run a single test, test directory

Keep each section to 3-5 lines max. Be concise and actionable.

## Step 4: Present Summary

Show the user a clear summary of what was detected and what will be written:

```
## Detection Results

### Environment
- Python 3.12.4 via .venv/ (managed by uv)

### Additional Directories
- ../shared-libs/ (read access)

### Linters
- pre-commit (ruff, mypy, black)
- Canonical command: pre-commit run --all-files

### Test Runner
- pytest (tests/ directory)
- Canonical command: pytest

### Proposed Changes
- .claude/settings.json: +3 permissions.allow, +1 additionalDirectories, +2 env vars
- .claude/CLAUDE.md: +3 new sections (Environment, Linting, Testing)
```

If `$ARGUMENTS` contains `--dry-run`, stop here. Do not write any files.

## Step 5: Write Configuration

After presenting the summary, ask the user for approval using AskUserQuestion before writing.

Once approved:
1. Create `.claude/` directory if it doesn't exist
2. Write/merge `.claude/settings.json` (read existing → merge → write)
3. Write/append to `.claude/CLAUDE.md` (only new sections)
4. Show what was written

## Step 6: Validate

Run `/project-setup:check` to validate the written configuration.
