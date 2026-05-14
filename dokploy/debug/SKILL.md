---
name: dokploy-debug
description: "Use when a Dokploy-hosted app is failing, crashing, stuck, unreachable, or behaving unexpectedly. Systematic diagnostic playbook — triage, container crashes, networking, Traefik routing, platform health, build pipeline failures, SSL/domain issues, resource pressure, database problems. Covers the full stack from Docker daemon to application routing."
version: 1.0.0
author: Hermes Agent
license: MIT
tags: [dokploy, debugging, diagnostics, troubleshooting, docker, traefik, containers, infrastructure]
slash: /dokploy-debug
preview: "Dokploy diagnostic triage — container, network, Traefik, platform, DNS, SSL, build, DB"
metadata:
  hermes:
    tags: [dokploy, diagnostics, debug, troubleshooting]
    related_skills: [dokploy, dokploy-manage, dokploy-deploy, dokploy-code-assisted]
---

# dokploy-debug

Systematic diagnostics for applications deployed via **Dokploy**. Use when an app is failing, crash-looping, unreachable, or behaving unexpectedly.

**CRITICAL RULES:**
1. **Always ask permission** before any action. Present findings first, then suggest fixes.
2. **Never modify code or config without explicit user consent.**
3. **Use the Symptom → Layer triage** below to find the right diagnostic track fast.
4. **One diagnosis at a time.** Don't fix multiple things simultaneously.
5. **Evolve this skill** — when you discover a novel root cause, patch it in.

---

## Quick Triage: Symptom → Most Likely Layer

| Symptom | Start With | Diagnostic Track |
|---|---|---|
| App status shows "restarting" or "unhealthy" | **Track A: Container Diagnostics** | Crash loop, health check, OOM |
| Page loads blank, 404 on refresh, assets missing | **Track B: App Content Diagnostics** | nginx config, build output, SPA routing |
| 502 Bad Gateway via domain | **Track C: Network & Traefik Diagnostics** | Traefik → container connectivity |
| 404 Not Found via domain | **Track C: Network & Traefik Diagnostics** | Traefik doesn't see container |
| App container runs but is unreachable | **Track C: Network & Traefik Diagnostics** | Network attachment, port mismatch |
| SSL warning, cert error, mixed content | **Track D: Domain & SSL Diagnostics** | Certificate renewal, Cloudflare mode |
| Build stuck or failed | **Track E: Build Pipeline Diagnostics** | Dokploy deploy queues, source code |
| Dokploy dashboard itself broken | **Track F: Dokploy Platform Diagnostics** | Dokploy container, DB, API |
| App is slow, disk full, high memory | **Track G: System Resource Diagnostics** | Disk, memory, Docker daemon |
| Database connection errors | **Track H: Database Diagnostics** | DB container, migrations, auth |
| "DNS cannot be resolved" or domain won't resolve | **Track D: Domain & SSL Diagnostics** | DNS propagation, Traefik host rules |
| Can't push/authenticate with git provider | **Track E: Build Pipeline Diagnostics** | Dokploy git provider settings, SSH keys |
| "Out of memory" or container killed | **Track A then Track G** | Swap, cgroup limits, Docker daemon OOM |
| WebSocket/disconnect errors | **Track C: Network & Traefik Diagnostics** | Sticky sessions, timeout config |
| Intermittent failures / "works sometimes" | **Track C: Network & Traefik Diagnostics** | DNS caching, container balancing, Traefik health |

---

## Track A: Container Diagnostics

Use when a container is crash-looping, unhealthy, or exits unexpectedly.

### A1. Surface-Level Status

```bash
# Show ALL containers for this project
docker ps -a --filter "name=<project-name>" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.RestartCount}}"

# Current resource usage
docker stats --no-stream --filter "name=<project-name>"
```

Key status signals:
- `Up X minutes` → running fine, look elsewhere (network/routing)
- `Up X minutes (unhealthy)` → health check failing, container works but Dokploy/Traefik won't route
- `Restarting (1) X seconds ago` → crash loop, immediate exit after start
- `Exited (N) X ago` → crashed, exited with code N

### A2. Exit Code Analysis

```bash
docker inspect <container-name> --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Error="{{.State.Error}}" Finished={{.State.FinishedAt}}'
```

