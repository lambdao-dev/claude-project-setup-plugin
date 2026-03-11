#!/usr/bin/env bash
# Dry-run validation for project-setup plugin.
# Verifies plugin structure and catches known bad patterns.
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0

fail() { echo "FAIL: $1"; ERRORS=$((ERRORS + 1)); }
pass() { echo "PASS: $1"; }

# 1. Plugin manifest
if [ -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]; then
    if python3 -m json.tool "$PLUGIN_DIR/.claude-plugin/plugin.json" > /dev/null 2>&1; then
        pass "plugin.json is valid JSON"
    else
        fail "plugin.json is not valid JSON"
    fi
else
    fail ".claude-plugin/plugin.json not found"
fi

# 2. All command files exist and have frontmatter
for cmd in "$PLUGIN_DIR"/commands/*.md; do
    name=$(basename "$cmd")
    if head -1 "$cmd" | grep -q '^---'; then
        pass "command $name has frontmatter"
    else
        fail "command $name missing frontmatter"
    fi
done

# 3. All skill files exist and have frontmatter
for skill_dir in "$PLUGIN_DIR"/skills/*/; do
    skill_file="$skill_dir/SKILL.md"
    name=$(basename "$skill_dir")
    if [ -f "$skill_file" ]; then
        if head -1 "$skill_file" | grep -q '^---'; then
            pass "skill $name has frontmatter"
        else
            fail "skill $name missing frontmatter"
        fi
    else
        fail "skill $name missing SKILL.md"
    fi
done

# 4. Check that skill/command docs never set PATH in env
for f in "$PLUGIN_DIR"/commands/*.md "$PLUGIN_DIR"/skills/*/SKILL.md; do
    # Look for env blocks that set PATH (the broken pattern)
    # Allow mentions in warnings/comments but not in JSON examples that would be copied
    if grep -Pzo '"env"\s*:\s*\{[^}]*"PATH"' "$f" > /dev/null 2>&1; then
        fail "$(basename "$f") contains an env block setting PATH (this breaks bash)"
    else
        pass "$(basename "$f") does not set PATH in env"
    fi
done

# 5. Check package.json
if [ -f "$PLUGIN_DIR/package.json" ]; then
    if python3 -m json.tool "$PLUGIN_DIR/package.json" > /dev/null 2>&1; then
        pass "package.json is valid JSON"
    else
        fail "package.json is not valid JSON"
    fi
else
    fail "package.json not found"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "RESULT: $ERRORS check(s) failed"
    exit 1
else
    echo "RESULT: all checks passed"
fi
