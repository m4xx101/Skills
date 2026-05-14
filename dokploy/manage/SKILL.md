---
name: dokploy-manage
description: "Use when you need to list, inspect, deploy, stop, start, or delete Docker Compose apps on a Dokploy instance via the REST API. API-first control plane with 450 endpoints — compose lifecycle, domain management, deployment tracking, and cleanup. Direct Docker CLI fallbacks for root server access."
version: 1.0.0
author: Hermes Agent
license: MIT
tags: [dokploy, docker, docker-compose, swarm, deployment, api, traefik]
slash: /dokploy-manage
preview: "List/inspect/deploy/stop/start/delete Docker Compose apps via Dokploy API"
metadata:
  hermes:
    tags: [dokploy, api, compose, management]
    related_skills: [dokploy, dokploy-deploy, dokploy-debug, dokploy-code-assisted]
---

# dokploy-manage

Manage applications deployed through **Dokploy** — a self-hosted PaaS / Vercel / Heroku alternative that manages Docker Compose + Swarm deployments behind Traefik.

**CRITICAL RULE:** Never execute without user permission. Every step: present → confirm → execute → verify.

---

## When to Use

**Use this skill when:**
- You need to list, inspect, stop, start, or delete compose apps via the API
- You need to manage domains, projects, environments, or deployments
- You need the Dokploy API directly (all endpoints documented)
- You're working alongside coding agents in an active dev environment

**Don't use this skill if:**
- You want to deploy a new app → use `/dokploy-deploy` for the full workflow with validation
- You have a specific error → use `/dokploy-debug` for pattern-matched diagnostics
- You need codebase inspection → use `/dokploy-diagnose` for nginx/Dockerfile/CLAUDE.md analysis
- You've never set up the suite → use `/dokploy` for the one-time setup guide

## Configuration

All configuration is documented in the `/dokploy` root skill. Run `skill_view(name='dokploy')` and read **Getting Started — One-Time Setup**. All values auto-detect except `DOKPLOY_API_KEY`. You only need:

```bash
export DOKPLOY_API_KEY='your-key-here'
```

---

## Research Protocol (use when you hit something you don't know)

If any situation, error, or question is not covered by this skill:

1. **Fetch the live OpenAPI spec** from the source:
   ```
   curl -sL https://raw.githubusercontent.com/Dokploy/dokploy/canary/openapi.json
   ```
2. **Consult official docs**: https://docs.dokploy.com/docs/api
3. **Check running instance's API**: `https://<dokploy-domain>/api/trpc/settings.getOpenApiDocument` (requires auth)
4. **Fallback**: Docker CLI inspection (`docker ps`, `docker inspect`, `docker logs`, `docker compose config`)
5. **Return with**: endpoint name, required params, example curl, risk assessment, and verification step

Always cross-reference with the running system before recommending actions.

---

## Cross-Skill Proactive Suggestions

When this skill loads, it detects context and suggests companion skills:

| If user is... | Suggest... | Why |
|---|---|---|
| Asking to deploy or update an app | `/dokploy-deploy` | Full deploy workflow with validation and rollback |
| Reporting an error, crash, or "not working" | `/dokploy-debug` | Error-driven diagnostics with pattern matching |
| Dealing with config file issues (nginx, compose) | `/dokploy-diagnose` | Codebase inspection — reads nginx.conf, Dockerfile, logs |

---

## Quick Reference: Key IDs to Know

| ID Type | How to Find | Used In |
|---|---|---|
| `composeId` | GET `/api/compose.search?name=<name>` | compose.* endpoints |
| `applicationId` | GET `/api/application.search?name=<name>` | application.* endpoints |
| `projectId` | GET `/api/project.all` | project, compose, application |
| `environmentId` | GET `/api/environment.search?name=<name>` | compose, application |
| `serverId` | GET `/api/server.all` | server, compose, application |
| `domainId` | GET `/api/domain.byComposeId?composeId=<id>` | domain.* |
| `deploymentId` | GET `/api/deployment.all?applicationId=<id>` | deployment.* |

---

## SECTION 1: Setup & Authentication

### 1.1 Setup Environment

```bash
# Base URL — replace with your Dokploy domain or localhost
DOKPLOY_URL="${DOKPLOY_URL:-http://localhost:3000}"
# Or for local access: DOKPLOY_URL="http://localhost:3000"

# API Key — generate at Dokploy Dashboard → Settings → Profile → API/CLI Section
# Set this as an environment variable (DOKPLOY_API_KEY) or ask user to provide it

# Test connection
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/settings.health"
# Expected: {"message":"Unauthorized"} if no key, or health data with key
```

