---
name: dokploy-code-assisted
description: "Use when standard inspection and API diagnostics have failed and you need deep codebase-driven root cause analysis. Reads the app's actual source code — nginx.conf, docker-compose.yml, Dockerfile, CLAUDE.md, and runtime logs. Triggers on repeated failure signals. Always asks permission before running diagnostics."
version: 1.0.0
author: Hermes Agent
license: MIT
tags: [dokploy, diagnostics, debugging, nginx, compose, codebase, app-crash]
slash: /dokploy-diagnose
preview: "Deep codebase inspection for apps on Dokploy — reads nginx.conf, docker-compose.yml, Dockerfile, CLAUDE.md, and runtime logs to find root causes"
metadata:
  hermes:
    tags: [dokploy, diagnostics, codebase, nginx]
    related_skills: [dokploy, dokploy-manage, dokploy-deploy, dokploy-debug]
---

# dokploy-code-assisted

Diagnose broken, crashing, or stuck applications hosted on **Dokploy** by reading their actual source code, config files, and runtime state.

**CRITICAL RULES:**
1. **HARD GATE — Double confirmation required.** Never proceed past the activation gate without user permission. After presenting findings, get a second explicit confirmation before attempting any fix.
2. **Never modify code without explicit user consent.**
3. **Load this skill only when standard inspection fails** — try `dokploy-manage` first (API checks, container status, Traefik routes).
4. **Self-evolve:** When you discover a novel root cause, patch this skill with the new pattern.
5. **Always prepare a rollback plan** before suggesting any change.

---

## When to Use

**Use this skill when:**
- Standard inspection and API diagnostics have failed to find the root cause
- You need to read the app's actual source code files (nginx.conf, docker-compose.yml, Dockerfile, CLAUDE.md)
- The error repeats despite normal fixes — suggests a code or config-level issue
- You want the skill to self-evolve by saving newly discovered patterns

**Don't use this skill if:**
- You haven't tried standard diagnostics first → use `/dokploy-debug` for error-driven diagnostics
- You just want to restart/deploy/manage → use `/dokploy-manage` or `/dokploy-deploy`
- The issue is a known pattern → `/dokploy-debug` matches known patterns and may fix it directly
- You've never set up the suite → use `/dokploy` for the one-time setup guide

## Configuration

All configuration is documented in the `/dokploy` root skill. Run `skill_view(name='dokploy')` and read **Getting Started — One-Time Setup**. All values auto-detect except `DOKPLOY_API_KEY`.

You only need:

```bash
export DOKPLOY_API_KEY='your-key-here'
```

---

## Activation Gate (Hard Gate)

Before inspecting anything, present this message and **wait for confirmation**:

> "The app appears to be failing. I can investigate the source code, compose config, nginx.conf, and logs to find the root cause. This involves reading application files and running diagnostic commands. **May I proceed?**

> ⚠️ **Note:** Diagnostics are read-only. I will not modify anything without a second explicit confirmation after presenting findings."

### Where apps live on disk

All Dokploy compose apps:
```
$DOKPLOY_COMPOSE_DIR/
└── <project-id>/
    └── code/              ← git clone or uploaded source (this is $DOKPLOY_COMPOSE_DIR)
        ├── docker-compose.yml
        ├── Dockerfile
        ├── nginx.conf
        └── src/ ...
```

Dokploy git-based applications live at:
```
/etc/dokploy/applications/
└── <project-id>/
    └── code/
```

---

## Default File Checklist (read these FIRST, in order)

Read these files first, always, in this exact order:

```bash
# 0. Derive project ID from DOKPLOY_COMPOSE_DIR if available
PROJECT_ID=$(basename "$(dirname "$DOKPLOY_COMPOSE_DIR")")

# 1. docker-compose.yml    ← service definitions, ports, health checks, env vars
cat "$DOKPLOY_COMPOSE_DIR/docker-compose.yml"

# 2. nginx.conf            ← SPA routing, proxy_pass, listen port ← MAJORITY OF ISSUES HERE
cat "$DOKPLOY_COMPOSE_DIR/nginx.conf"

# 3. Dockerfile            ← build pipeline, CMD, entrypoint
cat "$DOKPLOY_COMPOSE_DIR/Dockerfile"

# 4. CLAUDE.md / README.md ← project docs, architecture, known issues
cat "$DOKPLOY_COMPOSE_DIR/CLAUDE.md" 2>/dev/null
cat "$DOKPLOY_COMPOSE_DIR/README.md" 2>/dev/null
```

