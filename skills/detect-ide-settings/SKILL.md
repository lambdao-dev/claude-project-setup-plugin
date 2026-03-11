---
name: detect-ide-settings
description: Read IDE/editor configuration files (VSCode, PyCharm, Vim/Neovim, Emacs) to discover project settings. Used internally by /project-setup.
user-invocable: false
tools: Read, Glob
---

# IDE Settings Detection

Read IDE configuration files to extract hints about virtual environments, linters, test runners, and source directories.

## VSCode

Read `.vscode/settings.json` if it exists. Extract:

| Key | Maps to |
|-----|---------|
| `python.defaultInterpreterPath` | venv path |
| `python.testing.pytestEnabled` | test runner = pytest |
| `python.testing.pytestArgs` | pytest arguments |
| `python.testing.unittestEnabled` | test runner = unittest |
| `python.linting.ruffEnabled` | linter = ruff |
| `python.linting.flake8Enabled` | linter = flake8 |
| `python.linting.mypyEnabled` | linter = mypy |
| `python.linting.pylintEnabled` | linter = pylint |
| `python.envFile` | env file path |
| `eslint.workingDirectories` | JS project roots |
| `editor.defaultFormatter` | formatter hint |

Also check for `*.code-workspace` files in the project root — extract `folders[].path` entries as potential additional directories.

## PyCharm

If `.idea/` directory exists, read:

**`*.iml` files** — look for XML elements:
- `<sourceFolder url="..." isTestSource="false" />` → source root
- `<sourceFolder url="..." isTestSource="true" />` → test source root
- `<excludeFolder url="..." />` → excluded directory
- URLs use `file://$MODULE_DIR$/path` format — strip the prefix

**`misc.xml`** — look for:
- `<component name="ProjectRootManager">` with `project-jdk-name` attribute → SDK name
- `<component name="ProjectRootManager">` with child `<output url="..." />` → output dir
- Python interpreter path from SDK configuration

**`runConfigurations/*.xml`** — look for:
- `<configuration type="tests">` → test framework
- `<configuration type="PythonConfigurationType">` → Python scripts
- Extract working directory, script path, parameters

## Vim / Neovim

Check for project-local configuration that may contain environment or tooling hints:

**Neovim LSP / plugin configs** — check these files if they exist:
- `.nvim.lua`, `.nvimrc`, `.exrc` — project-local Neovim config
- `.neoconf.json` — neoconf.nvim project settings; look for:
  - `lspSettings.pylsp.plugins.*` or `lspSettings.pyright.*` → Python LSP/linter config
  - `lspSettings.rust_analyzer.*` → Rust config
- `.vim/coc-settings.json` — coc.nvim project settings; look for:
  - `python.pythonPath` or `python.venvPath` → venv path
  - `python.linting.*` → linter hints
  - `eslint.*` → JS linter

**pyrightconfig.json** — often created for Vim/Neovim Pyright users:
- `venvPath` + `venv` → venv path
- `include` / `exclude` → source roots and excluded dirs
- `executionEnvironments` → per-directory Python path overrides

**ALE / vim-test markers** — check `.vimrc` or `.exrc` for:
- `let g:ale_linters` → linter configuration
- `let g:ale_fixers` → formatter configuration
- `let g:test#python#runner` → test runner preference

## Emacs

Check for Emacs project configuration:

**`.dir-locals.el`** — Emacs per-directory local variables. Parse s-expressions for:
- `(python-mode . ((python-shell-interpreter . "/path/to/venv/bin/python")))` → venv path
- `(python-mode . ((python-shell-virtualenv-root . "/path/to/venv")))` → venv path
- `(flycheck-python-pylint-executable . "...")` → linter path
- `(flycheck-checker . python-ruff)` → linter hint
- `(eval . (setq ...))` → arbitrary variable settings

**`.projectile`** — Projectile project root marker; if it exists, check for:
- Lines prefixed with `-` → excluded directories
- Lines prefixed with `+` → included directories (potential source roots)

**`Eglot` / `lsp-mode`** — these typically use `pyrightconfig.json` or `pyproject.toml` for config, which are already covered by other detectors.

## Output

Return a structured summary of all IDE hints found, categorized as:
- `venv_hints`: list of potential venv paths
- `linter_hints`: list of detected linters
- `test_hints`: test runner name and arguments
- `source_roots`: additional source directories
- `excluded_paths`: directories to ignore