| Exit Code | Meaning | Likely Cause |
|---|---|---|
| 0 | Clean exit | Stopped intentionally (compose down, app shutdown) |
| 1 | General error | App crash (check logs), CMD misconfig, missing file |
| 2 | Misuse of shell builtins | Wrong interpreter or CMD syntax |
| 126 | Command cannot execute | Permission issue, missing execute bit |
| 127 | Command not found | Wrong CMD path, missing binary in image |
| 130 | Script terminated by Ctrl+C | Manual interrupt, graceful shutdown |
| 137 | SIGKILL (128+9) | **OOM killed** by kernel — check dmesg |
| 139 | SIGSEGV (128+11) | Segfault — app bug, memory corruption |
| 143 | SIGTERM (128+15) | Docker compose down, graceful stop |
| 255 | Uncaught exception | Node.js unhandled error, Python panic |

### A3. OOM Investigation

```bash
# Check kernel OOM killer logs
dmesg | grep -i "killed process" | tail -10

# Check if container was OOM-killed
docker inspect <container> --format '{{.State.OOMKilled}}'

# Check memory limits on the container
docker inspect <container> --format '{{json .HostConfig.Memory}}'

# Check system memory pressure
free -h
cat /proc/meminfo | grep -E "MemTotal|MemAvailable|SwapTotal|SwapFree"
```

### A4. Health Check Diagnostics

```bash
# Show configured health check
docker inspect <container> --format '{{json .Config.Healthcheck}}' | jq .

# Show health check history
docker inspect <container> --format '{{json .State.Health}}' | jq .

# Manually test the health check endpoint
# First, find what the check does:
docker inspect <container> --format '{{range .Config.Healthcheck.Test}}{{.}} {{end}}'

# Then test it from inside the container:
docker exec <container> curl -sf http://127.0.0.1:<port>/<health-path> 2>&1 || echo "FAILED"
docker exec <container> wget -qO- http://127.0.0.1:<port>/<health-path> 2>&1 || echo "FAILED"
```

**Common health check pitfalls:**
- Health check points to `/health` but the app only serves `GET /` (nginx SPA)
- Health check uses `curl` but container has `wget` (or vice versa)
- Health check uses a port that doesn't match what the app listens on
- Health check interval too short for slow-starting apps
- Health check runs before DB/migration completes

### A5. Container Logs — Structured Reading

```bash
# Last 50 lines — full output
docker logs <container> --tail 50 2>&1

# Errors only (case-insensitive)
docker logs <container> --tail 200 2>&1 | grep -iE "error|fatal|panic|exception|traceback|fail"

# Startup logs — first 20 lines (crash on init)
docker logs <container> 2>&1 | head -20

# Timestamp every line (for correlating events)
docker logs <container> -t --tail 100 2>&1

# Docker daemon logs (for container-level issues)
journalctl -u docker --no-pager --since "5 minutes ago" | grep -iE "error|oom|kill|<container-name>" | tail -20
```

### A6. Restart Policy & Container Config

```bash
# Check restart policy
docker inspect <container> --format 'RestartPolicy={{.HostConfig.RestartPolicy.Name}} MaxRetries={{.HostConfig.RestartPolicy.MaximumRetryCount}}'

# Check environment variables
docker inspect <container> --format '{{json .Config.Env}}' | jq -r '.[]'

# Check mounts/volumes
docker inspect <container> --format '{{json .Mounts}}' | jq -r '.[] | "\(.Type): \(.Source or .Name) → \(.Destination)"'

# Check port mappings
docker inspect <container> --format '{{json .NetworkSettings.Ports}}' | jq .

# Check entrypoint / CMD
docker inspect <container> --format 'Entrypoint={{json .Config.Entrypoint}} CMD={{json .Config.Cmd}}'
```

Restart policies Dokploy uses:
- `always` → keep restarting forever
- `unless-stopped` → restart unless explicitly stopped
- `on-failure:N` → retry N times, then stop (crash loop detection)

---

## Track B: App Content Diagnostics

Use when the container runs but serves blank pages, 404s, or broken content. For code-level diagnostics, load `dokploy-code-assisted` — this track covers infrastructure-level content issues.

### B1. nginx Config & Build Output Check

