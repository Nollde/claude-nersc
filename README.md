# Claude HPC

Sandboxed [Claude Code](https://docs.anthropic.com/en/docs/claude-code) environment for HPC 
(especially NERSC Perlmutter) and local Docker. Network-restricted via domain whitelist — only approved
services (Anthropic API, GitHub, PyPI, HEP data sources, etc.) are reachable.
Inspired by Claude Code's [Development Containers](https://code.claude.com/docs/en/devcontainer).

## How it works

Two containers run side by side:

| Container | Purpose |
|-----------|---------|
| **claude-hpc** | Claude Code + conda + dev tools (git, gh, fzf, delta, vim, nano) |
| **claude-hpc-proxy** | Squid forward proxy with domain whitelist |

On **local Docker**, the agent container uses iptables for network restriction (no proxy needed).
On **Perlmutter**, iptables is unavailable (rootless Podman), so traffic is routed through the
Squid proxy via `http_proxy`/`https_proxy` environment variables.

```
┌─────────────────────────────┐     ┌──────────────────────┐
│  claude-hpc (agent)         │     │  claude-hpc-proxy    │
│                             │     │                      │
│  Claude Code ──► http_proxy ──────►  Squid ──► internet  │
│                             │     │  (whitelist only)    │
│  /workspace (your code)     │     │                      │
└─────────────────────────────┘     └──────────────────────┘
```

### Security model

| Layer | Local Docker | Perlmutter (podman-hpc) |
|-------|-------------|------------------------|
| Network | iptables firewall (kernel-level) | Squid proxy (application-level) |
| Filesystem | Container isolation | Container isolation (only mounted volumes visible) |
| User | `researcher` (non-root, no sudo) | `researcher` (UID 1000) via `--userns=keep-id` — unprivileged inside and outside |
| Firewall tampering | Not possible — `researcher` cannot modify iptables (no `NET_ADMIN` capability, no sudo) | `readonly` env vars prevent `unset`; Claude Code respects proxy settings |

## Quick start

### Perlmutter (one command)

```bash
claude-hpc -A <your_account>
```

This allocates a compute node, starts the proxy, and drops you into the agent container
with Claude Code ready to use.

### Local Docker

```bash
docker run -it --rm \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v $(pwd):/workspace \
  nollde24/claude-hpc:latest
```

## Installation

### Perlmutter

**1. Install the launcher** (one-time):

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/Nollde/claude-hpc/main/bin/claude-hpc \
  -o ~/.local/bin/claude-hpc
chmod +x ~/.local/bin/claude-hpc
```

**2. Pull the images** (one-time, repeat after new releases):

```bash
podman-hpc pull docker.io/nollde24/claude-hpc:latest
podman-hpc pull docker.io/nollde24/claude-hpc-proxy:latest
```

**3. Set up Claude Code** (one-time per workspace):

You need an Anthropic API key or Claude Code subscription. On first run, `claude` will
prompt you to authenticate. Your Claude configuration (`._claude/` and `._claude.json`)
is automatically persisted in the mounted workspace directory, so it survives container
restarts — but is specific to each workspace.

**4. Launch**:

```bash
claude-hpc -A <your_account>
```

#### Launcher options

```
claude-hpc -A <account> [options]

  -A, --account ACCOUNT   NERSC account/project (required)
  -t, --time TIME         Time limit (default: 1:00:00)
  -C, --constraint TYPE   Node type: cpu or gpu (default: cpu)
  -g, --gpus N            Number of GPUs (implies --constraint gpu)
  -w, --workspace DIR     Workspace directory to mount (default: current dir)
      --agent-image IMG   Override agent image
      --proxy-image IMG   Override proxy image
```

#### Examples

```bash
# Basic CPU session
claude-hpc -A <your_account>

# 2-hour GPU session
claude-hpc -A <your_account> -t 2:00:00 -g 1

# Mount a specific project
claude-hpc -A <your_account> -w ~/my-project
```

### Local Docker

```bash
docker pull nollde24/claude-hpc:latest
```

Or use the VS Code Dev Container (see below).

## Using as a base image

Build project-specific images on top of the agent:

```dockerfile
FROM nollde24/claude-hpc:latest

# Project dependencies
COPY environment.yml /tmp/environment.yml
RUN conda env update -n base -f /tmp/environment.yml

# Project code
COPY . /workspace
```

On Perlmutter, build and use your custom image:

```bash
podman-hpc build -t my-project:latest .
claude-hpc -A <your_account> --agent-image my-project:latest
```

## VS Code integration

### Local (Dev Container)

This repo includes a `.devcontainer/devcontainer.json`, based on the
[official Claude Code Dev Container](https://github.com/anthropics/claude-code/tree/main/.devcontainer).
Open the repo in VS Code and select **Reopen in Container** — the iptables firewall
is set up automatically.

### Perlmutter (Remote attach)

1. Connect to Perlmutter via **Remote-SSH** in VS Code
2. Start a session: `claude-hpc -A <your_account>`
3. In a second terminal, find the container: `podman-hpc ps`
4. In VS Code, open the command palette and select **Dev Containers: Attach to Running Container**
5. Select the `claude-hpc` container

## Domain whitelist

The following domains are allowed. All other outbound traffic is blocked.

| Category | Domains |
|----------|---------|
| AI / Agent | `*.anthropic.com`, `*.claude.com`, `*.sentry.io`, `*.statsig.com` |
| GitHub | `*.github.com`, `*.githubusercontent.com` |
| Package managers | `*.npmjs.org`, `*.pypi.org`, `*.pythonhosted.org`, `*.anaconda.com`, `*.anaconda.org`, `*.pytorch.org` |
| VS Code | `*.visualstudio.com`, `*.windows.net`, `*.vscode-cdn.net` |
| Physics / HEP | `*.arxiv.org`, `*.inspirehep.net`, `*.hepdata.net`, `*.zenodo.org`, `*.cern.ch`, `*.harvard.edu`, `*.sdss.org`, `*.scikit-hep.org`, `root.cern` |
| Scientific Python | `*.scipy.org`, `*.numpy.org`, `*.matplotlib.org` |
| Data / Storage | `*.doi.org`, `*.docker.io`, `*.docker.com`, `*.huggingface.co`, `*.googleapis.com`, `*.amazonaws.com` |

To add or remove domains, edit the single source of truth:
- `shared/allowed-domains.conf` — used by both iptables (local Docker) and Squid (Perlmutter)

## CI/CD

Images are built and pushed to Docker Hub automatically when a version tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers GitHub Actions to build `linux/amd64` images and push:
- `nollde24/claude-hpc:latest` + `nollde24/claude-hpc:<version>`
- `nollde24/claude-hpc-proxy:latest` + `nollde24/claude-hpc-proxy:<version>`

### Setup (one-time)

Add these secrets to your GitHub repository:
- `DOCKERHUB_USERNAME` — your Docker Hub username
- `DOCKERHUB_TOKEN` — a Docker Hub access token

## Manual build

```bash
# Agent (context = repo root)
docker build --platform linux/amd64 -t nollde24/claude-hpc:latest -f agent/Dockerfile .
docker push nollde24/claude-hpc:latest

# Proxy (context = repo root)
docker build --platform linux/amd64 -t nollde24/claude-hpc-proxy:latest -f proxy/Dockerfile .
docker push nollde24/claude-hpc-proxy:latest
```

## License

MIT
