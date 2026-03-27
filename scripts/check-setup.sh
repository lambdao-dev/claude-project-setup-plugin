#!/bin/bash
# Check if project has Claude Code configuration
# Output is added to Claude's context on SessionStart/CwdChanged

if [ -f ".claude/settings.json" ] || [ -f ".claude/CLAUDE.md" ] || [ -f "CLAUDE.md" ]; then
    exit 0
fi

# Output to Claude's context
echo "[project-setup plugin] This project has no Claude Code configuration. Tell the user they can run /project-setup:project-setup to auto-discover tooling (linters, test runners, virtual environments, IDE settings)."
