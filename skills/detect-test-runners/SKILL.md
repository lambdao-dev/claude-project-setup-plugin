---
name: detect-test-runners
description: Detect test runners and testing configuration across Python, JS/TS, Rust, and Go. Used internally by /project-setup.
user-invocable: false
tools: Read, Bash, Glob
---

# Test Runner Detection

Find test runners, test directories, and determine the canonical test command.

## Detection Sources

### Python
- `pyproject.toml` → `[tool.pytest.ini_options]` → pytest
- `pytest.ini` → pytest
- `setup.cfg` → `[tool:pytest]` → pytest
- `conftest.py` at project root → pytest
- `tox.ini` → tox (extract `[testenv]` commands section)
- `noxfile.py` or `nox.py` → nox
- Test directories: check for `tests/`, `test/`, `src/tests/`

### JS/TS
- `package.json` → `scripts.test` → extract runner name
- `jest.config.js`, `jest.config.ts`, `jest.config.json` → jest
- `vitest.config.js`, `vitest.config.ts`, `vite.config.ts` (with test section) → vitest
- `.mocharc.yml`, `.mocharc.json` → mocha
- `playwright.config.ts`, `playwright.config.js` → playwright (e2e)
- Test directories: check for `__tests__/`, `test/`, `tests/`, `spec/`

### Rust
- `Cargo.toml` exists → `cargo test`
- Check for `tests/` directory (integration tests) and `#[cfg(test)]` modules (unit tests)
- `benches/` directory → `cargo bench`

### Go
- `go.mod` exists → `go test ./...`
- Check for `*_test.go` files to confirm tests exist
- Check for `testify` or other test framework imports

### Makefile
Read `Makefile` for targets named `test`, `tests`, `check`, `test-unit`, `test-integration`.

## Canonical Test Command

Determine the single best test command:
1. `make test` (if Makefile has `test` target)
2. `tox` (if `tox.ini` exists — it usually wraps pytest)
3. `pytest` (if pytest is configured)
4. `npm test` / `pnpm test` / `yarn test` (if `package.json` has `scripts.test`)
5. `cargo test` (Rust)
6. `go test ./...` (Go)
7. `nox` (if `noxfile.py` exists)

Also determine the single-test command pattern:
- pytest: `pytest tests/test_foo.py::test_bar -xvs`
- jest: `npx jest --testPathPattern test_foo`
- cargo: `cargo test test_name`
- go: `go test ./pkg/... -run TestName`

## Output

Return:
- Test runner name and version (if detectable)
- Test directory convention
- Canonical test command (run all)
- Single-test command pattern
- Suggested `permissions.allow` entries (e.g. `Bash(pytest *)`, `Bash(cargo test *)`)
- CLAUDE.md `## Testing` section content