### 1.2 API Key Generation (direct from root server)

If you have root access to the Dokploy postgres container:

```bash
# Generate API key via Dokploy API itself (requires existing auth)
# Or use the Dokploy Swagger UI at $DOKPLOY_URL/swagger (after login)

# Verify key works:
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/settings.getDokployVersion"
```

### 1.3 Auth Header Pattern

All API calls use:
```bash
curl -s -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" <endpoint>
```

GET requests use query parameters:
```bash
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.one?composeId=<id>"
```

POST requests use JSON body:
```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"key": "value"}' "$DOKPLOY_URL/api/compose.delete"
```

---

## SECTION 2: App Lifecycle (Compose)

Compose apps are Docker Compose projects managed through Dokploy.

### 2.1 List & Search Compose Apps (READ-ONLY)

```bash
# List all compose apps
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.search"

# Search by name
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.search?name=<name>"

# Get single app by ID
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.one?composeId=<id>"

# Direct Docker alternative (no API key needed):
docker compose -p <project-name> ps
docker inspect <container-name>
```

### 2.2 Deploy / Redeploy Compose App

```bash
# Deploy
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.deploy"

# Redeploy (trigger rebuild)
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.redeploy"

# Direct Docker alternative (Dokploy won't track this):
docker compose -f $DOKPLOY_COMPOSE_DIR/<project>/code/docker-compose.yml up -d
```

### 2.3 Start / Stop Compose App

```bash
# Start
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.start"

# Stop
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.stop"
```

### 2.4 Cancel / Kill Build

```bash
# Cancel deployment
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.cancelDeployment"

# Kill running build
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>"}' "$DOKPLOY_URL/api/compose.killBuild"
```

### 2.5 Delete Compose App (DESTRUCTIVE)

**⚠️ HARD GATE:** Before executing: 1. Present the change to the user  2. Show the rollback procedure  3. Wait for explicit confirmation  4. Execute  5. Verify  6. Print rollback instructions

```bash
# Preview what will be deleted first
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.one?composeId=<id>"

# Confirm with user, then:
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<composeId>", "deleteVolumes": false}' "$DOKPLOY_URL/api/compose.delete"

# Setting deleteVolumes: true also removes persistent volume data!
# Direct Docker alternative (Dokploy won't know it's gone):
docker compose -p <project> down
rm -rf $DOKPLOY_COMPOSE_DIR/<project>/
```

**Important:** After delete through API, always verify:
```bash
ls $DOKPLOY_COMPOSE_DIR/<project>/ 2>/dev/null || echo "Compose directory removed ✅"
docker ps -a --filter "name=<project-name>" | grep <project> || echo "Containers gone ✅"
```

---

## SECTION 3: App Lifecycle (Application)

Git-based applications (not Docker Compose). These are apps deployed from GitHub/GitLab/Bitbucket repositories.

### 3.1 Search & Inspect

```bash
# Search applications
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/application.search?name=<name>"

# Get one
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/application.one?applicationId=<id>"
```

### 3.2 Lifecycle Commands

```bash
# Deploy
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<id>"}' "$DOKPLOY_URL/api/application.deploy"

# Redeploy
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<id>"}' "$DOKPLOY_URL/api/application.redeploy"

# Stop
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<id>"}' "$DOKPLOY_URL/api/application.stop"

# Start
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<id>"}' "$DOKPLOY_URL/api/application.start"

**⚠️ HARD GATE:** Before deleting: 1. Present the app and its dependencies  2. Show rollback (redeploy from last known good)  3. Wait for confirmation  4. Execute  5. Verify  6. Print rollback command

# Delete
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"applicationId": "<id>"}' "$DOKPLOY_URL/api/application.delete"
```

---

## SECTION 4: Domain Management

### 4.1 List Domains

```bash
# Domains for a compose app
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/domain.byComposeId?composeId=<id>"

# Domains for an application
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/domain.byApplicationId?applicationId=<id>"
```

### 4.2 Add Domain

```bash
# For compose apps:
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "host": "app.example.com",
    "composeId": "<composeId>",
    "serviceName": "web",
    "domainType": "compose",
    "certificateType": "letsencrypt",
    "https": true,
    "port": null,
    "path": null
  }' "$DOKPLOY_URL/api/domain.create"
```

