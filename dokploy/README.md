# Dokploy Skill Suite

A production-grade suite of [Hermes Agent](https://hermes-agent.nousresearch.com/docs) skills for managing, deploying, debugging, and diagnosing applications on [Dokploy](https://dokploy.com) — without ever opening the web UI.

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/user/dokploy-skills)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20windows-lightgrey)]()

---

## What It Does

```
You: "/dokploy-deploy my-app"
Agent: "Found my-app. Validated compose syntax. Deploying via API... Deploy complete. Rollback: cp compose.yml.bak.1715720400 compose.yml && docker compose up -d"
```

- **5 skills** in one suite — pick the right tool for the job
- **Zero hardcoded values** — works on any Dokploy instance, any server
- **One-time setup** — set `DOKPLOY_API_KEY` once, everything else auto-detects
- **Hard safety gates** — never deploys or edits without your permission
- **Rollback on every change** — every destructive action has a documented undo

---

## Install (one command)

### Linux / macOS

```bash
curl -sSL https://raw.githubusercontent.com/m4xx101/dokploy-skills/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/m4xx101/dokploy-skills/main/install.ps1 | iex
```

### From GitHub (Manual)

```bash
git clone https://github.com/m4xx101/dokploy-skills.git
cp -r dokploy-skills/Skills/dokploy ~/.hermes/skills/devops/
```

---

## Quick Start

### 1. Set your API key

Open your Dokploy dashboard → **Settings → Profile → API/CLI Section** → Generate Token, then:

```bash
export DOKPLOY_API_KEY='dp_key_xxxxxxxxxxxxxxxx'
```

That's it. Everything else auto-detects.

### 2. Verify

```
/dokploy
```

The root skill loads, verifies your connection, and shows available commands.

### 3. Use it

```
/dokploy-manage    → List, inspect, start, stop apps
/dokploy-deploy    → Deploy or update an app
/dokploy-debug     → Diagnose crashes, errors, and failures
/dokploy-diagnose  → Deep codebase inspection (nginx.conf, Dockerfile, logs)
```

---

## Skills Overview

| Skill | Slash | When to Use |
|---|---|---|
| [`dokploy`](SKILL.md) | `/dokploy` | First-time setup, suite overview |
| [`dokploy-manage`](manage/SKILL.md) | `/dokploy-manage` | List/inspect/deploy/stop/start/delete — API control plane |
| [`dokploy-deploy`](deploy/SKILL.md) | `/dokploy-deploy` | Full deployment workflow with validation and rollback |
| [`dokploy-debug`](debug/SKILL.md) | `/dokploy-debug` | Error-driven diagnostics, 8 diagnostic tracks |
| [`dokploy-diagnose`](diagnose/SKILL.md) | `/dokploy-diagnose` | Codebase inspection — nginx → Dockerfile → logs |

---

## Architecture

```
                    ┌─────────────────────┐
                    │     /dokploy        │
                    │  (root entry point) │
                    │   Setup guide       │
                    │   Pick right tool   │
                    └────────┬────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌───────────────┐ ┌──────────────┐ ┌──────────────────┐
│ /dokploy-manage │ │/dokploy-deploy│ │/dokploy-debug│ │/dokploy-diagnose │
├─────────────────┤ ├───────────────┤ ├──────────────┤ ├──────────────────┤
│ API control     │ │ Full deploy   │ │ Error →      │ │ Codebase         │
│ plane           │ │ workflow      │ │ pattern match│ │ inspection       │
│ 450 endpoints   │ │ Validate →    │ │      ↓       │ │                  │
│                 │ │ Deploy →      │ │ deep diagnose│◄┼─── called by     │
│                 │ │ Verify →      │ │      ↓       │ │    debug when    │
│                 │ │ Rollback      │ │ fix + save   │ │    no pattern    │
└─────────────────┘ └───────────────┘ └──────────────┘ └──────────────────┘
```

Skills work in harmony — each detects the user's context and proactively suggests companions.

---

## Configuration

All values auto-detect except `DOKPLOY_API_KEY`.

