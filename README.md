# Next.js App Provisioner

Automated deployment system for scaffolding Next.js applications with SSL certificates and full infrastructure setup.

> **Note:** Claude AI integration has been removed due to system stability issues. This provisioner now focuses on rapid Next.js project scaffolding.

## Table of Contents

- [Quick Start](#quick-start)
- [Server Setup (First Time)](#server-setup-first-time)
- [Configuration](#configuration)
- [Usage](#usage)
- [REST API](#rest-api)
- [Directory Structure](#directory-structure)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
- [Migration Guide](#migration-from-claude-integrated-version)

## Quick Start

If you're setting up on a fresh server:

```bash
# 1. Clone the repository
git clone <your-repo-url> /opt/provisioner
cd /opt/provisioner

# 2. Run automated setup
chmod +x setup.sh
./setup.sh

# 3. Follow the manual configuration prompts
# (GitHub auth, Certbot registration, Cloudflare API keys, .env configuration)

# 4. Test your setup
./provisioner.sh -n "test-app" -m "dev"
./unprovision.sh -n "test-app" -y
```

## Server Setup (First Time)

### Automated Setup Script

The `setup.sh` script automates most of the installation process:

```bash
./setup.sh
```

**What it does automatically:**
- ✅ Installs Node.js LTS
- ✅ Installs PM2 process manager
- ✅ Installs and configures Nginx
- ✅ Installs Certbot (Let's Encrypt)
- ✅ Installs jq (JSON processor)
- ✅ Installs GitHub CLI
- ✅ Creates directory structure
- ✅ Creates `.env` template
- ✅ Configures PM2 startup service

**What requires manual action:**
- 🔐 GitHub authentication
- 🔐 Certbot/Let's Encrypt registration
- 🔐 Cloudflare API token creation
- ⚙️ `.env` file configuration

### Manual Prerequisites

After running `setup.sh`, complete these steps:

#### 1. GitHub Authentication

```bash
gh auth login
```

- Choose: **GitHub.com**
- Protocol: **HTTPS**
- Authenticate: **Login with a web browser** (recommended)
- Follow the browser prompts to authenticate

Verify:
```bash
gh auth status
```

#### 2. Certbot Registration

Register with Let's Encrypt:

```bash
sudo certbot register --email your@email.com
```

- Replace `your@email.com` with your actual email
- Accept the Terms of Service when prompted

Get your account ID:
```bash
sudo ls /etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory/
```

Copy the directory name (e.g., `abc123def456...`) - this is your `CERTBOT_ACCOUNT_ID`.

#### 3. Cloudflare Configuration

You need two pieces of information:

**a) Zone ID:**
1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select your domain
3. Zone ID is shown in the right sidebar (under "API")
4. Copy this value

**b) API Token:**
1. Go to: Profile → [API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use template: **"Edit zone DNS"**
4. Configure:
   - Permissions: `Zone - DNS - Edit`
   - Zone Resources: `Include - Specific zone - [Your domain]`
5. Click "Continue to summary" → "Create Token"
6. **Copy the token immediately** (you won't see it again)

## Configuration

### Environment Variables

Edit `.env` with your actual values:

```bash
nano /opt/provisioner/.env
```

Required configuration:

```bash
# Domain & DNS Configuration (must match your Cloudflare domain)
DEFAULT_DOMAIN=your-domain.com
CLOUDFLARE_ZONE_ID=your_zone_id_from_cloudflare

# Server Configuration
SERVER_PUBLIC_IP=your_server_public_ip

# API Keys
CLOUDFLARE_API_KEY=your_cloudflare_api_token
CERTBOT_ACCOUNT_ID=your_certbot_account_id
```

**How to get each value:**

| Variable | Where to Find |
|----------|---------------|
| `DEFAULT_DOMAIN` | Your domain name (e.g., `example.com`) |
| `CLOUDFLARE_ZONE_ID` | Cloudflare Dashboard → Domain → Zone ID (right sidebar) |
| `SERVER_PUBLIC_IP` | Run: `curl ifconfig.me` |
| `CLOUDFLARE_API_KEY` | Created in Cloudflare API Tokens (see above) |
| `CERTBOT_ACCOUNT_ID` | From certbot registration (see above) |

### Nginx Template

The `base.config` file is a template used for all apps. It includes placeholders:
- `{appName}` - Replaced with your app name
- `{appPort}` - Replaced with assigned port
- `{SERVER_PUBLIC_IP}` - Replaced with your server IP

**No need to edit this file manually** - the provisioner handles it automatically.

### Optional: REST API Setup

If you want the web interface and REST API:

```bash
# Navigate to API directory
cd /var/www/provisioner

# Install dependencies
npm install

# Build TypeScript
npm run build

# Create .env for API
echo "PORT=27032" > .env
echo "SCRIPTS_PATH=/opt/provisioner" >> .env

# Start with PM2
PORT=27032 pm2 start dist/index.js --name provisioner-api

# Save PM2 configuration
pm2 save
```

Access the web interface at: `http://your-server-ip:27032`

## Usage

### 1. Provision New App

**Basic usage (default template, production mode):**
```bash
./provisioner.sh -n "my-app"
```

**All options:**
```bash
./provisioner.sh -n "app-name" -t "template" -m "mode"
```

**Parameters:**
- `-n <name>` : **Required** - App name (becomes subdomain)
  - Must be lowercase letters, numbers, and hyphens
  - Must start with a letter
  - Examples: `my-app`, `portfolio`, `blog-2024`
- `-t <template>` : Optional - Template from `./templates/` (default: `new`)
  - `new` - Fresh Next.js app with TypeScript + Tailwind
  - `nextjs-slidex` - Landing page template
  - `nextjs-portfolio` - Portfolio template
  - `nextjs-saasly` - SaaS template
  - Or any custom template in `./templates/`
- `-m <mode>` : Optional - Deployment mode (default: `prod`)
  - `prod` - Production mode (builds and optimizes)
  - `dev` - Development mode (hot reload, no build)

**Examples:**

```bash
# Production app with default template
./provisioner.sh -n "my-portfolio"

# Development mode (fast, with hot reload)
./provisioner.sh -n "test-app" -m "dev"

# Production with custom template
./provisioner.sh -n "landing-page" -t "nextjs-slidex"

# Dev mode with template (fastest for testing)
./provisioner.sh -n "quick-test" -t "nextjs-portfolio" -m "dev"
```

**What gets created:**
- ✅ Next.js app at `/var/www/<name>`
- ✅ DNS record: `<name>.your-domain.com`
- ✅ SSL certificate (auto-renewed by certbot)
- ✅ PM2 process (auto-starts on server reboot)
- ✅ GitHub repository (public)
- ✅ Nginx reverse proxy configuration

**Provisioning time:**
- Dev mode: ~30-40 seconds
- Prod mode: ~1-2 minutes

### 2. Update Existing App (DEPRECATED)

The `site-update.sh` script has been **deprecated** due to stability issues with Claude integration.

**To update your applications manually:**

```bash
# 1. Navigate to your app
cd /var/www/<app-name>

# 2. Make your changes
# Edit files, add features, etc.

# 3. For dev mode apps (automatic reload)
npm run dev  # Already running, just save files

# 4. For production apps
npm run build
pm2 restart <app-name>

# 5. Commit and push
git add .
git commit -m "your changes"
git push
```

### 3. Remove App (Unprovision)

**Interactive (with prompts):**
```bash
./unprovision.sh -n "my-app"
```

**Flags:**
- `-n <name>` : **Required** - App name to remove
- `-g` : Skip GitHub repository deletion (keep repo)
- `-y` : Auto-accept prompts (GitHub still requires confirmation)

**Examples:**

```bash
# Normal removal (prompts before each action)
./unprovision.sh -n "old-app"

# Keep GitHub repo, remove everything else
./unprovision.sh -n "archive-app" -g

# Auto-accept all prompts (except GitHub deletion)
./unprovision.sh -n "temp-app" -y

# Fast cleanup with repo preservation
./unprovision.sh -n "test-app" -g -y
```

**What gets removed:**
- ✅ PM2 process (stops and deletes)
- ✅ Nginx configuration
- ✅ SSL certificate
- ✅ Cloudflare DNS record
- ✅ Application directory (all code and files)
- ⚠️ GitHub repository (only if confirmed)

**Unprovision time:** ~5-10 seconds

## REST API

The provisioner includes an optional REST API for programmatic access and a web interface.

### API Setup

```bash
cd /var/www/provisioner
npm install
npm run build
PORT=27032 pm2 start dist/index.js --name provisioner-api
pm2 save
```

### Endpoints

**Base URL:** `http://localhost:27032/api`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/templates` | List available templates |
| GET | `/apps` | List all deployed applications |
| GET | `/apps/:name` | Get details for specific app |
| GET | `/apps/:name/logs` | Get job history for app |
| POST | `/provision` | Create new application |
| POST | `/unprovision` | Remove application |
| GET | `/status/:jobId` | Get job status |
| POST | `/update` | **DEPRECATED** (returns 410 Gone) |

### Example API Usage

**Provision a new app:**
```bash
curl -X POST http://localhost:27032/api/provision \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "template": "new",
    "mode": "prod"
  }'
```

**Response:**
```json
{
  "jobId": "uuid-here",
  "status": "pending",
  "message": "Provisioning 'my-app' started"
}
```

**Check job status:**
```bash
curl http://localhost:27032/api/status/<jobId>
```

**List all apps:**
```bash
curl http://localhost:27032/api/apps | jq
```

**Web Interface:**
Access at `http://your-server:27032` for a visual control panel.

## Directory Structure

```
/opt/provisioner/              # Scripts repository (this repo)
├── provisioner.sh             # Main provisioning script
├── unprovision.sh             # App removal script
├── site-update.sh             # DEPRECATED (shows deprecation message)
├── setup.sh                   # Server setup automation script
├── base.config                # Nginx configuration template
├── .env                       # Your configuration (gitignored)
├── .env.example               # Configuration template
├── setup.log                  # Setup script log (created after setup)
├── data/                      # Runtime data (gitignored)
├── bkups/                     # Old backups (gitignored)
└── templates/                 # Next.js templates
    ├── nextjs-slidex/         # Landing page template
    ├── nextjs-portfolio/      # Portfolio template
    └── nextjs-saasly/         # SaaS template

/var/www/provisioner/          # API repository (optional)
├── src/                       # TypeScript source
│   ├── routes/                # API route handlers
│   ├── services/              # Business logic
│   └── types/                 # TypeScript type definitions
├── dist/                      # Compiled JavaScript (gitignored)
├── public/                    # Web interface (static files)
│   └── index.html            # Control panel UI
├── jobs/                      # Active job state (ephemeral, gitignored)
├── logs/                      # Completed job logs (gitignored)
├── package.json              # Dependencies
└── tsconfig.json             # TypeScript configuration

/var/www/<app-name>/           # Each provisioned app
├── app/                       # Next.js app directory
├── components/                # React components
├── public/                    # Static assets
├── .next/                     # Next.js build output (prod only)
├── node_modules/              # Dependencies
├── .env                       # App-specific environment
├── package.json              # App dependencies
└── next.config.mjs           # Next.js configuration

/etc/nginx/sites-enabled/      # Nginx configurations
└── <app-name>.<domain>        # Each app's reverse proxy config

/etc/letsencrypt/live/         # SSL certificates
└── <app-name>.<domain>/       # Each app's SSL cert
```

## System Details

### Port Assignment
- Automatically assigned from range: `27032-65535`
- Scans for first available port
- Stored in app's `.env` file as `PORT`

### DNS Configuration
- Subdomain format: `<app-name>.<your-domain.com>`
- Created via Cloudflare API
- A record pointing to `SERVER_PUBLIC_IP`
- TTL: Auto

### SSL Certificates
- Automatically obtained from Let's Encrypt
- Auto-renewed by certbot (every 60 days)
- Renewal happens in background via systemd timer
- Retries 3x with 15s delays if DNS not propagated

### PM2 Process Management
- Production mode: `npm start` (uses built files)
- Development mode: `npm run dev` (with Turbopack)
- Auto-restart on crashes
- Starts on server reboot (via PM2 startup)
- Logs: `pm2 logs <app-name>`

### Deployment Modes

**Production Mode (`-m prod`):**
- Runs `npm run build` (creates optimized bundle)
- Starts with `npm start`
- Slower provisioning (~1-2 min)
- Fast page loads
- Ready for production traffic

**Development Mode (`-m dev`):**
- Skips build step
- Starts with `npm run dev`
- Very fast provisioning (~30-40 sec)
- Hot reload enabled
- On-demand compilation
- Perfect for active development

### Parallel Operations

The provisioner runs these operations in parallel for speed:
1. **During provision:**
   - npm install + GitHub repo creation
   - npm build + nginx configuration (prod mode)

2. **DNS propagation:**
   - DNS record created early
   - Propagates while other tasks run
   - SSL attempt after setup completes

## Troubleshooting

### DNS Propagation Fails

**Symptoms:**
- Certbot fails with "DNS challenge failed"
- Cannot resolve `<app>.your-domain.com`

**Solutions:**
```bash
# Check if DNS record was created
curl -s "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_KEY" | jq '.result[] | select(.name | contains("app-name"))'

# Verify DNS propagation
dig <app-name>.your-domain.com

# Wait 60 seconds and retry SSL manually
cd /var/www/<app-name>
sudo certbot --nginx -d <app-name>.your-domain.com --account $CERTBOT_ACCOUNT_ID
```

**Common causes:**
- ❌ Wrong Cloudflare Zone ID (must match domain)
- ❌ Cloudflare API token missing DNS edit permission
- ❌ Domain not managed by Cloudflare

### SSL Certificate Fails

**Symptoms:**
- "Certificate request failed" after 3 retries
- Nginx shows "certificate not found"

**Solutions:**
```bash
# Check DNS is propagated first
dig <app-name>.your-domain.com +short
# Should return your SERVER_PUBLIC_IP

# Verify port 80/443 are open
sudo ufw status
# Should show 80/tcp and 443/tcp ALLOW

# Try manual SSL
sudo certbot --nginx -d <app-name>.your-domain.com

# Check certbot account exists
sudo certbot certificates
```

**Common causes:**
- ❌ DNS not propagated yet (wait 60-120 seconds)
- ❌ Firewall blocking ports 80/443
- ❌ Wrong certbot account ID
- ❌ Nginx configuration error

### Port Already in Use

**Symptoms:**
- Error: "Address already in use"
- PM2 process won't start

**Solutions:**
```bash
# Find what's using the port
sudo ss -tuln | grep <port-number>

# Kill the process
sudo kill <pid>

# Or restart the provisioning (it will find next available port)
```

### Build Failures (Production Mode)

**Symptoms:**
- "Build failed" during provisioning
- PM2 process starts but app shows errors

**Solutions:**
```bash
# Check build logs
cd /var/www/<app-name>
npm run build

# Check PM2 logs
pm2 logs <app-name>

# Common issues:
# - Missing dependencies: npm install
# - TypeScript errors: check code syntax
# - Environment variables: check .env

# Switch to dev mode if stuck
pm2 stop <app-name>
pm2 delete <app-name>
PORT=<port> pm2 start npm --name <app-name> -- run dev
```

### GitHub Authentication Expired

**Symptoms:**
- "GitHub repo creation failed"
- "authentication required"

**Solutions:**
```bash
# Re-authenticate
gh auth login

# Verify status
gh auth status

# Test connection
gh repo list
```

### Nginx Configuration Errors

**Symptoms:**
- "nginx: configuration test failed"
- 502 Bad Gateway

**Solutions:**
```bash
# Test nginx configuration
sudo nginx -t

# View detailed errors
sudo nginx -t 2>&1

# Check app is running
pm2 list
pm2 logs <app-name>

# Restart nginx
sudo systemctl restart nginx

# Check nginx logs
sudo tail -f /var/log/nginx/error.log
```

## Maintenance

### Update API

```bash
cd /var/www/provisioner
git pull
npm install
npm run build
pm2 restart provisioner-api
```

### View All Deployed Apps

```bash
# List PM2 processes
pm2 list

# Detailed status
pm2 status

# With API running
curl http://localhost:27032/api/apps | jq
```

### Manual App Management

```bash
# Restart an app
pm2 restart <app-name>

# Stop an app
pm2 stop <app-name>

# Start a stopped app
pm2 start <app-name>

# View real-time logs
pm2 logs <app-name>

# View last 100 lines
pm2 logs <app-name> --lines 100

# Clear logs
pm2 flush <app-name>

# Monitor resource usage
pm2 monit
```

### Backup and Restore

**Backup a provisioned app:**
```bash
# Create backup
sudo tar -czf ~/backups/<app-name>-$(date +%Y%m%d).tar.gz \
  /var/www/<app-name> \
  /etc/nginx/sites-enabled/<app-name>.* \
  /etc/letsencrypt/live/<app-name>.*

# Save PM2 state
pm2 save
```

**Restore an app:**
```bash
# Extract backup
sudo tar -xzf ~/backups/<app-name>-date.tar.gz -C /

# Restart PM2
pm2 resurrect

# Reload nginx
sudo nginx -s reload
```

### Update System Packages

```bash
# Update apt packages
sudo apt update
sudo apt upgrade -y

# Update Node.js (if new LTS available)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Update global npm packages
sudo npm update -g

# Update PM2
sudo npm install -g pm2@latest
pm2 update
```

### SSL Certificate Renewal

Certificates auto-renew, but you can manually force renewal:

```bash
# Test renewal (dry run)
sudo certbot renew --dry-run

# Force renewal for specific domain
sudo certbot renew --force-renewal -d <app-name>.your-domain.com

# Renew all certificates
sudo certbot renew
```

## Migration from Claude-Integrated Version

If you were using the previous version with Claude integration:

### What Changed

1. ✅ **Existing apps continue to work** - No changes needed for already-deployed applications
2. ❌ **Session UUIDs removed** - The `data/uuid.json` file is no longer used
3. ❌ **Update endpoint deprecated** - Use manual development workflow instead
4. ✅ **Frontend simplified** - Claude-related UI fields removed from control panel
5. ✅ **Faster provisioning** - No more 2-5 minute Claude sessions
6. ✅ **More stable** - No system crashes from Claude CLI hangs

### Migration Steps

**No action required!** Your existing apps will continue running normally.

If you want to update the system:

```bash
# 1. Pull latest changes
cd /opt/provisioner
git pull

# 2. Update API (if using)
cd /var/www/provisioner
git pull
npm install
npm run build
pm2 restart provisioner-api

# 3. Test new provisioning
cd /opt/provisioner
./provisioner.sh -n "test-migration" -m "dev"
./unprovision.sh -n "test-migration" -y
```

## Advanced Usage

### Custom Templates

Create your own templates in `./templates/`:

```bash
# 1. Create template directory
mkdir -p templates/my-custom-template

# 2. Add a Next.js project (can be existing project)
cd templates/my-custom-template
# Copy your Next.js project files here

# 3. Use in provisioning
./provisioner.sh -n "new-app" -t "my-custom-template"
```

**Template requirements:**
- Must be a valid Next.js project
- Must have `package.json`
- Should have `npm run dev` and `npm run build` scripts
- Can include any custom dependencies

### Environment Variables per App

Each app has its own `.env` file at `/var/www/<app-name>/.env`:

```bash
# Edit app environment
nano /var/www/<app-name>/.env

# Add custom variables
DATABASE_URL=postgresql://...
API_KEY=your-key-here

# Restart app to apply
pm2 restart <app-name>
```

### Custom Nginx Configuration

To customize nginx for a specific app:

```bash
# Edit the app's nginx config
sudo nano /etc/nginx/sites-enabled/<app-name>.your-domain.com

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### Multiple Domains/Subdomains

The provisioner creates: `<app-name>.<DEFAULT_DOMAIN>`

For custom domains:

```bash
# 1. Provision normally
./provisioner.sh -n "myapp"

# 2. Add custom domain to nginx
sudo nano /etc/nginx/sites-enabled/myapp.your-domain.com
# Add: server_name custom-domain.com;

# 3. Get SSL for custom domain
sudo certbot --nginx -d custom-domain.com

# 4. Reload nginx
sudo systemctl reload nginx
```

## License

MIT

## Credits

Built with:
- [Next.js](https://nextjs.org/) - React framework
- [PM2](https://pm2.keymetrics.io/) - Process manager
- [Nginx](https://nginx.org/) - Web server
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates
- [Cloudflare](https://www.cloudflare.com/) - DNS management
- [GitHub CLI](https://cli.github.com/) - Repository management
