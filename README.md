# Next.js App Provisioner

Automated deployment system for Next.js applications with Claude AI integration, SSL certificates, and full infrastructure setup.

## Prerequisites

**System Dependencies:**
```bash
# Install Node.js & npm
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2
sudo npm install -g pm2

# Install Nginx
sudo apt-get install -y nginx

# Install Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Install jq
sudo apt-get install -y jq

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh

# Install Claude CLI
npm install -g @anthropic-ai/claude-code-cli
```

**Authentication:**
```bash
# GitHub
gh auth login

# Claude
claude auth login

# Certbot (run once to register)
sudo certbot register --email your@email.com
```

**Nginx Template:**
The repository includes `base.config` with placeholders: `{appName}`, `{appPort}`, `{SERVER_PUBLIC_IP}`

## Configuration

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Configure `.env`:
   ```bash
   # Domain & DNS (must match)
   DEFAULT_DOMAIN=your-domain.com
   CLOUDFLARE_ZONE_ID=your_zone_id

   # Server
   SERVER_PUBLIC_IP=your_server_ip

   # API Keys
   CLOUDFLARE_API_KEY=your_api_key
   CERTBOT_ACCOUNT_ID=your_account_id

   # Claude Models (pre-configured)
   CLAUDE_MODEL_HAIKU=claude-haiku-4-5-20251001
   CLAUDE_MODEL_SONNET=claude-sonnet-4-5-20250929
   CLAUDE_MODEL_OPUS=claude-opus-4-1-20250805
   ```

3. Get Cloudflare credentials:
   - Zone ID: Dashboard → Domain → Zone ID (right sidebar)
   - API Key: Profile → API Tokens → Create Token (Zone.DNS Edit)

4. Get Certbot account ID:
   ```bash
   sudo ls /etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory/
   ```

## Usage

### 1. Provision New App (`provisioner.sh`)

**Basic (scaffold only):**
```bash
./provisioner.sh -n "my-app"
```

**With Claude customization:**
```bash
./provisioner.sh -n "my-app" -d "a portfolio site for a developer"
```

**Options:**
- `-n <name>` : App name (required, becomes subdomain)
- `-d <desc>` : Claude AI description (optional)
- `-t <template>` : Template from `./templates/` (default: "new")
- `-m <mode>` : "prod" or "dev" (default: "prod")
- `-c <model>` : "haiku", "sonnet", or "opus" (default: "haiku")

**Examples:**
```bash
# Production with Claude Sonnet
./provisioner.sh -n "portfolio" -d "creative portfolio" -c "sonnet"

# Development mode (hot reload, no build)
./provisioner.sh -n "test-app" -m "dev"

# From template
./provisioner.sh -n "blog" -t "nextjs-spark" -d "personal blog"
```

**Creates:**
- Next.js app at `/var/www/<name>`
- DNS: `<name>.your-domain.com`
- SSL certificate (auto-renewed)
- PM2 process
- GitHub repository
- Nginx reverse proxy
- Claude session (stored in `data/uuid.json`)

**Time:** 3-5 minutes (with Claude), 1-2 minutes (scaffold only)

### 2. Update Existing App (`site-update.sh`)

**Basic:**
```bash
./site-update.sh -n "my-app" -p "add a contact form"
```

**Options:**
- `-n <name>` : App name (required)
- `-p <prompt>` : Claude prompt (required)
- `-s <uuid>` : Session UUID (optional, auto-lookup from data store)
- `-c <model>` : "haiku", "sonnet", or "opus" (default: "haiku")

**Examples:**
```bash
# Simple update
./site-update.sh -n "portfolio" -p "change hero section to dark theme"

# With different model
./site-update.sh -n "blog" -p "add SEO meta tags" -c "sonnet"

# Manual UUID override
./site-update.sh -n "app" -s "uuid-here" -p "fix mobile layout"
```

### 3. Remove App (`unprovision.sh`)

**Interactive:**
```bash
./unprovision.sh -n "my-app"
```

**Flags:**
- `-n <name>` : App name (required)
- `-g` : Skip GitHub deletion
- `-y` : Auto-accept (GitHub still requires confirmation)

**Examples:**
```bash
# Normal removal (prompts for GitHub)
./unprovision.sh -n "old-app"

# Keep GitHub repo
./unprovision.sh -n "archive-app" -g

# Auto-accept (except GitHub)
./unprovision.sh -n "temp-app" -y
```

**Removes:**
- PM2 process
- Nginx configuration
- SSL certificate
- Cloudflare DNS record
- Application directory
- UUID from data store
- GitHub repository (if confirmed)

## Directory Structure

```
/opt/provisioner/
├── provisioner.sh       # Main provisioning script
├── site-update.sh       # Update existing apps
├── unprovision.sh       # Remove apps
├── base.config          # Nginx template
├── .env                 # Configuration (gitignored)
├── .env.example         # Template
├── bkups/               # Old script versions (gitignored)
├── data/
│   └── uuid.json        # Session UUID storage
└── templates/           # Custom Next.js templates
    └── nextjs-spark/
```

## Notes

- **Ports:** Auto-assigned from 27032-65535
- **DNS:** Subdomain format `<app-name>.<domain>`
- **SSL:** Auto-renewed by certbot
- **Sessions:** UUIDs persist in `data/uuid.json` for easy updates
- **Dev Mode:** Skips builds, uses hot reload (`npm run dev`)
- **Prod Mode:** Builds app, uses `npm start`
- **Templates:** Place custom Next.js projects in `./templates/`
- **Concurrency:** DNS, npm install, and repo creation run in parallel
- **Retries:** SSL obtains retry 3x with 15s delays

## Troubleshooting

**DNS propagation fails:**
- Check Cloudflare Zone ID matches domain
- Verify API key has DNS edit permissions
- Wait 60s and retry manually

**SSL fails:**
- Ensure DNS propagated: `dig <app-name>.<domain>`
- Check certbot account: `sudo certbot certificates`
- Verify port 80/443 open in firewall

**Claude errors:**
- Check authentication: `claude auth status`
- Verify model ID in `.env`
- Session limit: 200k tokens

**Port conflicts:**
- Check PM2 list: `pm2 list`
- Find port usage: `ss -tuln | grep <port>`

## Maintenance

**Update Claude models:**
Edit `.env` when new versions release:
```bash
CLAUDE_MODEL_HAIKU=claude-haiku-4-5-YYYYMMDD
```

**View sessions:**
```bash
cat data/uuid.json | jq
```

**Manual Claude resume:**
```bash
cd /var/www/<app-name>
claude --resume <uuid>
```