```bash
# Find the app directory
ls /etc/dokploy/compose/ | grep -i "<app-keyword>"
APP_PATH="/etc/dokploy/compose/<project-id>/code"

# Check if nginx.conf exists
ls -la "$APP_PATH/nginx.conf" 2>/dev/null

# Read nginx.conf — check listen port, root path, try_files
cat "$APP_PATH/nginx.conf"

# Check actual build output directories
ls -la "$APP_PATH/" 2>/dev/null
ls -la "$APP_PATH/dist/" 2>/dev/null
ls -la "$APP_PATH/build/" 2>/dev/null
ls -la "$APP_PATH/web/dist/" 2>/dev/null

# Compare nginx root path with actual build output
```

### B2. Inside-Container Content Check

```bash
# Check what the container actually serves
docker exec <container> ls -la /usr/share/nginx/html/ 2>/dev/null
docker exec <container> ls -la <nginx-root> 2>/dev/null

# Check if the container is listening on the expected port
docker exec <container> ss -tlnp 2>/dev/null || docker exec <container> netstat -tlnp 2>/dev/null
```

### B3. API Service Connectivity

For full-stack apps (nginx → API → DB):

```bash
# Check proxy_pass targets in nginx
cat "$APP_PATH/nginx.conf" | grep proxy_pass

# From inside nginx container, can it reach the API?
docker exec <nginx-container> curl -sf http://<api-service>:<api-port>/health 2>&1 || echo "API UNREACHABLE"

# Check API service status
docker ps --filter "name=<api-service>" --format "{{.Names}} {{.Status}}"
```

---

## Track C: Network & Traefik Diagnostics

Use when the app container is running but unreachable via its domain.

### C1. Quick Traefik Route Check

```bash
# List all Traefik routers — does the app appear?
docker exec <dokploy-traefik-name> wget -qO- http://localhost:8080/api/http/routers 2>/dev/null | \
  jq -r '.[] | "\(.name | ljust(50)) rule=\(.rule) status=\(.status)"' 2>/dev/null

# Filter for the app
docker exec <dokploy-traefik-name> wget -qO- http://localhost:8080/api/http/routers 2>/dev/null | \
  jq -r '.[] | select(.name | test("<app-keyword>"; "i")) | .name + " → " + .rule' 2>/dev/null

# Check Traefik services
docker exec <dokploy-traefik-name> wget -qO- http://localhost:8080/api/http/services 2>/dev/null | \
  jq -r '.[] | select(.name | test("<app-keyword>"; "i")) | .name'
```

### C2. Network Attachment

```bash
# What networks is the container on?
docker inspect <container> --format '{{json .NetworkSettings.Networks}}' | jq 'keys'

# What networks is Traefik on?
docker inspect <dokploy-traefik-name> --format '{{json .NetworkSettings.Networks}}' | jq 'keys'

# Do they share a network? (Required for Traefik routing)
# Common networks: dokploy-network, <project>_default
```

### C3. Inter-Container Connectivity

```bash
# From Traefik: can it reach the container directly?
docker exec <dokploy-traefik-name> wget -qO- -T 3 http://<container-name>:<port>/ 2>&1 | head -5

# From one app container to another (for multi-service apps)
docker exec <source-container> curl -sf http://<target-service>:<port>/ 2>&1 | head -5

# DNS resolution within Docker network
docker exec <container> getent hosts <other-service-name> 2>/dev/null || \
  docker exec <container> nslookup <other-service-name> 2>/dev/null
```

### C4. Traefik Label Check

Traefik discovers containers via Docker labels. If labels are missing or wrong, Traefik won't route:

```bash
# Show all traefik-related labels
docker inspect <container> --format '{{json .Config.Labels}}' | jq 'with_entries(select(.key | startswith("traefik")))'

# Check for common issues:
# - traefik.enable=true must be present
# - traefik.http.routers.<name>.rule must match the domain
# - traefik.http.services.<name>.loadbalancer.server.port must match app port
# - Entrypoints must align (websecure for https, web for http)
```

**Common label issues:**
- `traefik.enable` missing or set to `false`
- `traefik.http.routers.<name>.rule` uses wrong hostname
- Port in `loadbalancer.server.port` doesn't match app's listen port
- Two routers with identical `rule=Host(...)` on same entrypoint (Dokploy UI template duplication)

### C5. Duplicate Router Detection

