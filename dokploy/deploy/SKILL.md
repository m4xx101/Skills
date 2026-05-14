---
name: dokploy-deploy
description: "Use when you need to deploy a new or updated Docker Compose or git-based application on Dokploy. Full deployment workflow — discover, validate, ask, backup, deploy via API or CLI, verify, report with rollback. Covers compose creation, build configuration, environment variables, domains, and CI/CD webhooks."
version: 1.0.0
author: Hermes Agent
license: MIT
tags: [dokploy, deployment, ci-cd, compose, application, build, docker, webhooks, rollback]
slash: /dokploy-deploy
preview: "Deploy new apps to Dokploy: create, configure, build, deploy, monitor"
metadata:
  hermes:
    tags: [dokploy, deployment, compose, ci-cd]
    related_skills: [dokploy, dokploy-manage, dokploy-debug, dokploy-code-assisted]
---

# dokploy-deploy

Create, configure, and deploy applications through **Dokploy** — a self-hosted PaaS. This skill covers the complete deployment lifecycle: from creating a new app (compose or git-based) through configuring builds, managing environment variables, triggering deployments, monitoring build output, and rolling back.

**CRITICAL RULE:** Never execute without user permission. Every step: present → confirm → execute → verify.

**Related skills:** `dokploy-manage` (general API management), `dokploy-application-management` (inspect/remove/harden), `dokploy-code-assisted` (diagnose failing apps).

---

## When to Use

**Use this skill when:**
- You need to deploy a new or updated compose/git application from start to finish
- You want validation before deployment (compose syntax, ports, build context)
- You need a structured deploy → verify → rollback workflow
- You're setting up CI/CD with webhooks, domains, and environment variables

**Don't use this skill if:**
- You just want to stop/start/restart an existing app → use `/dokploy-manage`
- You're debugging a deployment failure → use `/dokploy-debug`
- You need to inspect the app's source code for root cause → use `/dokploy-diagnose`
- You've never set up the suite → use `/dokploy` for the one-time setup guide

## Configuration

All configuration is documented in the `/dokploy` root skill. Run `skill_view(name='dokploy')` and read **Getting Started — One-Time Setup**. All values auto-detect except `DOKPLOY_API_KEY`.

You only need:

```bash
export DOKPLOY_API_KEY='your-key-here'
```

### Auth Header Pattern

All API calls use:
```bash
curl -s -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" <endpoint>
```

---

## Quick Reference: IDs You Need Before Deploying

| ID | How to Get | Used For |
|---|---|---|
| `projectId` | `curl -s ... "$DOKPLOY_URL/api/project.all"` | Creating apps (required) |
| `environmentId` | `curl -s ... "$DOKPLOY_URL/api/environment.byProjectId?projectId=<id>"` | Creating apps (optional) |
| `serverId` | `curl -s ... "$DOKPLOY_URL/api/server.all"` | Multi-server setups |
| `registryId` | `curl -s ... "$DOKPLOY_URL/api/registry.all"` | Private Docker registries |
| `composeId` | Returned by `/api/compose.create` | All compose operations |
| `applicationId` | Returned by `/api/application.create` | All git-based app operations |

---

## SECTION 1: Project & Environment Setup

Before deploying, you need a project and optionally an environment.

### 1.1 List Existing Projects

```bash
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/project.all"
```

Response format:
```json
[
  {
    "projectId": "abc123...",
    "name": "my-project",
    "description": "...",
    "createdAt": "2024-...",
    "adminId": "..."
  }
]
```

### 1.2 Create a New Project

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "my-project", "description": "My project description", "env": "production"}' \
  "$DOKPLOY_URL/api/project.create"
```

Parameters:
- `name` (required): Project name
- `description` (optional): Human-readable description
- `env` (optional): Environment label (e.g., "production", "staging")

### 1.3 Create an Environment

Projects can have multiple environments (production, staging, development).

```bash
# List environments in a project
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/environment.byProjectId?projectId=<projectId>"

# Create a new environment
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "staging", "projectId": "<projectId>"}' \
  "$DOKPLOY_URL/api/environment.create"

# Duplicate an existing environment (clone env vars, settings)
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"environmentId": "<sourceEnvId>", "name": "production"}' \
  "$DOKPLOY_URL/api/environment.duplicate"
