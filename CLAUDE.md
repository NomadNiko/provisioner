# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Next.js App Provisioner - A two-part system for automated deployment of Next.js applications with Claude AI integration, SSL certificates, and full infrastructure setup.

**Architecture:**
- **Bash Scripts** (`/opt/provisioner`): Core provisioning logic that manages app lifecycle
- **REST API** (`/var/www/provisioner`): TypeScript/Express API that exposes provisioning operations via HTTP endpoints

## Key Commands

### Development

```bash
# API Development (in /var/www/provisioner)
cd /var/www/provisioner
npm run build          # Compile TypeScript to dist/
npm run dev            # Run with ts-node (development)
npm start              # Run compiled code (production)

# View API logs
pm2 logs provisioner-api
pm2 restart provisioner-api
```

### Testing Provisioning Scripts

```bash
# From /opt/provisioner

# Test provision (without Claude)
./provisioner.sh -n "test-app"

# Test provision with Claude
./provisioner.sh -n "test-app" -d "a portfolio site" -c "haiku"

# Test update
./site-update.sh -n "test-app" -p "add a contact form"

# Test unprovision (cleanup)
./unprovision.sh -n "test-app"
```

## Architecture

### Two-Directory Structure

1. **`/opt/provisioner`** (Scripts repository - current working directory)
   - Contains bash scripts (`provisioner.sh`, `site-update.sh`, `unprovision.sh`)
   - Environment configuration (`.env`)
   - Templates for Next.js apps (`templates/`)
   - Session UUID storage (`data/uuid.json`)
   - Nginx configuration template (`base.config`)

2. **`/var/www/provisioner`** (API repository - additional working directory)
   - TypeScript/Express REST API
   - Job management system (creates/tracks async jobs)
   - Spawns bash scripts from `/opt/provisioner`
   - Serves static frontend from `public/`
   - Stores job state in `jobs/` directory (ephemeral)
   - Stores completed job logs in `logs/` directory

### How They Work Together

```
User → REST API (Express) → ScriptRunner → Bash Scripts → Provisioned Apps
        /var/www/provisioner              /opt/provisioner    /var/www/<app-name>
```

1. API receives HTTP request (`POST /api/provision` or `/api/update`)
2. Creates Job record with UUID
3. `ScriptRunner` spawns bash script with `spawn()` from `/opt/provisioner`
4. Script output streams to job's output array
5. On completion, job finalized and saved to logs
6. Client polls `GET /api/status/:jobId` for progress

### Service Layer Architecture

**JobManager** (`/var/www/provisioner/src/services/JobManager.ts`)
- Creates/reads/updates jobs (stored as JSON files in `jobs/`)
- Queues operations per job to prevent race conditions
- Tracks job status: `pending` → `running` → `completed`/`failed`
- Cleans up orphaned jobs on API restart

**ScriptRunner** (`/var/www/provisioner/src/services/ScriptRunner.ts`)
- Spawns bash scripts using `child_process.spawn()`
- Uses `stdio: ['inherit', 'pipe', 'pipe']` to prevent Claude CLI hangs
- Streams stdout/stderr to JobManager
- Saves completed jobs to LogManager