A known issue: Dokploy can create duplicate Traefik routers with the same host rule:

```bash
# Check for duplicate host rules
docker exec <dokploy-traefik-name> wget -qO- http://localhost:8080/api/http/routers 2>/dev/null | \
  jq '[group_by(.rule)[] | select(length > 1)] | .[] | {rule: .[0].rule, routers: [.[].name]}'
```

If duplicates exist, Traefik silently ignores one. The fix is to remove the duplicate label from the container's compose config or Dokploy UI.

### C6. Traefik Provider Event Miss

Known issue: Traefik's Docker provider can miss container create/start events, especially after `docker compose up -d`. Symptoms: app has valid labels but doesn't appear in Traefik router list.

```bash
# Verify Traefik sees the container
docker exec <dokploy-traefik-name> wget -qO- http://localhost:8080/api/http/routers 2>/dev/null | \
  jq -r '.[] | select(.name | test("<app>"; "i")) | .name' | head -5

# If empty despite valid labels + shared network:
echo "Fix: docker restart <dokploy-traefik-name>"
```

### C7. Traefik Logs Inspection

```bash
# Recent Traefik errors
docker logs <dokploy-traefik-name> --tail 100 2>&1 | grep -iE "error|warn|refused|timeout|not found" | tail -20

# ACME/certificate errors
docker logs <dokploy-traefik-name> --tail 200 2>&1 | grep -iE "acme|certificate|letsencrypt|challenge" | tail -10

# Route debug — what is Traefik doing with this domain?
docker logs <dokploy-traefik-name> --tail 500 2>&1 | grep -i "<domain>" | tail -20
```

### C8. Docker-Internal vs External Port Mapping

```bash
# Check if the app publishes a host port (bypasses Traefik)
docker port <container>

# Check if port is exposed (internal only — correct pattern)
docker inspect <container> --format '{{json .NetworkSettings.Ports}}' | jq .

# The correct pattern: ports are EXPOSED (internal) only, NOT published to host
# Traefik connects via the shared Docker network, not via host ports
```

### C9. Check for Port Conflicts

```bash
# What's listening on host ports?
ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null

# Check if any container is already on the port
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep "<port>"
```

---

## Track D: Domain & SSL Diagnostics

### D1. DNS Resolution

```bash
# What does the domain resolve to?
dig +short <domain> 2>/dev/null || nslookup <domain> 2>/dev/null | grep Address

# Check if it points to your server's IP
dig +short <domain> 2>/dev/null | grep -q "<server-ip>" && echo "DNS OK ✓" || echo "DNS MISMATCH ✗"
```

### D2. SSL Certificate Status

```bash
# Check cert from outside (10s timeout)
curl -svI https://<domain> --connect-timeout 10 2>&1 | grep -iE "SSL|TLS|certificate|CN|subject|issuer|expire"

# Show certificate details
echo | openssl s_client -servername <domain> -connect <domain>:443 2>/dev/null | openssl x509 -noout -dates -subject -issuer 2>/dev/null || echo "SSL HANDSHAKE FAILED"

# Check ACME cert in Traefik
cat /etc/dokploy/traefik/dynamic/acme.json 2>/dev/null | jq '.[].Certificates[] | select(.domain.main == "<domain>") | {domain, subject, notBefore, notAfter}'

# Check cert expiry from Traefik config
cat /etc/dokploy/traefik/dynamic/acme.json 2>/dev/null | jq '.[].Certificates[] | {domain: .domain.main, expires: .notAfter}' 2>/dev/null | head -20
```

### D3. Traefik Certificate Configuration

```bash
# Check if certificate is configured in Traefik
ls -la /etc/dokploy/traefik/dynamic/ 2>/dev/null | head -10

# Check the app's specific Traefik config
cat /etc/dokploy/traefik/dynamic/*.yml 2>/dev/null | grep -A 10 "<domain>"
```

### D4. Cloudflare Proxy Mode Check

If proxied through Cloudflare:

```bash
# Check if Cloudflare is proxying (look for cloudflare IPs)
dig +short <domain> 2>/dev/null

# Cloudflare IP ranges: 104.16.0.0/12, 172.64.0.0/13, etc.
# If resolves to Cloudflare IP → proxied (orange cloud)

# Check SSL/TLS mode:
# - Full (Strict): Cloudflare connects to origin via HTTPS with valid cert
# - Full: Cloudflare connects via HTTPS (allows self-signed)
# - Flexible: Cloudflare connects via HTTP — causes redirect loop with Traefik
```