```

---

## SECTION 2: Create Compose-Based Apps

Compose apps use a `docker-compose.yml` file as the source of truth. Dokploy manages the project lifecycle (start, stop, deploy, logs).

### 2.1 Create a Compose App

**⚠️ HARD GATE:** Before creating: 1. Present the compose file content to the user 2. Show the project/environment it will be created in 3. Wait for explicit confirmation 4. Execute 5. Verify

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "projectId": "<projectId>",
    "environmentId": "<environmentId>",
    "name": "my-app",
    "description": "My Docker Compose application",
    "domain": {
      "host": "myapp.example.com",
      "certificateType": "letsencrypt",
      "https": true
    },
    "composeFile": "services:\n  web:\n    image: nginx:alpine\n    ports:\n      - \"80:80\"\n",
    "composeType": "docker-compose",
    "sourceType": "raw"
  }' "$DOKPLOY_URL/api/compose.create"
```

**Key Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `projectId` | string | Yes | Project to create the app in |
| `name` | string | Yes | App name (used as Docker Compose project name) |
| `description` | string | No | Description |
| `composeFile` | string | Yes | Full docker-compose.yml content (escaped JSON string) |
| `composeType` | string | Yes | `"docker-compose"` (default) |
| `sourceType` | string | Yes | `"raw"` for raw compose input, or for git-based compose |
| `environmentId` | string | No | Environment to associate |
| `domain` | object | No | Pre-configure domain (see Section 4) |

### 2.2 Create Compose App from Git Repository

For compose apps sourced from a git repository (auto-pulled on deploy):

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "projectId": "<projectId>",
    "name": "my-app",
    "description": "Git-sourced compose app",
    "composeFile": "services:\n  web:\n    build: .\n    ports:\n      - \"3000:3000\"\n",
    "composeType": "docker-compose",
    "sourceType": "git",
    "repository": "https://github.com/user/repo.git",
    "branch": "main",
    "autoDeploy": true,
    "customGitUrl": false
  }' "$DOKPLOY_URL/api/compose.create"
```

Additional parameters for git source:
- `repository`: Git clone URL
- `branch`: Branch to deploy (default: main)
- `autoDeploy`: Enable auto-deploy on push (webhook)
- `customGitUrl`: Set true for self-hosted git servers

### 2.3 Update Compose App Config

After creation, update configuration without redeploying:

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "composeId": "<composeId>",
    "name": "updated-name",
    "description": "Updated description",
    "composeFile": "services:\n  web:\n    ...\n"
  }' "$DOKPLOY_URL/api/compose.update"
```

### 2.4 Move Compose App to Different Project/Environment

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "composeId": "<composeId>",
    "projectId": "<newProjectId>",
    "environmentId": "<newEnvironmentId>"
  }' "$DOKPLOY_URL/api/compose.move"
```

---

## SECTION 3: Create Git-Based Applications

Git-based applications are built from source code (Dockerfile, Nixpacks, or buildpacks) rather than raw compose files.

### 3.1 Create a Git-Based Application

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "projectId": "<projectId>",
    "environmentId": "<environmentId>",
    "name": "my-web-app",
    "description": "My web application",
    "repository": "https://github.com/user/repo.git",
    "branch": "main",
    "buildType": "dockerfile",
    "autoDeploy": true,
    "customGitUrl": false,
    "private": false
  }' "$DOKPLOY_URL/api/application.create"
```

### 3.2 Build Types

Dokploy supports three build methods:

**Dockerfile** (`buildType: "dockerfile"`):
```bash
# Uses the Dockerfile in the repository root
# Optional: set Dockerfile path and build context
"dockerfilePath": "Dockerfile",
"buildContext": "."
```

**Nixpacks** (`buildType: "nixpacks"`):
```bash
# Automatic build detection (Node.js, Python, Go, Rust, etc.)
# No config needed — Nixpacks auto-detects the runtime
"buildType": "nixpacks"
```

**Heroku Buildpacks** (`buildType: "heroku_buildpacks"`):
```bash
# For apps that already use Heroku buildpacks
"buildType": "heroku_buildpacks"
```

### 3.3 Private Repositories

For private repos, you must first add an SSH key or use a deploy token:

```bash
# List SSH keys
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/sshKey.all"

# Create SSH key
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "github-deploy-key", "publicKey": "ssh-ed25519 AAAA...", "privateKey": "-----BEGIN OPENSSH PRIVATE KEY-----\n..."}' \
  "$DOKPLOY_URL/api/sshKey.create"

# Or generate a new key pair
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "github-deploy-key"}' "$DOKPLOY_URL/api/sshKey.generate"
```