### nginx.conf — Why It's First

| Symptom | Likely nginx Cause |
|---|---|
| Page loads blank / no content | `root` path doesn't match build output directory |
| API calls fail (502) | `proxy_pass` URL wrong or missing `/` suffix |
| 404 on page refresh | No `try_files` fallback for SPA routing |
| Static assets 404 | `location` block path prefix mismatch |
| Port mismatch | `listen` port doesn't match container's exposed port |
| Health check fails | Health endpoint path doesn't exist in nginx config |

**Diagnostic flow:** Read nginx.conf → check listen port vs compose expose → check root path vs actual build output → check proxy_pass endpoints vs API container ports.

---

## Step 1: Locate the Application

```bash
# If DOKPLOY_COMPOSE_DIR is already set, skip this
# Otherwise, search by keyword:
ls "$DOKPLOY_COMPOSE_DIR/" | grep -i "<app-name-or-keyword>"

# Then set:
export DOKPLOY_COMPOSE_DIR="$DOKPLOY_COMPOSE_DIR/<project-id>/code"
echo "APP_PATH=$DOKPLOY_COMPOSE_DIR"
```

---

## Step 2: Read Default Files

```bash
# 1. docker-compose.yml — understand the architecture
cat "$DOKPLOY_COMPOSE_DIR/docker-compose.yml"

# 2. nginx.conf — MOST COMMON ISSUE SOURCE
cat "$DOKPLOY_COMPOSE_DIR/nginx.conf"

# 3. Dockerfile — build pipeline + CMD
cat "$DOKPLOY_COMPOSE_DIR/Dockerfile"

# 4. CLAUDE.md — project docs, architecture, known issues
cat "$DOKPLOY_COMPOSE_DIR/CLAUDE.md" 2>/dev/null
```

---

## Step 3: Check Runtime State

```bash
# Container status (filter by project)
docker ps --filter "name=$PROJECT_ID" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Or by full container name match:
CONTAINER_NAME=$(docker ps --filter "name=$PROJECT_ID" --format "{{.Names}}" | head -1)
echo "Primary container: $CONTAINER_NAME"

# Container logs (last 50 lines)
docker logs "$CONTAINER_NAME" --tail 50

# Container logs (errors only)
docker logs "$CONTAINER_NAME" --tail 100 2>&1 | grep -i "error\|fatal\|panic\|exception"

# Exit code (if crashed)
docker inspect "$CONTAINER_NAME" --format '{{.State.Status}} {{.State.ExitCode}} {{.State.Error}}'
```

---

## Step 4: Generic Diagnostic Patterns

These work for ANY application type, regardless of stack:

### 4.1 Container Not Reachable / No Route to Service

```bash
# Step A: Can we reach the container at all?
docker exec -i "$DOKPLOY_TRAEFIK_NAME" wget -qO- -T 3 "http://$CONTAINER_NAME:${PORT:-80}" 2>/dev/null | head -5

# Step B: Are they on the same network?
TRAEFIK_NETWORKS=$(docker inspect "$DOKPLOY_TRAEFIK_NAME" --format '{{json .NetworkSettings.Networks}}' | jq keys)
APP_NETWORKS=$(docker inspect "$CONTAINER_NAME" --format '{{json .NetworkSettings.Networks}}' | jq keys)
echo "Traefik networks: $TRAEFIK_NETWORKS"
echo "App networks: $APP_NETWORKS"

# Step C: If no common network, diagnose
# Common fix: docker network connect <shared-network> $CONTAINER_NAME
```

### 4.2 Container Running But App Returns 5xx / Timeout