**Cloudflare + Traefik redirect loop fix:**
Set Cloudflare SSL/TLS to **Full** (or Full Strict), not Flexible. Flexible sends HTTP to origin, Traefik sees HTTP and redirects to HTTPS, Cloudflare gets redirect and retries with HTTP → infinite loop.

### D5. Traefik EntryPoint Verification

```bash
# Check if Traefik is listening on 443/80
docker exec <dokploy-traefik-name> ss -tlnp 2>/dev/null | grep -E ":443|:80"

# Check entrypoints config
cat /etc/dokploy/traefik/traefik.yml 2>/dev/null | grep -A5 "entryPoints"
cat /etc/dokploy/traefik/dynamic/dokploy.yml 2>/dev/null | head -30
```

### D6. HTTP → HTTPS Redirect Check

```bash
# Test HTTP — should redirect to HTTPS
curl -sI http://<domain> --connect-timeout 10 2>&1 | head -10

# Check redirect destination location (should be https://<domain>)
curl -sI http://<domain> --connect-timeout 10 2>&1 | grep -i "^location:"
```

---

## Track E: Build Pipeline Diagnostics

### E1. Dokploy Deploy Queue

```bash
# Check stuck deployments
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/deployment.queueList" | jq .

# Clean stuck queues
curl -s -X POST -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
  -d '{}' "$DOKPLOY_URL/api/compose.cleanQueues" | jq .
```

### E2. Build Logs

```bash
# List build logs
ls -la /etc/dokploy/logs/ 2>/dev/null

# Read build log for specific app
cat /etc/dokploy/logs/<project-id>/*.log 2>/dev/null | tail -100

# Check for build errors
cat /etc/dokploy/logs/<project-id>/*.log 2>/dev/null | grep -iE "error|fail|exit code|timeout|cannot|not found" | tail -20
```

### E3. Source Code Check

```bash
# Check if source was cloned
ls -la /etc/dokploy/compose/<project-id>/code/ 2>/dev/null

# Check git status
cd /etc/dokploy/compose/<project-id>/code/ && git log --oneline -5 2>/dev/null || echo "Not a git repo or no access"
```

### E4. Build Container Inspection

If a build is running, find it:

```bash
# Dokploy uses temporary build containers
docker ps -a --filter "name=build" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}" 2>/dev/null

# Check build container logs
docker logs <build-container> --tail 100 2>&1
```

### E5. Docker Builder Cache

```bash
# Check build cache size
docker builder prune --all --force --verbose 2>&1 | grep "Total"

# Check disk space (common build failure cause)
df -h / | tail -1
```

---

## Track F: Dokploy Platform Diagnostics

### F1. Dokploy Container Health

```bash
# Is Dokploy running?
docker ps --filter "name=dokploy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Dokploy container logs
docker logs <dokploy-container> --tail 100 2>&1

# Dokploy error logs
docker logs <dokploy-container> --tail 200 2>&1 | grep -iE "error|fatal|exception|ECONNREFUSED|timeout" | tail -20
```

### F2. Dokploy Database Check

```bash
# Is postgres running?
docker ps --filter "name=dokploy-postgres" --format "{{.Names}} {{.Status}}"

# Postgres logs
docker logs <dokploy-postgres> --tail 50 2>&1

# Check postgres disk usage
docker exec <dokploy-postgres> du -sh /var/lib/postgresql/data/ 2>/dev/null || echo "Can't check — no exec access"
```

### F3. Dokploy Redis Check

```bash
# Is redis running?
docker ps --filter "name=dokploy-redis" --format "{{.Names}} {{.Status}}"

# Redis logs
docker logs <dokploy-redis> --tail 50 2>&1
```

### F4. API Connectivity Test

```bash
# Test Dokploy API directly
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/settings.health" 2>&1 | head -5

# Check API version
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/settings.getDokployVersion" 2>&1 | jq .

# Test from within docker network
docker exec <dokploy-container> wget -qO- http://localhost:3000/api/settings.health 2>/dev/null | head -3
```