Then reference the SSH key when creating:
```bash
"customGitUrl": true,
"sshKeyId": "<sshKeyId>"
```

### 3.4 Application Port Configuration

For git-based apps, configure which port the application listens on:

```bash
# Include in application.create
"ports": [
  {
    "port": 3000,
    "protocol": "http"
  }
]
```

### 3.5 Update Application Config

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "applicationId": "<applicationId>",
    "name": "updated-name",
    "description": "Updated",
    "buildType": "nixpacks",
    "branch": "develop"
  }' "$DOKPLOY_URL/api/application.update"
```

---

## SECTION 4: Deploy & Build Management

### 4.1 Trigger Deployment

**Compose app:**
```bash
# Deploy (pull images / git clone + docker compose up)
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.deploy"

# Redeploy (force rebuild — kills existing, restarts)
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.redeploy"
```

**Git-based app:**
```bash
# Deploy (clone/pull repo, build, start)
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<applicationId>"}' "$DOKPLOY_URL/api/application.deploy"

# Redeploy (force rebuild)
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<applicationId>"}' "$DOKPLOY_URL/api/application.redeploy"
```

### 4.2 Start / Stop

```bash
# Compose
curl -s -X POST ... -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.start"
curl -s -X POST ... -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.stop"

# Application
curl -s -X POST ... -d '{"applicationId": "<applicationId>"}' "$DOKPLOY_URL/api/application.start"
curl -s -X POST ... -d '{"applicationId": "<applicationId>"}' "$DOKPLOY_URL/api/application.stop"
```

### 4.3 Cancel / Kill Deployments

```bash
# Cancel a queued or in-progress deployment
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.cancelDeployment"

# Kill a running build process immediately
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.killBuild"

# Kill app build
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<applicationId>"}' "$DOKPLOY_URL/api/application.killBuild"

# Clean entire deployment queue
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{}' "$DOKPLOY_URL/api/compose.cleanQueues"
```

### 4.4 Deploy from a Specific Commit (Git-based)

For git-based apps, push to the configured branch and trigger a deploy — Dokploy pulls the latest commit. Alternatively, update the branch before deploying:

```bash
# Switch branch, then deploy
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<id>", "branch": "v2.1.0"}' "$DOKPLOY_URL/api/application.update"
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<id>"}' "$DOKPLOY_URL/api/application.deploy"
```

---

## SECTION 5: Domain & HTTPS Setup

### 5.1 Add a Domain During App Creation

Include the domain block in `compose.create` or `application.create`:

```bash
"domain": {
  "host": "myapp.example.com",
  "certificateType": "letsencrypt",
  "https": true,
  "serviceName": "web",           # For compose: which service
  "port": null,                    # Override port (null = default)
  "stripPath": false               # Preserve path prefix
}
```

### 5.2 Add Domain After Creation

**For compose apps:**
```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "host": "myapp.example.com",
    "composeId": "<composeId>",
    "serviceName": "web",
    "domainType": "compose",
    "certificateType": "letsencrypt",
    "https": true,
    "port": null,
    "path": null
  }' "$DOKPLOY_URL/api/domain.create"
```

**For git-based apps:**
```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "host": "myapp.example.com",
    "applicationId": "<applicationId>",
    "domainType": "application",
    "certificateType": "letsencrypt",
    "https": true
  }' "$DOKPLOY_URL/api/domain.create"
```

### Certificate Types

| Value | Description |
|---|---|
| `"letsencrypt"` | Auto-provision with Let's Encrypt (default, recommended) |
| `"none"` | No SSL certificate (HTTP only) |
| `"custom"` | Bring your own certificate |

### 5.3 Auto-Generate Development Domain (traefik.me)

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "composeId": "<composeId>",
    "serviceName": "web",
    "domainType": "compose",
    "certificateType": "none",
    "https": false
  }' "$DOKPLOY_URL/api/domain.generateDomain"
```

This creates a `<app-name>.<vps-ip>.traefik.me` domain for development/testing without a real domain.

### 5.4 Update / Delete Domains

```bash
# Update domain config
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"domainId": "<domainId>", "host": "new-domain.com"}' \
  "$DOKPLOY_URL/api/domain.update"

# Delete domain
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"domainId": "<domainId>"}' "$DOKPLOY_URL/api/domain.delete"
```