```bash
# Step A: Internal health check (bypass nginx)
docker exec "$CONTAINER_NAME" curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:${PORT}/health 2>/dev/null

# Step B: If health endpoint doesn't exist, guess common paths
for path in / /api/health /healthz /status /api/v1/health; do
  status=$(docker exec "$CONTAINER_NAME" curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}$path" 2>/dev/null)
  echo "$path → $status"
done

# Step C: Check if the app is listening on the expected port inside the container
docker exec "$CONTAINER_NAME" ss -tlnp 2>/dev/null || docker exec "$CONTAINER_NAME" netstat -tlnp 2>/dev/null
```

### 4.3 Build / Deploy Logs

```bash
# Check Dokploy deploy logs on disk
ls /etc/dokploy/logs/$PROJECT_ID/ 2>/dev/null || echo "No deploy logs directory"

# Find the latest build log
LATEST_LOG=$(ls -t /etc/dokploy/logs/$PROJECT_ID/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
  tail -80 "$LATEST_LOG"
fi

# Check Docker build cache / image history
docker image ls --filter "reference=*$PROJECT_ID*"
docker history $(docker image ls --filter "reference=*$PROJECT_ID*" --format "{{.ID}}" | head -1) 2>/dev/null | head -20
```

### 4.4 Environment Variable Mismatch

```bash
# What the compose file expects
echo "=== Compose Environment ==="
grep -A50 "environment:" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml" | head -60

# What's actually in the container
echo "=== Container Env ==="
docker inspect "$CONTAINER_NAME" --format '{{range .Config.Env}}{{.}}{{"\n"}}{{end}}' | grep -v "PATH=" | head -30

# Compare: if an env var referenced in the app is missing from the container, that's the bug
```

### 4.5 Dependency Health Chain

```bash
# Map service dependencies from docker-compose.yml
grep -A2 "depends_on:" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml"

# Check if each dependency is running
for dep in $(grep -A2 "depends_on:" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml" | grep -v "depends_on" | grep -v "^--$" | tr -d ' '); do
  status=$(docker ps --filter "name=$dep" --format "{{.Status}}")
  echo "Dependency: $dep → $status"
done

# Check DB specifically (most common dependency failure)
DB_CONTAINER=$(docker ps --filter "name=$PROJECT_ID.*db\|postgres\|mysql\|mariadb\|redis" --format "{{.Names}}" | head -1)
if [ -n "$DB_CONTAINER" ]; then
  echo "DB container: $DB_CONTAINER"
  docker inspect "$DB_CONTAINER" --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Health={{index .State.Health.Status}}'
  docker logs "$DB_CONTAINER" --tail 20
fi
```

### 4.6 Port / Network Binding Issues

```bash
# What ports does the compose file expose?
grep -E "^  [a-z].*:" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml" | head -5
grep -A3 "ports:" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml"

# Traefik exposes port inferred from labels
docker inspect "$CONTAINER_NAME" --format '{{json .Config.Labels}}' | jq 'with_entries(select(.key | test("traefik")))'

# What's actually bound on the host
ss -tlnp | grep -E "$(docker inspect "$CONTAINER_NAME" --format '{{range $p, $conf := .NetworkSettings.Ports}}{{printf "%s" $p}}{{end}}' | sed 's/\/tcp//g')"
```

---

## Step 5: Archetype-Specific Diagnostics

### Archetype A: Static SPA (React/Svelte/Vue + nginx)

```bash
# 1. Read nginx.conf — check root path and try_files
cat "$DOKPLOY_COMPOSE_DIR/nginx.conf"

# 2. Check actual build output directory
ls -la "$DOKPLOY_COMPOSE_DIR/" | grep -i "dist\|build\|public\|out"
ls -la "$DOKPLOY_COMPOSE_DIR/web/dist/" 2>/dev/null
ls -la "$DOKPLOY_COMPOSE_DIR/dist/" 2>/dev/null
ls -la "$DOKPLOY_COMPOSE_DIR/build/" 2>/dev/null

# 3. Compare build output path with nginx root directive
# If they don't match, page serves empty content or 404

# 4. Check SPA routing in nginx
# Should have: try_files $uri $uri/ /index.html;
# Missing → 404 on page refresh

# 5. Verify container has the built assets
docker exec "$CONTAINER_NAME" ls -la /usr/share/nginx/html 2>/dev/null
docker exec "$CONTAINER_NAME" ls -la <nginx-root-path> 2>/dev/null
```