**LockManager** (`/var/www/provisioner/src/services/LockManager.ts`)
- Prevents concurrent updates to same app (file-based locks)
- Used by update operations only (provision doesn't need locking)

**AppManager** (`/var/www/provisioner/src/services/AppManager.ts`)
- Lists all provisioned apps by reading `data/uuid.json`
- Checks PM2 status, reads .env files for port numbers
- Integrates with LogManager for latest job history

**LogManager** (`/var/www/provisioner/src/services/LogManager.ts`)
- Persists completed jobs as timestamped JSON files in `logs/<appName>/`
- Provides job history for apps

### Routes

- `POST /api/provision` - Creates new Next.js app
- `POST /api/update` - Updates existing app with Claude
- `GET /api/status/:jobId` - Poll job progress
- `GET /api/apps` - List all apps
- `GET /api/apps/:name` - Get app details

## Important Technical Details

### Bash Script Parameters

**provisioner.sh:**
- `-n <name>` (required): App name, becomes subdomain
- `-d <description>` (optional): Claude AI prompt for customization
- `-t <template>` (optional): Template from `templates/` (default: "new")
- `-m <mode>` (optional): "prod" or "dev" (default: "prod")
- `-c <claude_model>` (optional): "haiku", "sonnet", "opus" (default: "haiku")

**site-update.sh:**
- `-n <name>` (required): App name
- `-p <prompt>` (required): Claude prompt
- `-s <session_uuid>` (optional): Session UUID (auto-lookup from `data/uuid.json`)
- `-c <claude_model>` (optional): Claude model choice

**unprovision.sh:**
- `-n <name>` (required): App name
- `-g` (optional): Skip GitHub deletion
- `-y` (optional): Auto-accept prompts

### Environment Variables

Located at `/opt/provisioner/.env`:
- `DEFAULT_DOMAIN` - Base domain for subdomains
- `CLOUDFLARE_ZONE_ID` - Must match DEFAULT_DOMAIN's zone
- `SERVER_PUBLIC_IP` - Public IP for DNS records
- `CLOUDFLARE_API_KEY` - API token with DNS edit permissions
- `CERTBOT_ACCOUNT_ID` - Account ID from `/etc/letsencrypt/accounts/`
- `CLAUDE_MODEL_HAIKU/SONNET/OPUS` - Model IDs (update as new models release)

API environment at `/var/www/provisioner/.env`:
- `PORT` - API port (default: 27032)
- `SCRIPTS_PATH` - Path to provisioner scripts (default: `/opt/provisioner`)

### Provisioning Flow

1. Find available port (27032-65535)
2. Generate session UUID
3. Create Cloudflare DNS record (starts propagating)
4. Create Next.js app (from scratch or template)
5. Initialize git repo
6. Create `.env` file with PORT
7. **Parallel**: npm install + GitHub repo creation
8. **Parallel** (prod only): Build app + Configure nginx
9. Start PM2 process (`npm start` or `npm run dev`)
10. Test and restart nginx
11. Obtain SSL certificate (retries 3x)
12. If description provided: Run Claude CLI
13. If Claude ran and prod mode: Rebuild + restart
14. Commit and push to GitHub

### Claude CLI Integration

Scripts use Claude CLI with specific flags:
- `--model` - Model ID from .env
- `--session-id` or `--resume` - Session UUID
- `--dangerously-skip-permissions` - Auto-approve tool use
- `--output-format=json` - Structured output
- `< /dev/null` redirects stdin to prevent hangs when spawned from Node.js

Session UUIDs stored in `/opt/provisioner/data/uuid.json`:
```json
{
  "app-name": "uuid-here"
}
```

### Common Patterns

**Reading the environment:**
```bash
source "$SCRIPT_DIR/.env"
```

**Mapping user-friendly names to model IDs:**
```bash
case "$CLAUDE_MODEL_CHOICE" in
    haiku) CLAUDE_MODEL_ID="$CLAUDE_MODEL_HAIKU" ;;
    sonnet) CLAUDE_MODEL_ID="$CLAUDE_MODEL_SONNET" ;;
    opus) CLAUDE_MODEL_ID="$CLAUDE_MODEL_OPUS" ;;
esac
```

**Job queuing to prevent race conditions:**
The JobManager queues operations per job ID to ensure file operations don't conflict.

**Stdio configuration for spawned scripts:**
Use `stdio: ['inherit', 'pipe', 'pipe']` to inherit stdin but pipe stdout/stderr. This prevents Claude CLI from hanging (see ScriptRunner.ts:70).

## Debugging Tips

**API not starting:**
```bash
pm2 logs provisioner-api  # Check for errors
pm2 restart provisioner-api
```

**Script failures:**
- Check job output in `/var/www/provisioner/jobs/<jobId>.json`
- Check logs in `/var/www/provisioner/logs/<appName>/`
- Run script manually: `cd /opt/provisioner && ./provisioner.sh -n "test"`

**Claude hangs:**
- Ensure stdin redirected: `< /dev/null`
- Check session exists: `cat data/uuid.json`
- Verify authentication: `claude auth status`

**DNS/SSL issues:**
- Verify propagation: `dig <app>.domain.com`
- Check Cloudflare zone ID matches domain
- Certbot retries 3x automatically with 15s delays

## Making Changes

### Modifying Bash Scripts

1. **Test changes locally first** with a test app
2. Use `-m dev` mode to skip builds during testing
3. The scripts use parallel execution (`&` and `wait`) - be careful with dependencies
4. Always update README.md if changing parameters

### Modifying the API

1. Make changes in `/var/www/provisioner/src/`
2. Build: `npm run build`
3. Restart: `pm2 restart provisioner-api`
4. Check logs: `pm2 logs provisioner-api`

**Before editing any file, read the entire file first** (per user's global instructions).

### Adding New Templates

1. Create directory in `/opt/provisioner/templates/<name>`
2. Add a valid Next.js project structure
3. Test: `./provisioner.sh -n "test" -t "<name>"`

## File Locations Reference

- Apps deployed to: `/var/www/<app-name>/`
- Nginx configs: `/etc/nginx/sites-enabled/<app-name>.<domain>`
- SSL certs: `/etc/letsencrypt/live/<app-name>.<domain>/`
- PM2 process list: `pm2 list`
- Job state (ephemeral): `/var/www/provisioner/jobs/`
- Job logs (persistent): `/var/www/provisioner/logs/`
- Session UUIDs: `/opt/provisioner/data/uuid.json`
