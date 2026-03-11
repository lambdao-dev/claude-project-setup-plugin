---
description: Validate that .claude/ configuration is correct and functional
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
---

# Project Setup Check

Validate the current `.claude/` configuration by checking that all referenced tools, paths, and commands actually work.

## Checks to Perform

Read `.claude/settings.json` and `.claude/CLAUDE.md` (or `CLAUDE.md`). For each configured item, run the corresponding validation:

### 1. Settings File Valid

```bash
python3 -m json.tool .claude/settings.json > /dev/null 2>&1
```
If this fails, try `jq . .claude/settings.json`. Report JSON syntax errors.

### 2. Virtual Environment

If `env.VIRTUAL_ENV` is set in settings.json:
- Check the path exists: `test -d "$VIRTUAL_ENV"`
- Check Python is executable: `"$VIRTUAL_ENV/bin/python" --version`
- Report Python version on success
- Check that a `SessionStart` hook exists to prepend venv bin to PATH (warn if missing)

### 3. Additional Directories

For each path in `permissions.additionalDirectories`:
- Check it exists: `test -d "<path>"`
- Check it's readable: `test -r "<path>"`
- Report if missing or unreadable

### 4. Linters

For each linter command found in `permissions.allow` or mentioned in CLAUDE.md:
- Check the binary is available: `command -v <linter>`
- If pre-commit: `pre-commit --version`
- If ruff: `ruff --version`
- If eslint: `npx eslint --version` or `eslint --version`
- If cargo clippy: `cargo clippy --version`
- If golangci-lint: `golangci-lint --version`

### 5. Test Runners

For each test runner found in `permissions.allow` or mentioned in CLAUDE.md:
- Check it's available: `command -v <runner>`
- Dry-run collection to verify config:
  - pytest: `pytest --co -q 2>&1 | head -5`
  - jest: `npx jest --listTests 2>&1 | head -5`
  - cargo test: `cargo test --no-run 2>&1 | tail -3`
  - go test: `go test ./... -list '.*' -run '^$' 2>&1 | head -5`

### 6. Node Environment

If `package.json` exists and a package manager was configured:
- Check lock file exists
- Check `node_modules/` exists (warn if missing, suggest install command)

## Output Format

Present results as a checklist:

```
## Project Setup Check

[PASS] .claude/settings.json is valid JSON
[PASS] Virtual environment: .venv/ (Python 3.12.4)
[PASS] Additional directory: ../shared-libs/ (readable)
[PASS] Linter: ruff 0.8.0 (available)
[PASS] Linter: mypy 1.14.0 (available)
[FAIL] Test runner: pytest collection failed
       → Error: ModuleNotFoundError: No module named 'myapp'
       → Fix: Activate venv first or check PYTHONPATH in settings.json env
[WARN] node_modules/ not found
       → Fix: Run `npm install` to install dependencies
```

Use `[PASS]`, `[FAIL]`, or `[WARN]` prefixes. For failures, include the error and a suggested fix.

At the end, show a summary line:
```
Result: 5/6 checks passed, 1 failed, 1 warning
```
