---
name: detect-environment
description: Detect language runtimes, virtual environments, and toolchains (Python, Node, Rust, Go). Used internally by /project-setup.
user-invocable: false
tools: Read, Bash, Glob
---

# Environment Detection

Detect language runtimes and virtual environments in the project.

## Python

Check in order (stop at first confirmed venv):

1. **Standard venv directories**: `.venv/`, `venv/`, `env/` — confirm by checking `bin/python` exists
2. **Poetry**: if `poetry.lock` exists → `poetry env info -p 2>/dev/null`
3. **Pipenv**: if `Pipfile` exists → `pipenv --venv 2>/dev/null`
4. **PDM**: if `pdm.lock` exists → `pdm venv --path in-project 2>/dev/null`
5. **uv**: if `uv.lock` exists → default `.venv/`
6. **IDE hint**: use venv path from IDE detection if available
7. **pyproject.toml**: check for `[tool.poetry]`, `[tool.pdm]`, `[build-system]` to identify package manager even without lock files

Validate the found venv:
```bash
<venv_path>/bin/python --version
```

Record: absolute venv path, Python version string, package manager name.

**Settings mapping:**

**CRITICAL: NEVER set `PATH` in the `env` object.** `env` values are NOT expanded — `${PATH}` or `$PATH` would be passed as literal strings, completely replacing PATH and breaking all shell commands. Only set `VIRTUAL_ENV` in `env`. Use a `SessionStart` hook to prepend the venv bin to PATH.

```json
{
  "env": {
    "VIRTUAL_ENV": "/absolute/path/to/.venv"
  }
}
```

Additionally, add a `SessionStart` hook to activate the venv in the shell:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "export PATH=\"/absolute/path/to/.venv/bin:$PATH\""
          }
        ]
      }
    ]
  }
}
```

**CLAUDE.md section:**
```markdown
## Environment
- Python <version> via <venv_dir>/ (managed by <package_manager>)
- Activate: `source <venv_dir>/bin/activate`
```

## Node/JS

1. Check `package.json` exists
2. Detect package manager by lock file:
   - `pnpm-lock.yaml` → pnpm
   - `yarn.lock` → yarn
   - `bun.lockb` → bun
   - `package-lock.json` or none → npm
3. Check `.nvmrc` or `.node-version` for version pinning
4. Run `node --version 2>/dev/null` to get current version

Record: package manager, node version, version constraint file.

**CLAUDE.md section:**
```markdown
## Environment
- Node <version> (managed by <manager>)
- Install dependencies: `<manager> install`
```

## Rust

1. Check `Cargo.toml` exists → read `[package]` for edition
2. Check `rust-toolchain.toml` or `rust-toolchain` for toolchain spec
3. Run `rustc --version 2>/dev/null`

Record: Rust version, toolchain, edition.

**CLAUDE.md section:**
```markdown
## Environment
- Rust <version> (edition <edition>, toolchain <toolchain>)
- Build: `cargo build`
```

## Go

1. Check `go.mod` exists → extract `module` path and `go` version directive
2. Run `go version 2>/dev/null`

Record: Go version, module path.

**CLAUDE.md section:**
```markdown
## Environment
- Go <version> (module <module_path>)
- Build: `go build ./...`
```