### Archetype B: Python API Backend (FastAPI + uvicorn)

```bash
# 1. Read Dockerfile — check CMD and entrypoint
grep -A3 "CMD\|ENTRYPOINT\|RUN" "$DOKPLOY_COMPOSE_DIR/Dockerfile"

# 2. Check env vars in compose
grep -A20 "environment:" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml" | grep -v "^#" | head -30

# 3. Read the API source entrypoint
ls "$CODE_DIR/api/main.py" "$CODE_DIR/app/main.py" 2>/dev/null || find "$CODE_DIR" -name "main.py" -path "*/app/*" -o -name "api.py" -path "*/api/*" 2>/dev/null | head -5
ls "$DOKPLOY_COMPOSE_DIR/app/main.py" 2>/dev/null
ls "$DOKPLOY_COMPOSE_DIR/api/main.py" 2>/dev/null
ls "$DOKPLOY_COMPOSE_DIR/src/main.py" 2>/dev/null

# 4. Check what port the API listens on
grep -i "port\|host\|uvicorn" "$DOKPLOY_COMPOSE_DIR/Dockerfile" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml" 2>/dev/null

# 5. Test the API health endpoint internally
docker exec "$CONTAINER_NAME" curl -s http://127.0.0.1:<port>/health 2>/dev/null
```

### Archetype C: Full-Stack (nginx → API → DB)

```bash
# 1. Trace the request path
# nginx.conf → proxy_pass → API container → DB connection
grep proxy_pass "$DOKPLOY_COMPOSE_DIR/nginx.conf"

# 2. Check nginx reverse proxy target
# Format: proxy_pass http://<service-name>:<port>/;
# Service name must match docker-compose.yml service name

# 3. Check if API service is healthy
docker ps --filter "name=$PROJECT_ID" --format "table {{.Names}}\t{{.Status}}"

# 4. Check DB connectivity
docker exec "$CONTAINER_NAME" ping -c 1 <db-service> 2>/dev/null

# 5. Check if API port matches nginx target
grep -i "port\|APP_PORT\|API_PORT" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml"
```

### Archetype D: Container Crash Loop

```bash
# 1. Get exit code
docker inspect "$CONTAINER_NAME" --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Error={{.State.Error}}'

# Exit code meanings:
#   0   = clean exit
#   1   = general error (app crash, misconfig)
#   137 = SIGKILL (OOM kill)
#   139 = SIGSEGV (segfault)
#   143 = SIGTERM (graceful shutdown)

# 2. Check OOM in system logs
dmesg | grep -i "kill\|oom" | tail -5

# 3. Check startup logs (short logs = crash on init)
docker logs "$CONTAINER_NAME" --tail 20

# 4. Compare Dockerfile CMD with compose command override
grep "CMD\|ENTRYPOINT" "$DOKPLOY_COMPOSE_DIR/Dockerfile"
grep -A2 "command:" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml"
```

---

## Step 6: Log Cross-Referencing

Match error patterns to specific config files:

| Error Log Pattern | Likely Config File | What to Check |
|---|---|---|
| `nginx: [emerg] bind() to 0.0.0.0:80 failed` | nginx.conf | Port already in use — check `expose` vs `ports` |
| `connect() failed (111: Connection refused)` | nginx.conf | `proxy_pass` target IP/port wrong |
| `Cannot find module` | Dockerfile, package.json | Missing build step or wrong WORKDIR |
| `ModuleNotFoundError` | docker-compose.yml | Missing PYTHONPATH or install step |
| `wget: can't connect to remote host` | docker-compose.yml | Health check URL wrong |
| `Cannot open display` | .xsession, Xorg config | Known XRDP+XFCE bug — switch to TigerVNC |
| `OOMKilled` | docker-compose.yml | Add memory limits or increase swap |
| `dial tcp: lookup <service>` | docker-compose.yml | Service name not resolvable — check `depends_on` or network |
| `Permission denied` | Dockerfile | Wrong file permissions — check `chmod` in build |
| `address already in use` | nginx.conf, docker-compose.yml | Port conflict with another container or host process |

