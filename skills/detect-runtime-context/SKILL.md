---
name: detect-runtime-context
description: Detect whether the project is running locally or in a remote/container environment (GitHub Codespaces, VS Code Dev Containers, Gitpod, SSH, etc.). Used internally by /project-setup.
user-invocable: false
tools: Read, Bash
---

# Runtime Context Detection

Determine whether Claude Code is running locally on a developer workstation or inside a remote/container environment.

## Detection Signals

Run all checks below and collect every signal that fires. Do not stop at the first match — gather all evidence before drawing a conclusion.

### 1. Environment Variables

Run:
```bash
[ "$CODESPACES" = "true" ] && echo "CODESPACES=true" || echo "CODESPACES="
[ "$REMOTE_CONTAINERS" = "true" ] && echo "REMOTE_CONTAINERS=true" || echo "REMOTE_CONTAINERS="
[ -n "$GITPOD_WORKSPACE_ID" ] && echo "GITPOD_WORKSPACE_ID=$GITPOD_WORKSPACE_ID" || echo "GITPOD_WORKSPACE_ID="
[ -n "$VSCODE_REMOTE_CONTAINERS_SESSION" ] && echo "VSCODE_REMOTE_CONTAINERS_SESSION=set" || echo "VSCODE_REMOTE_CONTAINERS_SESSION="
[ -n "$CONTAINER_ID" ] && echo "CONTAINER_ID=set" || echo "CONTAINER_ID="
[ -n "$SSH_CLIENT" ] && echo "SSH_CLIENT=set" || echo "SSH_CLIENT="
[ -n "$SSH_CONNECTION" ] && echo "SSH_CONNECTION=set" || echo "SSH_CONNECTION="
```

Signals:
- `CODESPACES=true` → strong remote signal (GitHub Codespaces)
- `REMOTE_CONTAINERS=true` → strong remote signal (VS Code Dev Containers)
- `GITPOD_WORKSPACE_ID` is non-empty → strong remote signal (Gitpod)
- `VSCODE_REMOTE_CONTAINERS_SESSION` is non-empty → strong remote signal (VS Code Dev Containers)
- `CONTAINER_ID` is non-empty → weak remote signal (generic container)
- `SSH_CLIENT` or `SSH_CONNECTION` is non-empty → remote signal (SSH session); only treat as standalone-SSH if no container signals are present

### 2. Container Marker Files

```bash
test -f /.dockerenv && echo "dockerenv=true" || echo "dockerenv=false"
test -f /run/.containerenv && echo "containerenv=true" || echo "containerenv=false"
```

Signals:
- `/.dockerenv` exists → weak-to-strong remote signal (Docker container). Strength depends on corroborating signals.
- `/run/.containerenv` exists → weak-to-strong remote signal (Podman/OCI container). Strength depends on corroborating signals.

### 3. Filesystem Path

```bash
pwd
```

Signals:
- CWD starts with `/workspaces/` → strong remote signal (GitHub Codespaces convention)
- CWD starts with `/workspace/` → strong remote signal (Gitpod convention)

### 4. Dev Container Config

Check if `.devcontainer/devcontainer.json` exists in the project root:
```bash
test -f .devcontainer/devcontainer.json && echo "devcontainer=true" || echo "devcontainer=false"
```

Signal:
- `.devcontainer/devcontainer.json` exists → this means the project *supports* dev containers, but does not by itself prove we are *inside* one. Only treat this as a corroborating signal, not a standalone signal.

## Confidence Scoring

After collecting all signals, classify the result:

**`remote` with `confidence: high`** — if ANY of the following are true:
- `CODESPACES=true`
- `REMOTE_CONTAINERS=true`
- `GITPOD_WORKSPACE_ID` non-empty
- `VSCODE_REMOTE_CONTAINERS_SESSION` non-empty
- CWD starts with `/workspaces/` or `/workspace/`
- SSH_CLIENT/SSH_CONNECTION set AND no container markers found (pure SSH session)
- Any container marker file exists AND at least one container env var also fires

**`uncertain` with `confidence: low`** — if:
- Container markers exist (/.dockerenv or /run/.containerenv) but NO container env vars are set
- `.devcontainer/devcontainer.json` exists but no container markers and no container env vars

**`local` with `confidence: high`** — if no signals fired at all.

## Output

Return a structured summary:

```
runtime-context:
  context: <local|remote|uncertain>
  confidence: <high|low>
  signals:
    - "<signal description>"
  ssh_only: <true|false>
  notes: "<optional human-readable note>"
```

Example outputs:

```
runtime-context:
  context: remote
  confidence: high
  signals:
    - "CODESPACES=true (GitHub Codespaces)"
    - "CWD is /workspaces/my-project"
  ssh_only: false
  notes: "Running inside GitHub Codespaces."
```

```
runtime-context:
  context: uncertain
  confidence: low
  signals:
    - "/.dockerenv exists (no container env vars to confirm)"
  ssh_only: false
  notes: "Container marker found but no confirming env vars. May be running inside an unrecognized container runtime."
```

```
runtime-context:
  context: local
  confidence: high
  signals: []
  ssh_only: false
  notes: "No remote or container signals detected."
```