### 5.5 Check traefik.me Availability

```bash
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/domain.canGenerateTraefikMeDomains"
```

---

## SECTION 6: Environment Variables & Secrets

### 6.1 Save Environment Variables for Compose App

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "composeId": "<composeId>",
    "environment": [
      {"key": "DATABASE_URL", "value": "postgres://user:pass@host:5432/db"},
      {"key": "API_KEY", "value": "sk-...", "secret": true},
      {"key": "NODE_ENV", "value": "production"}
    ]
  }' "$DOKPLOY_URL/api/compose.saveEnvironment"
```

Notes:
- Set `"secret": true` for sensitive values (they're encrypted in the DB and masked in the UI)
- Environment variables are **injected at deploy time**, not runtime
- After changing env vars, you must redeploy for changes to take effect

### 6.2 Save Environment Variables for Git-Based App

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "applicationId": "<applicationId>",
    "environment": [
      {"key": "NODE_ENV", "value": "production"},
      {"key": "PORT", "value": "3000"}
    ]
  }' "$DOKPLOY_URL/api/application.saveEnvironment"
```

### 6.3 Read Environment Variables

Environment variables are returned when fetching app details:

```bash
# Compose app detail includes env array
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.one?composeId=<composeId>" | jq '.environment'

# Application detail
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/application.one?applicationId=<applicationId>" | jq '.environment'
```

> **Note:** Secret values may be masked in API responses. If you need to update a secret, re-submit the full environment array with the new value.

---

## SECTION 7: Deployment Monitoring & Logs

### 7.1 View Deployment History

```bash
# Deployments for a compose app
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/deployment.allByCompose?composeId=<composeId>"

# Deployments for a git-based app
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/deployment.all?applicationId=<applicationId>"

# View queued deployments
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/deployment.queueList"
```

### 7.2 Check Deployment Status via Docker

After triggering a deploy, you can poll the container status:

```bash
# Watch compose app containers come up
docker ps --filter "name=<project-name>" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check the build/deploy logs on disk
ls /etc/dokploy/logs/<project-id>/ 2>/dev/null
tail -50 /etc/dokploy/logs/<project-id>/*.log 2>/dev/null

# Quick health check against the app
curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/health 2>/dev/null
curl -s -o /dev/null -w "%{http_code}" https://<domain>/ 2>/dev/null
```

### 7.3 Build Log Access

Dokploy stores deployment logs on disk at:
```bash
/etc/dokploy/logs/<project-id>/
```

Check these for build failures:
```bash
ls -la /etc/dokploy/logs/<project-id>/
cat /etc/dokploy/logs/<project-id>/<latest-log>.log
```

### 7.4 Poll Deploy Completion

After triggering a deploy, repeat this until containers are healthy:

```bash
# Step 1: Check if containers exist
docker ps -a --filter "name=<project-name>" --format "{{.Names}} {{.Status}}"

# Step 2: Check health (if healthcheck configured)
docker inspect <container-name> --format '{{json .State.Health.Status}}' 2>/dev/null

# Step 3: Check routing (via Traefik)
docker exec $DOKPLOY_TRAEFIK_NAME wget -qO- http://localhost:8080/api/http/routers 2>/dev/null | jq -r '.[] | select(.name | test("<app-name>")) | "\(.name) → \(.rule)"'

# Step 4: Test from CLI
curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/ 2>/dev/null
```

---

## SECTION 8: Rollback & Recovery

### 8.1 Rollback a Compose App Deployment

```bash
# List rollback points
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/rollback.byComposeId?composeId=<composeId>"

# Execute rollback to a specific deployment
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"rollbackId": "<rollbackId>"}' "$DOKPLOY_URL/api/rollback.rollback"

# Delete a rollback point (cleanup old rollbacks)
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"rollbackId": "<rollbackId>"}' "$DOKPLOY_URL/api/rollback.delete"
```

### 8.2 Manual Rollback (Docker Level)

If the API rollback isn't available, manually revert:

```bash
# 1. Re-deploy from last known good compose file
docker compose -f $DOKPLOY_COMPOSE_DIR/<project>/code/docker-compose.yml up -d

# 2. If the compose file was updated, restore from backup
# Check if there's a backup in the project directory
ls $DOKPLOY_COMPOSE_DIR/<project>/code/*.backup*

# 3. Restart Traefik to pick up the running container
docker restart $DOKPLOY_TRAEFIK_NAME
```

