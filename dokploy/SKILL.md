---
name: dokploy
description: "Use when deploying, debugging, diagnosing, or managing Docker Compose apps on a Dokploy PaaS instance. Serves as the entry point for the Dokploy skill suite — pick the right sub-skill based on your goal."
version: 1.0.0
author: Hermes Agent
license: MIT
tags: [dokploy, docker, compose, deployment, diagnostics, debugging, management]
slash: /dokploy
preview: "Dokploy skill suite — deploy, debug, diagnose, manage | pick the right tool"
metadata:
  hermes:
    tags: [dokploy, docker-compose, deployment, management, diagnostics]
    related_skills: [dokploy-manage, dokploy-deploy, dokploy-debug, dokploy-code-assisted]
---

# Dokploy Skill Suite

A suite of 4 Hermes skills for managing, deploying, debugging, and diagnosing applications hosted on **Dokploy** — a self-hosted PaaS that manages Docker Compose + Swarm deployments behind Traefik.

**Works on any Dokploy instance. Zero hardcoded values. One-time setup, then full control from your terminal.**

---

## Overview

This suite gives you complete control over a Dokploy server without ever opening the web UI. Pick the right tool:

| Skill | Slash | Use when you need to... |
|---|---|---|
| `dokploy-manage` | `/dokploy-manage` | List apps, inspect state, stop/start/delete, manage domains — **API control plane** |
| `dokploy-deploy` | `/dokploy-deploy` | Deploy a new or updated compose/git app from scratch — **full deployment workflow with rollback** |
| `dokploy-debug` | `/dokploy-debug` | Diagnose a specific error or crash — **error-driven, pattern-matching, 8 diagnostic tracks** |
| `dokploy-diagnose` | `/dokploy-diagnose` | Inspect the app's source code, nginx.conf, Dockerfile, CLAUDE.md — **deep codebase root cause analysis** |

## When to Use

**Use this root skill (`/dokploy`):**
- First time using the suite — complete the one-time setup below
- You're not sure which sub-skill to use and want guidance
- You need the setup guide or cross-skill architecture reference

**Don't use this skill if:**
- You already know you need to deploy → use `/dokploy-deploy` directly
- You have a specific error → use `/dokploy-debug` directly
- You need to inspect/manage apps → use `/dokploy-manage` directly
- You need codebase inspection → use `/dokploy-diagnose` directly

## Getting Started — One-Time Setup

Set these environment variables once. The agent can auto-detect most values.

### 1. DOKPLOY_API_KEY (required)

```bash
export DOKPLOY_API_KEY='your-key-here'
```

**How to get it (2 minutes):**
1. Open your Dokploy dashboard in a browser
2. Go to **Settings → Profile → API/CLI Section**
3. Click **Generate Token** (or use an existing one)
4. Copy the token — it looks like a long random string
5. Paste it in the export command above

### 2. DOKPLOY_URL (optional — auto-detected)

```bash
export DOKPLOY_URL="http://localhost:3000"
```

**What this is:** The base URL of your Dokploy API.

**Takes one of these values:**
- `http://localhost:3000` — Dokploy runs on the same machine (default, works for most users)
- `https://dokploy.yourdomain.com` — if you access Dokploy via a domain
- `http://192.168.1.100:3000` — if Dokploy is on a different server on your network

**Agent auto-detect:**
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null
# If 200 or 401, the local URL works. If not, the agent asks you.
```

### 3. DOKPLOY_TRAEFIK_NAME (optional — auto-detected)

```bash
export DOKPLOY_TRAEFIK_NAME="dokploy-traefik"
```

**Agent auto-detect:**
```bash
docker ps --format '{{.Names}}' | grep -i traefik | head -1
```

### 4. DOKPLOY_COMPOSE_DIR (optional — auto-detected)

```bash
export DOKPLOY_COMPOSE_DIR="/etc/dokploy/compose"
```

**Agent auto-detect:**
```bash
ls /etc/dokploy/compose/ 2>/dev/null
# If the directory is empty or missing, the agent asks you.
```

### Quick Start

```bash
# All you really need:
export DOKPLOY_API_KEY='your-key-here'
# Everything else auto-detects.
```

### Verify

```bash
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/settings.health"
```

## How the Skills Work Together

```
            ┌─────────────────────┐
            │     /dokploy        │
            │  (root entry point) │
            ├─────────────────────┤
            │   Setup guide       │
            │   Pick right tool   │
            └────────┬────────────┘
                     │
     ┌───────────────┼───────────────┐
     │               │               │
     ▼               ▼               ▼
┌─────────┐   ┌──────────┐   ┌──────────┐   ┌──────────────┐
│ manage  │   │  deploy  │   │  debug   │   │   diagnose   │
├─────────┤   ├──────────┤   ├──────────┤   ├──────────────┤
│ API     │   │ Full     │   │ Error →  │   │ Codebase     │
│ control │   │ deploy   │   │ pattern  │   │ inspection   │
│ plane   │   │ workflow │   │ match    │   │              │
│         │   │          │   │    │     │   │      ▲       │
│         │   │          │   │    ▼     │   │      │       │
│         │   │          │   │ deep     │◄──┼──────┘       │
│         │   │          │   │ diagnose │   │ (called by   │
│         │   │          │   │          │   │  debug when  │
│         │   │          │   │          │   │  no pattern) │
└─────────┘   └──────────┘   └──────────┘   └──────────────┘
```

## Proactive Suggestions

Each sub-skill detects context and suggests companions:

| Context | Suggests | Reason |
|---|---|---|
| User wants to deploy | `/dokploy-deploy` | Full deploy workflow with validation |
| App has errors / crashes | `/dokploy-debug` | Pattern-matched diagnostics |
| Config file issues (nginx, compose) | `/dokploy-diagnose` | Codebase-driven root cause |
| Deployment failed | `/dokploy-debug` | Diagnostic follow-up |
| Debug found code-level issue | `/dokploy-diagnose` | Deep codebase inspection |

## Common Pitfalls

- **Don't use `docker compose` directly if Dokploy is tracking the app** — Dokploy won't know about the change. Use the API via `dokploy-manage` or `dokploy-deploy`.
- **Traefik event miss**: After compose deploy, Traefik may miss Docker events. Fix: `docker restart $DOKPLOY_TRAEFIK_NAME`.
- **Cloudflare Flexible SSL**: If your domain is behind Cloudflare, set SSL/TLS mode to **Full** (not Flexible) or Traefik's redirect-to-https creates an infinite loop.
- **Docker bypasses UFW**: Published Docker ports bypass UFW rules. Always add DOCKER-USER iptables rules for ports you want blocked.
- **sshd_config.d ordering**: Drop-in files load lexicographically. `50-cloud-init.conf` wins over `60-cloudimg-settings.conf`. Always check `sshd -T` for the actual running config.

## Verification Checklist

- [ ] `DOKPLOY_API_KEY` is set and verified via `settings.health`
- [ ] `DOKPLOY_URL` resolves and returns 200 or 401
- [ ] `DOKPLOY_TRAEFIK_NAME` container is running (check with `docker ps`)
- [ ] `DOKPLOY_COMPOSE_DIR` directory exists and contains your apps
- [ ] All 4 slash commands available: `/dokploy-manage`, `/dokploy-deploy`, `/dokploy-debug`, `/dokploy-diagnose`