**Parameters explained:**
- `host`: The domain name (e.g., `myapp.example.com`)
- `composeId` or `applicationId`: What to attach the domain to
- `serviceName`: For compose apps, which service to route to
- `certificateType`: `"letsencrypt"`, `"none"`, or `"custom"`
- `https`: `true` to enable HTTPS
- `port`: Override port (null = use app's default)
- `stripPath`: `false` to preserve path prefix

### 4.3 Delete Domain

```bash
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"domainId": "<id>"}' "$DOKPLOY_URL/api/domain.delete"
```

### 4.4 Generate Domain (traefik.me)

```bash
# Dokploy can auto-generate a *.traefik.me domain for testing:
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "composeId": "<composeId>",
    "serviceName": "web",
    "domainType": "compose",
    "certificateType": "none",
    "https": false
  }' "$DOKPLOY_URL/api/domain.generateDomain"
```

---

## SECTION 5: Project & Environment Management

### 5.1 Projects

```bash
# List all projects
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/project.all"

# Get one
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/project.one?projectId=<id>"

# Create project
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "my-project", "description": "optional desc", "env": "production"}' \
  "$DOKPLOY_URL/api/project.create"

# Delete project
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"projectId": "<id>"}' "$DOKPLOY_URL/api/project.remove"
```

### 5.2 Environments

```bash
# List environments in a project
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/environment.byProjectId?projectId=<id>"

# Create environment
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"name": "staging", "projectId": "<projectId>"}' "$DOKPLOY_URL/api/environment.create"

# Remove environment
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"environmentId": "<id>"}' "$DOKPLOY_URL/api/environment.remove"
```

---

## SECTION 6: Deployment Management

### 6.1 View Deployments

```bash
# All deployments for an application
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/deployment.all?applicationId=<id>"

# All for a compose app
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/deployment.allByCompose?composeId=<id>"

# Queue list (stuck deployments)
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/deployment.queueList"

# Direct Docker alternative:
docker logs <container-name> --tail 50
docker inspect <container-name> --format '{{.State.Status}}'
```

### 6.2 Clean Stuck Deployments

```bash
# Kill a stuck process
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"deploymentId": "<id>"}' "$DOKPLOY_URL/api/deployment.killProcess"

# Remove deployment record
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"deploymentId": "<id>"}' "$DOKPLOY_URL/api/deployment.removeDeployment"

# Clean entire queue
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{}' "$DOKPLOY_URL/api/compose.cleanQueues"
```

---

## SECTION 7: Docker Operations (Direct)

These don't need the Dokploy API. Available from the root server.

### 7.1 Container Inspection

```bash
# List all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Container details
docker inspect <container-name>

# Container logs
docker logs <container-name> --tail 50
docker logs <container-name> --tail 100 2>&1 | grep -i error

# Resource usage
docker stats --no-stream <container-name>

# Container health check
docker inspect <container-name> --format '{{json .State.Health}}' | jq .
```

### 7.2 Network Analysis

```bash
# List networks
docker network ls

# Who's on a network
docker network inspect <network-name> --format '{{range .Containers}}{{.Name}} ({{.IPv4Address}}) {{end}}'

# Check if Traefik, Dokploy, and apps share a network
docker network inspect dokploy-network --format '{{range .Containers}}{{.Name}} {{end}}'
```

### 7.3 Docker Compose Projects

```bash
# List compose files
ls $DOKPLOY_COMPOSE_DIR/

# Read compose config
cat $DOKPLOY_COMPOSE_DIR/<project>/code/docker-compose.yml

# Start/stop project (bypasses Dokploy tracking)
docker compose -f $DOKPLOY_COMPOSE_DIR/<project>/code/docker-compose.yml up -d
docker compose -f $DOKPLOY_COMPOSE_DIR/<project>/code/docker-compose.yml down
```

### 7.4 Docker Swarm Services

```bash
# List swarm services
docker service ls

# Service status
docker service ps <service-name>

# Swarm node info
docker node ls
```

---

## SECTION 8: Traefik Management

### 8.1 Inspect Traefik Routes

```bash
# Via Traefik API (internal):
docker exec $DOKPLOY_TRAEFIK_NAME wget -qO- http://localhost:8080/api/http/routers | jq -r '.[] | "\(.name) → \(.rule)"'

# All services
docker exec $DOKPLOY_TRAEFIK_NAME wget -qO- http://localhost:8080/api/http/services | jq -r '.[].name'

# Traefik logs
docker logs $DOKPLOY_TRAEFIK_NAME --tail 50

# Traefik dynamic config
cat /etc/dokploy/traefik/dynamic/*.yml
```

### 8.2 Reload / Restart Traefik

```bash
# Graceful reload (no downtime)
docker exec $DOKPLOY_TRAEFIK_NAME kill -HUP 1

# Hard restart
docker restart $DOKPLOY_TRAEFIK_NAME
```

**When to restart Traefik:**
- After a container was deployed via Docker Compose and Traefik didn't pick it up (provider event timeout)
- After modifying `/etc/dokploy/traefik/dynamic/*.yml`
- When routes show "404" despite correct labels

---

## SECTION 9: Debugging & Root Cause Analysis

### 9.1 App Won't Start / Container Crashing

```bash
# 1. Check container status
docker ps -a --filter "name=<app-name>"

# 2. Check exit code / reason
docker inspect <container-name> --format '{{.State.Status}} {{.State.ExitCode}} {{.State.Error}}'

# 3. View logs
docker logs <container-name> --tail 100

# 4. Check health check
docker inspect <container-name> --format '{{json .State.Health}}' | jq .

# 5. Check Traefik sees it
docker exec $DOKPLOY_TRAEFIK_NAME wget -qO- http://localhost:8080/api/http/routers | jq -r '.[] | select(.name | test("<app-name>"))'
```

### 9.2 Application Returns 404 / 502 via Traefik

```bash
# 1. Check if Traefik has a route
docker exec $DOKPLOY_TRAEFIK_NAME wget -qO- http://localhost:8080/api/http/routers | jq -r '.[] | select(.name | test("<app-name>")) | .name'

# 2. No route? Check Docker labels
docker inspect <container-name> --format '{{json .Config.Labels}}' | jq 'with_entries(select(.key | test("traefik"))) | keys'

# 3. Route exists but 502? Check if container is reachable
docker exec $DOKPLOY_TRAEFIK_NAME wget -qO- -T 3 http://<container-name>:<port> 2>/dev/null | head -3

# 4. 502 means Traefik can't reach the container — check networks
docker inspect <container-name> --format '{{json .NetworkSettings.Networks}}' | jq 'keys'
docker inspect $DOKPLOY_TRAEFIK_NAME --format '{{json .NetworkSettings.Networks}}' | jq 'keys'

# 5. Fix: Ensure both are on same network, then restart Traefik
```

### 9.3 SSL Certificate Issues

```bash
# Check Let's Encrypt cert status
cat /etc/dokploy/traefik/dynamic/acme.json | jq '.letsencrypt.Certificates[] | select(.domain.main == "<domain>") | .domain'
docker logs $DOKPLOY_TRAEFIK_NAME 2>&1 | grep -i "acme\|certificate\|letsencrypt" | tail -10

# Check Cloudflare SSL mode (if proxied):
# Go to Cloudflare Dashboard → SSL/TLS → Overview
# Must be "Full" (not Flexible) when using Traefik's redirect-to-https
```

### 9.4 Dokploy API Connection Issues

```bash
# 1. Is Dokploy running?
docker ps --filter "name=dokploy" --format "{{.Names}} {{.Status}}"

# 2. Can Traefik reach Dokploy?
docker exec $DOKPLOY_TRAEFIK_NAME wget -qO- -T 3 http://dokploy:3000 2>/dev/null | head -1

# 3. API key valid?
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/settings.health"

# 4. Check Dokploy logs
docker logs dokploy.1.5hjcvos0vrsccfppae8m3ibpd --tail 50
```

### 9.5 Dokploy Shows "Unhealthy" but App Responds

```bash
# The health check might be misconfigured (e.g., wget to /health when it should be /)
# Check what the health check uses:
docker inspect <container-name> --format '{{range .Config.Cmd}}{{.}} {{end}}' | head -1
cat $DOKPLOY_COMPOSE_DIR/<project>/code/docker-compose.yml | grep -A5 "healthcheck"
```

---

## SECTION 10: Cleanup & Maintenance

### 10.1 Cleanup Via API

```bash
# Clean stopped containers
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{}' "$DOKPLOY_URL/api/settings.cleanStoppedContainers"

# Clean unused images
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{}' "$DOKPLOY_URL/api/settings.cleanUnusedImages"

# Clean unused volumes
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{}' "$DOKPLOY_URL/api/settings.cleanUnusedVolumes"

# Clean Docker builder cache
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{}' "$DOKPLOY_URL/api/settings.cleanDockerPrune"

# Clean all
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{}' "$DOKPLOY_URL/api/settings.cleanAll"
```

### 10.2 Cleanup Without API (Direct Docker)

```bash
# Safer — these bypass Dokploy's tracking:
docker system prune -f              # Clean stopped containers + dangling images
docker volume prune -f              # Clean unused volumes
docker builder prune -f             # Clean build cache
docker image prune -af              # Clean all unused images
```

---

## SECTION 11: Server Management (Remote Servers)

Dokploy can manage multiple servers. This endpoint handles adding/removing remote build/deploy servers.

```bash
# List all servers
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/server.all"

# Add a remote server
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "name": "build-server-1",
    "description": "Build server for heavy compiles",
    "ipAddress": "192.168.1.100",
    "port": 22,
    "username": "root",
    "sshKeyId": "<sshKeyId>",
    "serverType": "build"
  }' "$DOKPLOY_URL/api/server.create"

# Remove a server (DESTRUCTIVE)

**⚠️ HARD GATE:** Before removing a server: 1. Present server details and dependent apps  2. Show rollback (re-add via server.create)  3. Wait for confirmation  4. Execute  5. Verify  6. Print rollback command

curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"serverId": "<id>"}' "$DOKPLOY_URL/api/server.remove"
```

---

## SECTION 12: Backup Management

### 12.1 Create Backups

```bash
# Manual backup of compose app
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<id>"}' "$DOKPLOY_URL/api/backup.manualBackupCompose"

# Manual backup of Postgres database
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"databaseId": "<id>"}' "$DOKPLOY_URL/api/backup.manualBackupPostgres"

# List backups
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/backup.listBackupFiles"
```

---

## SECTION 13: Safe Graceful Removal

**⚠️ HARD GATE:** Before executing: 1. Present all resources and shared dependencies  2. Show rollback (check compose backup, save composeId/network topology)  3. Wait for explicit confirmation  4. Execute step-by-step  5. Verify each step  6. Print rollback commands

### 13.1 Full App Removal (Compose)

```bash
# Step 1: Inspect what exists
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.search?name=<name>"

# Step 2: Show user the details
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.one?composeId=<id>"

# Step 3: Check networks — are they shared with other containers?
docker network inspect <network-name> --format '{{range .Containers}}{{.Name}} {{end}}'

# Step 4: Check volumes — are they shared?
docker inspect <container-name> --format '{{json .Mounts}}' | jq '.[].Name'

# Step 5: Remove via API (Dokploy DB record + containers)
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{"composeId": "<id>", "deleteVolumes": false}' "$DOKPLOY_URL/api/compose.delete"

# Step 6: Filesystem cleanup
rm -rf $DOKPLOY_COMPOSE_DIR/<project>/
rm -rf /etc/dokploy/logs/<project>/

# Step 7: Check for orphaned networks (if external:true and only Traefik left)
docker network rm <orphaned-network> 2>/dev/null || echo "Network has other containers — keeping it"

# Step 8: Verify
ls $DOKPLOY_COMPOSE_DIR/<project>/ 2>/dev/null || echo "DONE ✅"
```

---

## Copy-Paste Format

When presenting commands to the user, prefer individual simple commands over chained pipes or heredocs. `tee <<'EOF'` heredocs can trigger a `heredoc>` prompt in WSL2/Windows terminals when copy-pasted. Use `sudo nano <file>` for service files, or generate on the agent side with `write_file`.

## Important Dokploy Concepts & Architecture

### How Apps are Organized

```
/etc/dokploy/
├── compose/                    # Docker Compose-based apps
│   └── <project-id>/
│       └── code/               # Git clone or uploaded source
│           ├── docker-compose.yml
│           └── ... (source code, Dockerfile, etc.)
│
├── applications/               # Git-based applications (Swarm deploy)
│   └── <project-id>/
│       └── code/               # Git clone
│
├── traefik/
│   ├── dynamic/                # Traefik file provider config
│   │   ├── acme.json           # Let's Encrypt certificates
│   │   ├── dokploy.yml         # Dokploy router
│   │   ├── middlewares.yml     # Shared middlewares
│   │   └── <app>.yml           # Per-app static routes
│   └── traefik.yml             # Main Traefik config
│
└── logs/                       # Build/deploy logs
    └── <project-id>/
        └── *.log
```

### Docker Network Architecture

```
dokploy-network (overlay, Swarm)
    ├── dokploy                 # The Dokploy app
    ├── $DOKPLOY_TRAEFIK_NAME    # Traefik reverse proxy
    ├── dokploy-postgres        # Dokploy's database
    ├── dokploy-redis           # Dokploy's cache
    └── <app containers>        # Application containers on overlay

<app-name>_default (bridge, local)
    └── <app containers>        # Per-app bridge network

ingress (overlay, Swarm)
    └── ingress-endpoint        # Swarm routing mesh
```

### How Traefik Routes Work

Traefik has TWO providers for routes:

1. **Docker provider** — auto-discovers container labels:
   - Watches Docker events via `/var/run/docker.sock`
   - Reads `traefik.*` labels on containers
   - Routes appear/disappear as containers start/stop
   - 🔴 **Known issue:** Container events can be missed on compose deploy. Fix: `docker restart $DOKPLOY_TRAEFIK_NAME`

2. **File provider** — static YAML config in `/etc/dokploy/traefik/dynamic/`:
   - Loaded at startup and on changes
   - Watches for file modifications
   - Used for: dokploy, portfolio, middleware

### Known Issues & Workarounds

| Issue | Symptom | Fix |
|---|---|---|
| Traefik misses compose container | 404 despite correct labels | `docker restart $DOKPLOY_TRAEFIK_NAME` |
| Cloudflare Flexible SSL | Infinite redirect loop | Set CF SSL to **Full** (not Flexible) |
| XRDP + XFCE crash | Session exits in 1 second | Switch to TigerVNC |
| Docker bypasses UFW | Port exposed despite UFW block | Add DOCKER-USER iptables rules |
| Container unhealthy but working | Dokploy shows warning | Fix health check path in compose file |
| Swapports exposed (single node) | 2377/7946/4789 open to internet | Block via DOCKER-USER + UFW |

---

## Rollback Quick Reference

| Operation | Rollback Command | Notes |
|---|---|---|
| **Compose Delete** | `curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" -d '{"name":"<name>","composeFile":"<saved-content>"}' "$DOKPLOY_URL/api/compose.create"` | Save composeId and compose file content **before** deleting |
| **Application Delete** | Redeploy from last known good commit: `curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" -d '{"applicationId":"<saved-id>"}' "$DOKPLOY_URL/api/application.deploy"` | Save applicationId **before** deleting |
| **Server Remove** | `curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" -d '{"name":"<saved-name>","ipAddress":"<saved-ip>","port":22,"username":"root","sshKeyId":"<saved-key>","serverType":"build"}' "$DOKPLOY_URL/api/server.create"` | Save server details **before** removing |
| **Compose Stop** | `curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" -d '{"composeId":"<saved-id>"}' "$DOKPLOY_URL/api/compose.start"` | Simple toggle — stop data is ephemeral |
| **Domain Delete** | `curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" -d '{"host":"<saved-host>","composeId":"<saved-id>","serviceName":"<saved-service>","certificateType":"letsencrypt","https":true}' "$DOKPLOY_URL/api/domain.create"` | Save domain host and app ID **before** deleting |
| **Cleanup (API)** | Not reversible — schedule a backup (`backup.manualBackupCompose`) before running | Clean operations are one-way |

> **Before every destructive action:** Save the resource ID, metadata, and any content that would be lost. Print these rollback commands after execution so the user can quickly undo if needed.

---

## Safety Checklist

Before any destructive operation, verify:

```bash
# 1. Is this the right app?
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/compose.one?composeId=<id>" | jq .

# 2. Are there shared resources?
docker network inspect <network> --format '{{range .Containers}}{{.Name}} {{end}}'

# 3. Check volumes
docker inspect <container> --format '{{json .Mounts}}' | jq '.[] | {Name: .Name, Source: .Source, Destination: .Destination}'

# 4. Confirm with user before proceeding
```

## Quick Reference

See `references/endpoints.md` for a compact listing of all 450+ Dokploy API endpoints across 44 categories — quick lookup when you need the exact endpoint path and method without re-fetching the OpenAPI spec.

## Everything in this skill is non-destructive unless explicitly noted.
## Never execute without user permission.
## Every destructive action must be preceded by an inspection step.