### F5. Disk Space on Dokploy Data

```bash
# Dokploy data directory sizes
du -sh /etc/dokploy/ 2>/dev/null || echo "/etc/dokploy/ not found"
du -sh /etc/dokploy/logs/ 2>/dev/null
du -sh /etc/dokploy/traefik/dynamic/acme.json 2>/dev/null

# Docker data size
docker system df 2>/dev/null
```

### F6. Dokploy Version Upgrade Issues

```bash
# Current version
curl -s -H "x-api-key: $DOKPLOY_API_KEY" "$DOKPLOY_URL/api/settings.getDokployVersion" | jq .

# Check if version is recent by comparing with latest
# Some DB schema changes between versions can cause API errors
# If API errors appear after upgrade: check DB migrations
```

---

## Track G: System Resource Diagnostics

### G1. Disk Space

```bash
# Overall disk usage
df -h | grep -E "^/dev|Filesystem"

# Large Docker files
du -sh /var/lib/docker/ 2>/dev/null
du -sh /var/lib/docker/containers/ 2>/dev/null
du -sh /var/lib/docker/overlay2/ 2>/dev/null

# Log file sizes
find /var/log -name "*.log" -size +100M -exec ls -lh {} \; 2>/dev/null
du -sh /var/log/ 2>/dev/null

# Check inode usage (can fill up on small VPS)
df -i / | tail -1
```

### G2. Memory & Swap

```bash
# System memory
free -h

# Top memory consumers
ps aux --sort=-%mem | head -10

# Docker container memory
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.PIDs}}"

# Swap usage
swapon --show 2>/dev/null || echo "No swap configured"
cat /proc/sys/vm/swappiness 2>/dev/null

# Check for OOM kills
dmesg | grep -i "oom" | tail -5
```

### G3. CPU Load

```bash
# System load
uptime
cat /proc/loadavg

# Top CPU consumers
ps aux --sort=-%cpu | head -10

# Docker container CPU
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### G4. Docker Daemon Health

```bash
# Docker daemon info
docker info 2>&1 | head -30

# Docker daemon logs
journalctl -u docker --no-pager --since "1 hour ago" | grep -iE "error|fail|warn" | tail -20

# Docker events (last 60 seconds)
docker events --since 1m --until 0s 2>&1 | tail -20

# Check Docker storage driver
docker info 2>&1 | grep "Storage Driver"

# Check for Docker socket issues
ls -la /var/run/docker.sock 2>/dev/null
```

### G5. Container Restart Loop — System Impact

```bash
# Check restart count
docker inspect <crashing-container> --format '{{.RestartCount}}'

# Each restart creates a new overlay layer — can fill disk
# Check how many dead containers exist
docker ps -a --filter "status=exited" --format "{{.Names}}" | head -20

# These accumulate in Docker, old containers take minor disk
# But overlay2 layers accumulate with each build/deploy
```

---

## Track H: Database Diagnostics

### H1. Postgres Connection Check

```bash
# Is postgres running?
docker ps --filter "name=postgres" --filter "status=running" --format "{{.Names}} {{.Status}}"

# Check app → DB connectivity
docker exec <app-container> curl -sf http://<db-service>:5432/ 2>&1 | head -3
docker exec <app-container> pg_isready -h <db-service> 2>&1 || echo "pg_isready not available"

# Check DB connection env vars in app
docker inspect <app-container> --format '{{json .Config.Env}}' | jq -r '.[] | select(startswith("DATABASE") or startswith("DB_") or startswith("POSTGRES") or startswith("PG"))'
```

### H2. Postgres Logs

```bash
# App's DB container logs
docker logs <db-container> --tail 100 2>&1

# Errors only
docker logs <db-container> --tail 200 2>&1 | grep -iE "error|fatal|panic|refused|authentication|connection" | tail -20

# Connection count
docker logs <db-container> --tail 500 2>&1 | grep -c "connection" | tail -5
```

### H3. Migration Issues

```bash
# Check app logs for migration errors
docker logs <app-container> --tail 200 2>&1 | grep -iE "migration|migrate|prisma|sequelize|typeorm|knex|diesel|alembic" | tail -20

# Check if migration was interrupted (common after deploy failure)
# Check for half-applied migrations by inspecting schema
docker exec <app-db-container> psql -U <user> -d <dbname> -c "\dt" 2>/dev/null || echo "psql not available in container"