### 8.3 Revert Git-Based App to Previous Commit

```bash
# Switch to the tag or commit that was working
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<applicationId>", "branch": "<tag-or-commit>"}' \
  "$DOKPLOY_URL/api/application.update"

# Then deploy
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<applicationId>"}' "$DOKPLOY_URL/api/application.deploy"
```

### 8.4 Rollback Quick Reference

| Situation | Action | Command |
|---|---|---|
| Deploy failed, old containers still running | No action needed — Dokploy doesn't stop old containers until new ones are healthy | Just fix and redeploy |
| Deploy succeeded but app broken | Rollback via API or redeploy previous version | See 8.1 / 8.3 |
| Env vars wrong | Update env vars and redeploy | See Section 6 + Section 4 |
| Domain wrong | Update domain and restart Traefik | See 5.4 + `docker restart $DOKPLOY_TRAEFIK_NAME` |

---

## SECTION 9: CI/CD & Webhooks

### 9.1 Enable Auto-Deploy on Git Push

When creating an app, set `autoDeploy: true`. Dokploy automatically creates a webhook URL:

```bash
# Find the webhook URL from the app details
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.one?composeId=<composeId>" | jq '.webhookToken // empty'

# Or for applications
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/application.one?applicationId=<id>" | jq '.webhookToken // empty'
```

The webhook URL format is:
```
https://<dokploy-domain>/api/deploy/<webhookToken>
```

### 9.2 Configure Git Provider Webhooks

**GitHub:**
```bash
gh api repos/:owner/:repo/hooks \
  --input - <<'EOF'
{
  "name": "web",
  "active": true,
  "events": ["push"],
  "config": {
    "url": "https://<dokploy-domain>/api/deploy/<webhookToken>",
    "content_type": "json",
    "insecure_ssl": "0"
  }
}
EOF
```

**GitLab:**
```
Settings → Webhooks → Add webhook
URL: https://<dokploy-domain>/api/deploy/<webhookToken>
Trigger: Push events
```

**Manual curl:**
```bash
curl -s -X POST "https://<dokploy-domain>/api/deploy/<webhookToken>" \
  -H "Content-Type: application/json" \
  -d '{"ref": "refs/heads/main"}'
```

### 9.3 Notification Channels for Deploy Status

Set up notifications to get deploy status in your chat:

```bash
# List existing notifications
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/notification.all"

# Create Discord notification
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "deploy-alerts", "channelType": "discord", "webhookUrl": "https://discord.com/api/webhooks/..."}' \
  "$DOKPLOY_URL/api/notification.create"

# Create Slack notification
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "slack-deploy", "channelType": "slack", "webhookUrl": "https://hooks.slack.com/services/..."}' \
  "$DOKPLOY_URL/api/notification.create"

# Create Telegram notification
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "telegram-deploy", "channelType": "telegram", "webhookUrl": "https://api.telegram.org/...", "chatId": "-100..."}' \
  "$DOKPLOY_URL/api/notification.create"

# Test notification
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"notificationId": "<notificationId>"}' "$DOKPLOY_URL/api/notification.testConnection"
```

---

## SECTION 10: Resource Configuration

### 10.1 Configure Resource Limits (Compose)

Set CPU/memory limits for services in the docker-compose.yml:

```yaml
services:
  web:
    image: nginx:alpine
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

These compose-level limits are honored by Dokploy when deploying.

### 10.2 Configure Resource Limits (Git-Based Apps)

For git-based apps, limits are set at the API level:

```bash
# Include in application.create or application.update
"memoryReservation": 256,    # MB
"memoryLimit": 512,          # MB
"cpuReservation": 0.25,      # vCPU
"cpuLimit": 0.5              # vCPU
```

---

## SECTION 11: Database & Service Dependencies

Dokploy can create and manage database instances alongside your apps.

### 11.1 Create Database Instances

```bash
# PostgreSQL
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "projectId": "<projectId>",
    "environmentId": "<environmentId>",
    "name": "my-postgres",
    "appName": "my-app-db",
    "databaseName": "myapp",
    "databaseUser": "myapp",
    "databasePassword": "<generate-password>",
    "dockerImage": "postgres:16-alpine",
    "memoryReservation": 256,
    "memoryLimit": 512
  }' "$DOKPLOY_URL/api/postgres.create"

