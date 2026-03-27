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
- `.claude/project-setup.local.md` (plugin config — frontmatter keys: `dir-permission-default`, `runtime-context`)

If `.claude/project-setup.local.md` does not exist, the default directory permission level is `read`
(which includes Glob and Grep for search).

The `runtime-context` key may be `auto` (default), `local`, or `remote`. Store the value as `$CONFIG_RUNTIME_CONTEXT` (default: `auto`). If the value is anything other than `auto`, `local`, or `remote`, warn the user and treat it as `auto`.

## Step 2: Run Detection

Run each detection phase using the corresponding skill. Track all findings in a structured internal summary.

### 2-pre: Runtime Context Detection (run first)

Use the `detect-runtime-context` skill.

- If `$CONFIG_RUNTIME_CONTEXT` is `local` or `remote`: skip the skill. Set `$DETECTED_CONTEXT` to the config value and `$CONTEXT_CONFIDENCE` to `high` (user preference overrides detection).
- Otherwise run the skill. Store the result as:
  - `$DETECTED_CONTEXT` ← `context` field (`local`, `remote`, or `uncertain`)
  - `$CONTEXT_CONFIDENCE` ← `confidence` field (`high` or `low`)
  - `$CONTEXT_SIGNALS` ← `signals` list (for the summary display)
  - `$SSH_ONLY` ← `ssh_only` field (true if remote context is SSH-only with no container signals; may inform environment activation strategy)

### 2a: IDE Settings (run next — feeds hints to other detectors)

Use the `detect-ide-settings` skill. Store all returned hints (venv paths, linter names, test runner, source roots) for use in subsequent phases.

### 2b: Environment Detection

Use the `detect-environment` skill. Pass any venv hints from step 2a as context.

### 2c: Directory Detection

Use the `detect-directories` skill. Pass any source root hints from step 2a as context.

### 2d: Linter Detection

Use the `detect-linters` skill. Pass any linter hints from step 2a as context.

### 2e: Test Runner Detection

Use the `detect-test-runners` skill. Pass any test runner hints from step 2a as context.

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
- `read` (default) → add `Read(path/**)`, `Glob(path/**)`, `Grep(path/**)` to `permissions.allow`
- `read-only` → add `Read(path/**)` only (no search tools)
- `edit` → add `Read(path/**)`, `Glob(path/**)`, `Grep(path/**)`, `Edit(path/**)`, `Write(path/**)`
- `full` → add `Read(path/**)`, `Glob(path/**)`, `Grep(path/**)`, `Edit(path/**)`, `Write(path/**)`, `Bash(*)` scoped to path

**Linter mapping:**
- Add `permissions.allow` entries for lint commands (e.g. `Bash(pre-commit run *)`, `Bash(ruff check *)`)

**Test runner mapping:**
- Add `permissions.allow` entries for test commands (e.g. `Bash(pytest *)`, `Bash(cargo test *)`)

**Default shell permissions:**
- Always add `permissions.allow` entries for common exploration commands needed during normal operation: `Bash(find:*)`, `Bash(ls:*)`, `Bash(wc:*)`, `Bash(head:*)`, `Bash(tail:*)`, `Bash(cat:*)`, `Bash(which:*)`, `Bash(readlink:*)`

### Proposed `.claude/CLAUDE.md` additions

Only append sections whose `##` header does NOT already exist in the current CLAUDE.md. Sections to add:

- `## Environment` — language version, venv location, how to activate
  - If `$DETECTED_CONTEXT` is `remote` (confidence high), append one additional line to the `## Environment` section: `- Context: remote/container environment` (with specifics from `$CONTEXT_SIGNALS` if available, e.g. "GitHub Codespaces", "VS Code Dev Container")
- `## Linting` — canonical lint command, configured linters
- `## Testing` — canonical test command, how to run a single test, test directory

Keep each section to 3-5 lines max. Be concise and actionable.

## Step 4: Present Summary

Show the user a clear summary of what was detected and what will be written:

```
## Detection Results

### Runtime Context
- <$DETECTED_CONTEXT> (<$CONTEXT_CONFIDENCE> confidence)
  Signals: <$CONTEXT_SIGNALS or "none">
  <If uncertain: "Will ask for confirmation before writing.">

### Environment
- Python 3.12.4 via .venv/ (managed by uv)

### Additional Directories
- ../shared-libs/ (read + search access)

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

**If `$DETECTED_CONTEXT` is `uncertain`** (i.e. `$CONTEXT_CONFIDENCE` is `low`) AND `$CONFIG_RUNTIME_CONTEXT` is `auto`:

Before asking general approval, ask the user a dedicated context question using AskUserQuestion:

> I detected possible container/remote signals but couldn't confirm the execution context automatically. Is this project running locally or in a remote environment?
>
> 1. Locally on your workstation
> 2. Inside a container or remote environment (Codespaces, Dev Containers, Gitpod, SSH, etc.)

Map their answer to `$DETECTED_CONTEXT` (`local` or `remote`) and set `$CONTEXT_CONFIDENCE` to `high`. Then proceed to the general approval question below.

**General approval question** (always asked, using AskUserQuestion):

> [Summary shown above.] Apply these changes to .claude/?

Once approved:
1. Create `.claude/` directory if it doesn't exist
2. Write/merge `.claude/settings.json` (read existing → merge → write)
3. Write/append to `.claude/CLAUDE.md` (only new sections)
4. Show what was written

## Step 6: Validate

Run `/project-setup:check` to validate the written configuration.