| Variable | Default | How to Find |
|---|---|---|
| `DOKPLOY_API_KEY` | *(required)* | Dokploy Dashboard → Settings → Profile → API/CLI |
| `DOKPLOY_URL` | `http://localhost:3000` | Your Dokploy instance URL |
| `DOKPLOY_TRAEFIK_NAME` | `dokploy-traefik` | `docker ps \| grep traefik` |
| `DOKPLOY_COMPOSE_DIR` | `/etc/dokploy/compose` | `ls /etc/dokploy/compose/` |

---

## Requirements

- **Hermes Agent** (any recent version)
- **Dokploy** running and accessible (local or remote)
- **Docker** running on the target host
- **Dokploy API Key** (generated from your dashboard)

---

## Usage Examples

### Deploy an app

```
/dokploy-deploy my-app
```

The agent:
1. Finds `my-app` in `/etc/dokploy/compose/`
2. Validates `docker-compose.yml` syntax
3. Checks ports, build context, env vars
4. Asks: "Ready to deploy my-app? This may cause downtime."
5. Deploys via API or Docker Compose
6. Verifies container health + Traefik route + HTTP response
7. Prints rollback command

### Diagnose a crash

```
/dokploy-debug my-app is crashing on startup
```

The agent:
1. Extracts the error: "crashing on startup"
2. Checks container exit code → finds 137 (OOM kill)
3. Matches against known patterns
4. Suggests: "Add memory limits to docker-compose.yml"
5. Asks permission to apply, with rollback reference

### List all apps

```
/dokploy-manage list
```

```
Found 4 compose apps:
  cryptex        → running (healthy)    https://cryptex.m4xx.cfd
  portfolio      → running (healthy)    https://portfolio.m4xx.cfd
  hideaway       → running (unhealthy)  https://hideaway.m4xx.cfd
  lobechat       → stopped              (removed)
```

### Full removal

```
/dokploy-manage delete lobechat
```

The agent:
1. Searches compose API for `lobechat`
2. Shows the app details for confirmation
3. Checks for shared networks/volumes
4. Deletes via API (purges DB record + env vars)
5. Cleans up filesystem (`/etc/dokploy/compose/<id>/`, `/etc/dokploy/logs/<id>/`)
6. Removes orphaned Docker network

---

## Safety Guarantees

| Feature | How It Works |
|---|---|
| **Permission gate** | Every destructive action requires explicit user confirmation |
| **Rollback on everything** | Every file edit, deploy, and delete has a documented undo command |
| **Backup before change** | Files are backed up with timestamps before modification |
| **Proactive suggestions** | Skills suggest the right companion skill based on context |
| **No code changes without consent** | The agent reads code to diagnose, never modifies without asking |
| **Self-evolving** | Novel patterns and fixes are saved back into the skills |

---

## File Structure

```
Skills/dokploy/                    ← Clone this repo
├── README.md                      ← This file (human-facing docs)
├── SKILL.md                       ← Root entry point for agents (/dokploy)
├── manage/
│   └── SKILL.md                   ← /dokploy-manage (API control plane)
├── deploy/
│   └── SKILL.md                   ← /dokploy-deploy (deployment workflow)
├── debug/
│   └── SKILL.md                   ← /dokploy-debug (error diagnostics)
└── diagnose/
    └── SKILL.md                   ← /dokploy-diagnose (codebase inspection)

Install to: ~/.hermes/skills/devops/dokploy/
```

---

## Contributing

When you discover a novel root cause or fix:

1. Document it in the **Pattern Matching** table of the relevant skill
2. Use `skill_manage(action='patch', name='dokploy-...', ...)` to add it
3. Write generic patterns — no hardcoded app names or domains
4. Include the exact error log line as the symptom identifier

See [`diagnose/SKILL.md`](diagnose/SKILL.md) for the self-evolution protocol.

---

## License

MIT — see [LICENSE](LICENSE)

## Related

- [Hermes Agent Documentation](https://hermes-agent.nousresearch.com/docs)
- [Dokploy Documentation](https://dokploy.com/docs)
- [Dokploy API Reference](https://dokploy.com/docs/api)
