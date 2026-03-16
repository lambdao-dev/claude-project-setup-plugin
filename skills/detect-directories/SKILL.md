---
name: detect-directories
description: Discover additional source directories outside the project root that should be accessible. Used internally by /project-setup.
user-invocable: false
tools: Read, Bash, Glob
---

# Directory Detection

Find directories outside the project root that should be added to `permissions.additionalDirectories`.

## Detection Sources

### Monorepo Configurations
- `lerna.json` → `packages` array
- `pnpm-workspace.yaml` → `packages` list
- `package.json` → `workspaces` field (array or object with `packages`)
- These typically reference directories within the project, but may include `../` paths

### Git Submodules
```bash
git submodule status 2>/dev/null
```
Submodules inside the project are already accessible. Only flag those outside the project root.

### Cargo Workspaces
- `Cargo.toml` → `[workspace]` section with `members` list
- Check if any member paths resolve outside the project root

### Go Workspaces
- `go.work` → `use` directives listing module directories

### IDE Source Roots
- PyCharm `.iml` `<sourceFolder>` entries from IDE detection
- VSCode `*.code-workspace` `folders[].path` entries

### Symlinks
```bash
find . -maxdepth 2 -type l -not -path './.git/*' 2>/dev/null | head -50
```
Check if any symlinks point outside the project root with `readlink -f`.

## Filtering

Only include directories that:
1. Actually exist on disk
2. Are outside the current project root (resolved to absolute paths)
3. Are not already in `permissions.additionalDirectories`

## Output

Return a list of directory paths (relative to project root, e.g. `../shared-libs/`) with a brief note about how each was discovered (e.g. "from pnpm-workspace.yaml", "git submodule", "PyCharm source root").