# Check last migration timestamp
docker logs <app-container> --tail 500 2>&1 | grep -iE "migration.*applied|migration.*done|migration.*complete" | tail -5
```

### H4. Database Auth Issues

```bash
# Check DB credentials in compose file
cat /etc/dokploy/compose/<project-id>/code/docker-compose.yml | grep -A5 -B5 "POSTGRES\|DATABASE_URL\|DB_HOST\|DB_PORT"

# Check if postgres is accepting connections on the right port
docker exec <db-container> ss -tlnp 2>/dev/null | grep 5432

# Check pg_hba.conf for auth method
docker exec <db-container> cat /var/lib/postgresql/data/pg_hba.conf 2>/dev/null | grep -v "^#" | grep -v "^$" | head -20
```

### H5. Database Volume Issues

```bash
# Check DB volume size
docker inspect <db-container> --format '{{json .Mounts}}' | jq -r '.[] | select(.Destination | test("postgres|data|db")) | "\(.Source or .Name) → \(.Destination)"'

# Check disk space for DB volume
docker inspect <db-container> --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' | while read src; do
  [ -n "$src" ] && du -sh "$src" 2>/dev/null
done

# Check if DB volume is full
# Postgres needs ~20% overhead beyond data size
```

---

## Track I: Comprehensive Diagnostic Workflow

Use this when you don't know where to start or the symptom is vague.

### Phase 1: Gather Everything (Read-Only)

Run all of these and report findings:

```bash
echo "=== STEP 1: Container Status ==="
docker ps --filter "name=<project>" --format "table {{.Names}}\t{{.Status}}\t{{.RestartCount}}"

echo "=== STEP 2: Network Status ==="
docker inspect <container> --format 'Networks={{json .NetworkSettings.Networks}}'

echo "=== STEP 3: Traefik Routes ==="
docker exec <dokploy-traefik-name> wget -qO- -T 3 http://localhost:8080/api/http/routers 2>/dev/null | \
  jq -r '.[] | select(.name | test("<project>"; "i")) | "\(.name) rule=\(.rule) status=\(.status)"' 2>/dev/null || echo "Traefik unreachable"

echo "=== STEP 4: Container Logs (errors) ==="
docker logs <container> --tail 200 2>&1 | grep -iE "error|fatal|panic|exception|traceback|fail" | tail -30 || echo "No errors found"

echo "=== STEP 5: Resource Usage ==="
docker stats --no-stream --filter "name=<project>" --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Phase 2: Narrow to Layer

Based on Phase 1 findings, pick the relevant Track (A-H) and continue investigation.

### Phase 3: Form Hypothesis

State clearly: "I think [component] is failing because [evidence]."

### Phase 4: Test & Fix

Make the minimal change to test the hypothesis. One change at a time. Verify after each.

### Phase 5: Verify

```bash
# Container is healthy
docker ps --filter "name=<container>" --format "{{.Names}} {{.Status}}"

# Traefik sees the route
docker exec <dokploy-traefik-name> wget -qO- -T 3 http://localhost:8080/api/http/routers 2>/dev/null | \
  jq -r '.[] | select(.name | test("<app>"; "i")) | .status'

# App responds from within network
docker exec <app-container> curl -sf http://127.0.0.1:<port>/ 2>&1 | head -3

# App responds externally
curl -sI https://<domain> 2>&1 | head -5
```

---

## When to Use

**Use this skill when:**
- An app is failing, crashing, stuck, unreachable, or behaving unexpectedly
- You need systematic diagnostics across the full stack (container → network → Traefik → DNS → SSL → DB)
- You have a specific error message and want pattern-matched root cause analysis
- Standard `dokploy-manage` inspection didn't find the issue

**Don't use this skill if:**
- You want to deploy/stop/start/manage apps → use `/dokploy-manage` or `/dokploy-deploy`
- You need deep codebase inspection (nginx.conf, Dockerfile, CLAUDE.md) → use `/dokploy-diagnose`
- You've never set up the suite → use `/dokploy` for the one-time setup guide

## Configuration

All configuration is documented in the `/dokploy` root skill. Run `skill_view(name='dokploy')` and read **Getting Started — One-Time Setup**. All values auto-detect except `DOKPLOY_API_KEY`.