---

## Step 7: Pattern Matching — Past Issues

| Symptom | Root Cause | Fix |
|---|---|---|
| SPA/web container vanished after compose down | Compose down removed the container; Traefik missed events | `docker compose -f "$DOKPLOY_COMPOSE_DIR/docker-compose.yml" up -d <service> && docker restart "$DOKPLOY_TRAEFIK_NAME"` |
| SPA web "unhealthy" | Health check used `/health` but nginx SPA only serves `/` | Change health check to `curl -f http://localhost:<port>/` |
| App returns 404 via Traefik | Compose container labels not picked up by Docker provider | `docker restart "$DOKPLOY_TRAEFIK_NAME"` |
| XRDP session crashes in 1 second | `xfwm4: cannot open display` — Ubuntu 24.04 + XFCE bug | Replace with TigerVNC |
| Application exposed on random high port | Docker published port bypassed UFW | Add DOCKER-USER iptables rule |
| SPAserve missing publicPath | nginx root path doesn't match build output dir | Align nginx `root` with actual build directory |
| Container exits immediately with code 1 | Missing env vars (DB_HOST, API_KEY) referenced on startup | Add missing env vars to compose `environment:` block |
| Traefik route exists but returns 502 | Network mismatch — app on bridge, Traefik on overlay | `docker network connect dokploy-network "$CONTAINER_NAME"` |

---

## Rollback Procedures

**HARD GATE:** Before executing any fix, you MUST:
1. Present the findings and the proposed fix
2. Show the rollback plan below
3. Get **second explicit confirmation** ("Are you sure you want to proceed?")
4. Execute the fix
5. Verify the fix worked
6. Print the rollback command

### Rollback Reference

| Fix Action | Rollback Procedure |
|---|---|
| **Restart container** | Previous state is lost — no rollback needed (restart is ephemeral) |
| **Modify docker-compose.yml** | `git checkout "$DOKPLOY_COMPOSE_DIR/docker-compose.yml"` (if tracked) or restore from backup: `cp "$DOKPLOY_COMPOSE_DIR/docker-compose.yml.bak" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml"` |
| **Modify nginx.conf** | `git checkout "$DOKPLOY_COMPOSE_DIR/nginx.conf"` or restore from backup |
| **Modify Dockerfile** | `git checkout "$DOKPLOY_COMPOSE_DIR/Dockerfile"` or restore from backup |
| **Restart Traefik** | `docker restart "$DOKPLOY_TRAEFIK_NAME"` is safe (no config change) |
| **docker network connect** | `docker network disconnect <network> "$CONTAINER_NAME"` |
| **Add env var via compose** | Remove the added line from `docker-compose.yml` and `docker compose -f "$DOKPLOY_COMPOSE_DIR/docker-compose.yml" up -d` |
| **docker compose up -d** | `docker compose -f "$DOKPLOY_COMPOSE_DIR/docker-compose.yml" down` then restore prior versions of containers |
| **Modify environment:** in compose | Remove the added environment variable(s) and re-deploy |
| **Change health check** | Restore original health check config in compose, re-deploy |
| **Delete or modify a file** | Restore from git: `cd "$DOKPLOY_COMPOSE_DIR" && git checkout -- <file>` |

### Before Any Fix: Snapshot Procedure

Before making any change, take a snapshot:

```bash
# Backup critical config files
cp "$DOKPLOY_COMPOSE_DIR/docker-compose.yml" "$DOKPLOY_COMPOSE_DIR/docker-compose.yml.bak.$(date +%s)"
cp "$DOKPLOY_COMPOSE_DIR/nginx.conf" "$DOKPLOY_COMPOSE_DIR/nginx.conf.bak.$(date +%s)"
cp "$DOKPLOY_COMPOSE_DIR/Dockerfile" "$DOKPLOY_COMPOSE_DIR/Dockerfile.bak.$(date +%s)"

# Record current container state
docker inspect "$CONTAINER_NAME" > /tmp/dokploy-snapshot-${PROJECT_ID}.json

# Note current git SHA if available
(cd "$DOKPLOY_COMPOSE_DIR" && git rev-parse HEAD 2>/dev/null && git diff --stat) || echo "Not a git repository or no changes tracked"
```

