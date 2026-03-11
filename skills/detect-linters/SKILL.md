---
name: detect-linters
description: Detect linters and formatters configured in the project across Python, JS/TS, Rust, and Go. Used internally by /project-setup.
user-invocable: false
tools: Read, Bash, Glob
---

# Linter Detection

Find all configured linters and formatters, and determine the canonical lint command.

## Detection Sources

### Pre-commit (multi-language)
Read `.pre-commit-config.yaml` if it exists. Parse `repos[].hooks[].id` to identify linters:
- ruff, ruff-format, black, isort, flake8, mypy, pylint (Python)
- eslint, prettier (JS)
- rustfmt, clippy (Rust)

If pre-commit is configured, the canonical lint command is `pre-commit run --all-files`.

### Python
Check `pyproject.toml` for tool sections:
- `[tool.ruff]` or `[tool.ruff.lint]` → ruff
- `[tool.black]` → black
- `[tool.mypy]` → mypy
- `[tool.isort]` → isort
- `[tool.pylint]` → pylint
- `[tool.flake8]` → flake8 (via flake8-pyproject)

Check standalone config files: `.flake8`, `mypy.ini`, `.pylintrc`, `ruff.toml`, `.style.yapf`

Check `setup.cfg` for `[flake8]`, `[mypy]`, `[isort]` sections.

### JS/TS
- `package.json` → `scripts.lint`, `scripts.format`; `devDependencies` for eslint, prettier, biome
- `.eslintrc`, `.eslintrc.json`, `.eslintrc.js`, `.eslintrc.yml`, `eslint.config.js`, `eslint.config.mjs`
- `.prettierrc`, `.prettierrc.json`, `.prettierrc.js`, `prettier.config.js`
- `biome.json`, `biome.jsonc`

### Rust
- `rustfmt.toml` or `.rustfmt.toml` → rustfmt
- `.clippy.toml` or `clippy.toml` → clippy
- Presence of `Cargo.toml` implies `cargo fmt` and `cargo clippy` are available

### Go
- `.golangci.yml`, `.golangci.yaml`, `.golangci.toml` → golangci-lint
- Presence of `go.mod` implies `gofmt` / `go vet` are available

### Makefile
Read `Makefile` and check for targets named `lint`, `format`, `fmt`, `check`, `style`.

## Canonical Lint Command

Determine the single best lint command in this priority order:
1. `pre-commit run --all-files` (if `.pre-commit-config.yaml` exists)
2. `make lint` (if Makefile has `lint` target)
3. `npm run lint` / `pnpm lint` / `yarn lint` (if `package.json` has `scripts.lint`)
4. `ruff check . && ruff format --check .` (if ruff is the sole Python linter)
5. `cargo clippy` (Rust)
6. `golangci-lint run` (Go)
7. Individual linter commands as fallback

## Output

Return:
- List of detected linters with their config source
- The canonical lint command
- Suggested `permissions.allow` entries (e.g. `Bash(pre-commit run *)`, `Bash(ruff *)`)
- CLAUDE.md `## Linting` section content