You only need:

```bash
export DOKPLOY_API_KEY='your-key-here'
```

## Hard Gate — Permission & Safety

Every diagnostic command and fix requires explicit user consent. Follow this pattern:

1. **Present** what you found and what you want to check/change
2. **Show rollback** command for any proposed fix
3. **Wait** for user confirmation before running commands
4. **Backup** any file that will be modified
5. **Execute** the diagnostic or fix
6. **Verify** the result
7. **Report** the final state and rollback reference

## Rollback Quick Reference

| Action | Rollback |
|---|---|
| File edit (nginx.conf, docker-compose.yml, Dockerfile) | `cp <file>.bak.<ts> <file>` |
| Compose up/down | `docker compose -f <file> up -d` |
| Container restart | `docker restart <container>` |
| Traefik restart | `docker restart $DOKPLOY_TRAEFIK_NAME` |
| Environment variable change | Remove the added variable and re-deploy |
| Network change | `docker network disconnect <net> <container>` |

## Context-Aware Opening

When this skill loads, scan the conversation for:
- App names (any app name mentioned in context)
- Error keywords (404, 502, crash, unhealthy, timeout, blank page, restarting)

Open with:
```
Detected: <app-name> with symptom <error-keyword>.
Running structured diagnostics...
```

If no specific symptom detected:
```
No specific error detected. Running comprehensive diagnostics.
```

Auto-detect Traefik container name:

```bash
DOKPLOY_TRAEFIK_NAME="${DOKPLOY_TRAEFIK_NAME:-$(docker ps --format '{{.Names}}' | grep -i traefik | head -1)}"
DOKPLOY_COMPOSE_DIR="${DOKPLOY_COMPOSE_DIR:-/etc/dokploy/compose}"
```

---

## Common Resolution Playbook

| Diagnosis | Resolution | Track |
|---|---|---|
| Container crash loop, exit code 137 | Increase memory limit in compose, add swap | A → G |
| Health check failing | Fix health check command/path in compose | A4 |
| Traefik doesn't see container | `docker restart <traefik>` | C1, C6 |
| Duplicate Traefik routers | Remove duplicate labels from compose | C5 |
| Traefik sees but 502s | Check container port, shared network | C2, C3 |
| SSL certificate not renewing | Check acme.json, port 443 reachable from outside | D2 |
| Build stuck in queue | `compose.cleanQueues` API call | E1 |
| Build fails with "no space" | `docker builder prune`, `docker system prune` | E5, G1 |
| Disk full | `docker system prune -af`, clean logs, check overlay2 | G1 |
| OOM kills | Add memory limits, increase swap, reduce container count | A3, G2 |
| DB connection refused | Check DB container health, check app → DB network | H1 |
| Migration stuck/failed | Restart app container, check for half-applied state | H3 |
| App shows "unhealthy" but responds | Fix health check path (may not match app's endpoint) | A4 |

---

## Self-Evolution Protocol

When you discover a **novel root cause** not covered here:

1. **Document** the symptom, diagnostic commands, root cause, and fix
2. **Patch the skill**:
   ```
   skill_manage(action='patch', name='dokploy-debug',
     old_string='<existing section>',
     new_string='<existing section + new pattern>')
   ```
3. **Only add non-obvious patterns** — don't add "container not running → start it"
4. **Always include the exact command** that identifies the issue

---

## Related Skills

- **dokploy-manage** — API-based management (deploy, stop, start, delete). Load for management actions after diagnosis.
- **dokploy-code-assisted** — Application-level source code diagnostics (nginx.conf, Dockerfile, app code). Load when the issue is in application code, not infrastructure.
- **dokploy-application-management** — Graceful removal and security hardening.
- **systematic-debugging** — General debugging process (4-phase root cause investigation). Use when the symptom doesn't clearly map to any Track.

## Principles

1. **Read-only first** — gather evidence before touching anything
2. **One diagnosis at a time** — don't chase multiple failures
3. **Check the obvious first** — is the container running? Network shared? Labels correct?
4. **Logs are truth** — don't guess what the container is doing, read its logs
5. **Traefik restart is the last resort** — find why it missed the event, don't just paper over it
6. **Correlate timestamps** — when did the issue start? What changed at that time?