### After Fix: Verification & Exit Plan

```bash
# 1. Verify container is running
docker ps --filter "name=$PROJECT_ID" --format "{{.Names}} {{.Status}}"

# 2. Verify health check passes
docker inspect "$CONTAINER_NAME" --format '{{json .State.Health}}' | jq '.Status' 2>/dev/null || echo "No health check defined"

# 3. Verify app responds
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:<port>/ 2>/dev/null || echo "Cannot reach app directly"

# 4. Verify Traefik route exists
docker exec "$DOKPLOY_TRAEFIK_NAME" wget -qO- http://localhost:8080/api/http/routers | jq -r '.[] | select(.name | test("'"$PROJECT_ID"'")) | .name' 2>/dev/null || echo "No Traefik route found"

# 5. Print rollback command for quick undo
echo "=== Rollback if something is wrong ==="
echo "docker compose -f \"$DOKPLOY_COMPOSE_DIR/docker-compose.yml\" down"
echo "cp \"$DOKPLOY_COMPOSE_DIR/docker-compose.yml.bak.*\" \"$DOKPLOY_COMPOSE_DIR/docker-compose.yml\""
echo "cp \"$DOKPLOY_COMPOSE_DIR/nginx.conf.bak.*\" \"$DOKPLOY_COMPOSE_DIR/nginx.conf\""
echo "docker compose -f \"$DOKPLOY_COMPOSE_DIR/docker-compose.yml\" up -d"
```

---

## Troubleshooting Tips

When diagnosing issues, also check:
- **Traefik event miss:** After a compose deploy, Traefik's Docker provider may miss the container creation event. If the app has valid Traefik labels but doesn't appear in Traefik's router list, restart Traefik: `docker restart "$DOKPLOY_TRAEFIK_NAME"`.
- **Copy-paste heredoc trap:** When providing service files or config blocks for copy-paste, `tee <<'EOF'` heredocs may trigger a `heredoc>` prompt in WSL2/Windows terminals. Prefer `sudo nano <file>` and paste content manually, or generate on the agent side with `write_file`.
- **App deployed by compose but not by API:** If Dokploy UI shows the app but the API returns nothing for `compose.search`, the Dokploy DB record may be stale. Re-deploy via the UI or API.
- **Traefik API not available:** If `wget` to Traefik's API endpoint fails, the API port (8080) may not be exposed. Try adding `traefik.enable=true` label or inspect Traefik config directly: `cat /etc/dokploy/traefik/dynamic/*.yml`.
- **Container name different from project name:** Dokploy may name containers with suffixes like `.<replica>`. Always use `--filter "name=$PROJECT_ID"` not exact matches.

## Self-Evolution Protocol

When you discover a **novel root cause** that isn't already in this skill:

1. **Document** the symptom, root cause, and fix as a new row in the `Pattern Matching` table
2. **Patch the skill** using:
   ```
   skill_manage(action='patch', name='dokploy-code-assisted',
     old_string='<existing relevant section>',
     new_string='<existing section + new pattern>')
   ```
3. **Only patch patterns that are non-obvious** — don't add "container not running → start it"
4. **Always include the exact log line** that identifies the issue

---

## Safety Checklist

- [ ] **HARD GATE:** Asked user permission before starting diagnostics
- [ ] Presented the scope (read-only, configs + logs)
- [ ] Read nginx.conf first (majority of issues)
- [ ] Read docker-compose.yml second (architecture)
- [ ] Checked runtime state (logs, exit code, health)
- [ ] Cross-referenced error logs with config files
- [ ] Presented findings and suggested fix to user
- [ ] **HARD GATE:** Got second confirmation before any fix
- [ ] Snapshot config files before modifying
- [ ] Presented rollback plan before executing fix
- [ ] Verified fix worked after execution
- [ ] Printed rollback command for user
- [ ] Never modified code without consent
- [ ] Patched skill with novel patterns after resolution