# MySQL
curl -s -X POST ... "$DOKPLOY_URL/api/mysql.create"

# MariaDB
curl -s -X POST ... "$DOKPLOY_URL/api/mariadb.create"

# MongoDB
curl -s -X POST ... "$DOKPLOY_URL/api/mongo.create"

# Redis
curl -s -X POST ... "$DOKPLOY_URL/api/redis.create"
```

### 11.2 Reference Database from App

Once a database is deployed, you can access it via Docker internal networking:

```
Host: <db-app-name>
Port: <db-internal-port> (5432 for postgres, 3306 for mysql, 6379 for redis)
```

Set these as environment variables in your app (Section 6).

### 11.3 Deploy Database

```bash
# Deploy Postgres
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"postgresId": "<postgresId>"}' "$DOKPLOY_URL/api/postgres.deploy"
```

---

## SECTION 12: Complete Deployment Workflow Examples

### 12.1 Deploy a Simple Web App (Compose)

Complete workflow:

```bash
# 1. Find or create project
PROJECT_ID=$(curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/project.all" | jq -r '.[0].projectId')

# 2. Create compose app
COMPOSE_RESPONSE=$(curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d "{
    \"projectId\": \"$PROJECT_ID\",
    \"name\": \"my-web-app\",
    \"description\": \"My web application\",
    \"composeFile\": \"services:\\n  web:\\n    image: nginx:alpine\\n    ports:\\n      - \\\"80:80\\\"\\n\",
    \"composeType\": \"docker-compose\",
    \"sourceType\": \"raw\"
  }" "$DOKPLOY_URL/api/compose.create")

COMPOSE_ID=$(echo "$COMPOSE_RESPONSE" | jq -r '.composeId')
echo "Created compose app: $COMPOSE_ID"

# 3. Add domain
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d "{
    \"host\": \"myapp.example.com\",
    \"composeId\": \"$COMPOSE_ID\",
    \"serviceName\": \"web\",
    \"domainType\": \"compose\",
    \"certificateType\": \"letsencrypt\",
    \"https\": true
  }" "$DOKPLOY_URL/api/domain.create"

# 4. Set env vars
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d "{
    \"composeId\": \"$COMPOSE_ID\",
    \"environment\": [
      {\"key\": \"NODE_ENV\", \"value\": \"production\"}
    ]
  }" "$DOKPLOY_URL/api/compose.saveEnvironment"

# 5. Deploy
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d "{\"composeId\": \"$COMPOSE_ID\"}" "$DOKPLOY_URL/api/compose.deploy"

# 6. Verify
docker ps --filter "name=my-web-app" --format "table {{.Names}}\t{{.Status}}"
curl -s -o /dev/null -w "%{http_code}" https://myapp.example.com/
```

### 12.2 Deploy a Git-Based App with Database

```bash
# 1. Create project if needed
PROJECT_ID=$(curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/project.all" | jq -r '.[0].projectId')

# 2. Create the application
APP_RESPONSE=$(curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d "{
    \"projectId\": \"$PROJECT_ID\",
    \"name\": \"my-api\",
    \"repository\": \"https://github.com/user/my-api.git\",
    \"branch\": \"main\",
    \"buildType\": \"nixpacks\",
    \"autoDeploy\": true
  }" "$DOKPLOY_URL/api/application.create")

APP_ID=$(echo "$APP_RESPONSE" | jq -r '.applicationId')

# 3. Deploy the app
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d "{\"applicationId\": \"$APP_ID\"}" "$DOKPLOY_URL/api/application.deploy"

# 4. Wait and check status
sleep 10
docker ps --filter "name=my-api" --format "table {{.Names}}\t{{.Status}}"
```

---

## SECTION 13: SSO & Registry Integration

### 13.1 Private Docker Registry

If using private Docker images:

```bash
# List registries
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/registry.all"

# Add registry
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "name": "docker-hub",
    "registryType": "dockerhub",
    "username": "myuser",
    "password": "mypassword",
    "registryUrl": ""
  }' "$DOKPLOY_URL/api/registry.create"

# Test registry credentials
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"registryId": "<registryId>"}' "$DOKPLOY_URL/api/registry.testRegistry"

# Remove registry
curl -s -X POST ... -d '{"registryId": "<registryId>"}' "$DOKPLOY_URL/api/registry.remove"
```

Registry types: `dockerhub`, `gitlab`, `github`, `self-hosted`

### 13.2 SSO Providers

```bash
# List SSO providers
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/sso.listProviders"

