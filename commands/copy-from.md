---
description: Copy and adapt .claude/ configuration from another project
argument-hint: "[--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Skill", "AskUserQuestion"]
---

# Copy Project Setup from Another Project

Copy `.claude/` configuration from a source project and adapt it to the current project. Paths, dependencies, and environment references are remapped rather than copied verbatim.

## Step 1: Identify Source Project

If `$ARGUMENTS` does not contain a path (only contains flags like `--dry-run`, or is empty), ask the user for the source project path using AskUserQuestion:

> Which project should I copy the .claude/ configuration from? Provide an absolute or relative path.

Resolve the path to an absolute path. Verify that it exists and contains `.claude/settings.json` or `.claude/CLAUDE.md`. If neither exists, tell the user there is nothing to copy and stop.

## Step 2: Read Source Configuration

Read from the source project:
- `.claude/settings.json`
- `.claude/CLAUDE.md` or `CLAUDE.md`

Also read from the source project to understand its structure (if they exist):
- `pyproject.toml`, `Cargo.toml`, `go.mod`, `package.json`
- `.pre-commit-config.yaml`
- `Makefile`

Record the source project root as `$SOURCE`.

## Step 3: Read Current Project

Read from the current project (if they exist):
- `.claude/settings.json`
- `.claude/settings.local.json`
- `.claude/CLAUDE.md` or `CLAUDE.md`
- `.claude/project-setup.local.md`
- `pyproject.toml`, `Cargo.toml`, `go.mod`, `package.json`
- `.pre-commit-config.yaml`
- `Makefile`

Record the current project root as `$TARGET`.

## Step 4: Run Detection on Current Project

Run the detection skills on the current project to understand its actual tooling:

1. Use the `detect-environment` skill → current venv, language versions
2. Use the `detect-linters` skill → current linters
3. Use the `detect-test-runners` skill → current test runners
4. Use the `detect-directories` skill → current additional directories

## Step 5: Adapt Configuration

Build the adapted configuration by transforming the source settings for the current project. Apply these adaptation rules:

### 5a: Environment (`env`, `hooks`)

- **Virtual environment**: if source has `env.VIRTUAL_ENV`, do NOT copy the source path. Instead use the venv detected in Step 4 for the current project. If no venv was detected, drop the `VIRTUAL_ENV` entry and warn the user.
- **SessionStart hooks**: rewrite any venv PATH export commands to use the current project's venv path. Drop hooks that reference source-specific paths with no local equivalent.
- **Other env vars**: copy as-is unless they contain absolute paths under `$SOURCE` — those must be rewritten to `$TARGET` equivalents.

### 5b: Additional Directories (`permissions.additionalDirectories`)

For each directory in the source config:
1. Determine what the directory **is** (e.g. a dependency checkout, a shared library, a sibling project). Use the directory name and any context from the source project structure.
2. Check if an equivalent directory exists relative to `$TARGET`. For example:
   - Source has `../Dep2` → current project has `../Dep2` at the same relative path → use it
   - Source has `../Dep2` → current project does NOT have `../Dep2` but has `../Dep3` which serves the same role → ask the user whether to substitute
   - Source has `../Dep2` → no equivalent found → warn and skip
3. Only include directories that actually exist on disk.

When the mapping is ambiguous (e.g. the source references a dependency the current project doesn't use, or there are multiple candidates), ask the user using AskUserQuestion to choose the right mapping.

### 5c: Permissions (`permissions.allow`)

For each entry in the source `permissions.allow`:
- **Tool commands** (e.g. `Bash(pytest *)`, `Bash(pre-commit run *)`): keep if the same tool is available in the current project (detected in Step 4). Drop if the tool is not present. Substitute if the current project uses a different equivalent (e.g. source uses `npm run lint`, current project uses `pnpm lint`).
- **Path-based permissions** (e.g. `Read(../Dep2/**)`): rewrite using the directory mapping from Step 5b.
- Entries referencing `permissions.deny` are never modified.

### 5d: CLAUDE.md Content

For each `##` section in the source CLAUDE.md:
- **`## Environment`**: regenerate from Step 4 detection results (do not copy source environment details).
- **`## Linting`**: regenerate from Step 4 detection results if the current project has different linters. If linters match, adapt the section (e.g. replace package manager commands).
- **`## Testing`**: regenerate from Step 4 detection results if the test runner differs. If it matches, adapt paths.
- **Other sections**: copy as-is, but rewrite any absolute paths under `$SOURCE` to `$TARGET` equivalents. Flag sections that reference source-specific tooling not found in the current project.

## Step 6: Merge with Existing

Apply the same merge rules as `/project-setup`:
- `permissions.allow`: union with existing (no duplicates)
- `permissions.deny`: **never modified**
- `permissions.additionalDirectories`: union with existing
- `env`: merge keys; **existing values take precedence**
- All other keys: left untouched

**CRITICAL: NEVER set `PATH` in the `env` object.** Use `SessionStart` hooks to modify PATH.

Only append CLAUDE.md sections whose `##` header does NOT already exist.

## Step 7: Present Summary

Show the user what was copied, what was adapted, and what was dropped:

```
## Copy Results (from /path/to/source)

### Copied as-is
- permissions.allow: Bash(pre-commit run *), Bash(pytest *)

### Adapted
- env.VIRTUAL_ENV: /source/.venv → /target/.venv
- additionalDirectories: ../Dep2 → ../Dep3 (user confirmed)
- SessionStart hook: venv path updated
- permissions.allow: Read(../Dep2/**) → Read(../Dep3/**)

### Dropped
- additionalDirectories: ../source-only-lib (not found near target)

### CLAUDE.md
- ## Environment: regenerated from detection
- ## Linting: copied (same tooling)
- ## Custom Section: copied as-is
```

If `$ARGUMENTS` contains `--dry-run`, stop here.

## Step 8: Write Configuration

Ask the user for approval using AskUserQuestion before writing.

Once approved:
1. Create `.claude/` directory if it doesn't exist
2. Write/merge `.claude/settings.json`
3. Write/append to `.claude/CLAUDE.md`
4. Show what was written

## Step 9: Validate

Run `/project-setup:check` to validate the written configuration.