# Register GitHub OAuth
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "github", "clientId": "...", "clientSecret": "..."}' \
  "$DOKPLOY_URL/api/sso.register"

# Delete SSO provider
curl -s -X POST ... -d '{"ssoId": "<ssoId>"}' "$DOKPLOY_URL/api/sso.deleteProvider"
```

---

## Pitfalls & Common Issues

### 1. Traefik misses Compose-deployed containers
After a compose deploy, Traefik's Docker provider may miss the container creation event. The container has valid `traefik.enable=true` labels but Traefik never registers the route.
**Fix:** `docker restart $DOKPLOY_TRAEFIK_NAME`

### 2. Deploy triggers but app stays "stopped"
The deployment may have failed silently. Check:
```bash
docker ps -a --filter "name=<project-name>"
docker logs <container-name> --tail 50
```

### 3. Env vars not taking effect
Environment variables are injected at **build time** for git-based apps (during the Docker build) and **deploy time** for compose apps. After changing env vars, you must redeploy.

### 4. Secret env vars are masked in API responses
If you submit a secret and later fetch the app, the API returns `"******"` for the value. When updating env vars, you must re-submit ALL env vars, not just the ones you're changing. Save the original values locally before the update.

### 5. Compose file with special characters in JSON
When embedding a compose file in the JSON body, escape newlines as `\n` and quotes as `\"`. For complex compose files, use a JSON file or `jq` to construct the payload:
```bash
COMPOSE_CONTENT=$(cat docker-compose.yml | jq -Rs '.')
jq -n --arg compose "$COMPOSE_CONTENT" '{
  "projectId": "...",
  "name": "my-app",
  "composeFile": $compose,
  "composeType": "docker-compose",
  "sourceType": "raw"
}' | curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d @- "$DOKPLOY_URL/api/compose.create"
```

### 6. Git-based app fails to clone
Check: is the repo URL correct? Is the branch name correct? For private repos, is the SSH key configured? Test with:
```bash
GIT_SSH_COMMAND="ssh -i <key-path>" git ls-remote <repo-url> 2>&1 | head -5
```

### 7. HTTPS certificate provisioning fails on first deploy
Let's Encrypt generates certificates AFTER the domain routes through Traefik. On the first deploy after adding a domain, HTTPS may fail for a minute or two. Wait and retry.

### 8. Docker Compose project name conflicts
If you create a compose app with a name that conflicts with an existing Docker Compose project, containers may not start correctly. Use unique names.

### 9. Port conflicts
If a compose app exposes a host port (e.g., `ports: ["3000:3000"]`) and another app uses the same port, the deploy will fail. Use Traefik for routing instead of direct port mapping.

### 10. Auto-deploy pushes but nothing happens
The webhook was delivered but the app didn't redeploy. Check:
- Is the webhook URL correct? Compare with the one from `compose.one` or `application.one`
- Is `autoDeploy` enabled on the app?
- Check the deployment queue: `curl -s ... "$DOKPLOY_URL/api/deployment.queueList"`

---

## Verification Checklist

After any deployment:

- [ ] Containers are running: `docker ps --filter "name=<project-name>"`
- [ ] Traefik has the route: `docker exec $DOKPLOY_TRAEFIK_NAME wget -qO- http://localhost:8080/api/http/routers`
- [ ] App responds on domain: `curl -s -o /dev/null -w "%{http_code}" https://<domain>/`
- [ ] Health check passes (if configured): `curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/health`
- [ ] Logs show no errors: `docker logs <container> --tail 20 2>&1 | grep -i error`
- [ ] Environment variables are correct: Verify env vars were set via Section 6.3

---

## Research Protocol (when you hit something not covered)

1. **Fetch the live OpenAPI spec:**
   ```bash
   curl -sL https://raw.githubusercontent.com/Dokploy/dokploy/canary/openapi.json
   ```
2. **Check official docs:** https://docs.dokploy.com/docs/api
3. **Check running instance's API:** `https://<dokploy-domain>/api/trpc/settings.getOpenApiDocument`
4. **Fallback:** Docker CLI inspection (`docker ps`, `docker inspect`, `docker logs`)
5. **Cross-reference** with the running system before recommending actions

---

## Everything in this skill requires user permission.
## Never execute destructive commands without user confirmation.
## Always verify after every deployment step.
