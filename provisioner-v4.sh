#!/bin/bash

# Color codes for better visibility
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track script start time
SCRIPT_START=$(date +%s)

# Helper function to show elapsed time
elapsed_time() {
    local current=$(date +%s)
    local elapsed=$((current - SCRIPT_START))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    printf "%02d:%02d" $minutes $seconds
}

# Helper function for status messages
status() {
    echo -e "${BLUE}▸ [$(elapsed_time)]${NC} $1"
}

# Helper function for success messages
success() {
    echo -e "${GREEN}✓ [$(elapsed_time)]${NC} $1"
}

# Helper function for error messages
error() {
    echo -e "${RED}✗ [$(elapsed_time)]${NC} $1"
}

# Helper function for warnings
warning() {
    echo -e "${YELLOW}⚠ [$(elapsed_time)]${NC} $1"
}

# Certbot retry function
run_certbot_with_retry() {
    local domain=$1
    local account=$2
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        status "Obtaining SSL certificate (attempt $attempt/$max_attempts)..."

        if sudo certbot --nginx -d "$domain" --account "$account"; then
            success "SSL certificate obtained successfully"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                warning "Certbot failed, waiting 15 seconds before retry..."
                sleep 15
            else
                error "Certbot failed after $max_attempts attempts"
                return 1
            fi
        fi

        attempt=$((attempt + 1))
    done
}

# Parse arguments
TEMPLATE="new"  # Default template
while getopts "n:d:t:" opt; do
  case $opt in
    n) APP_NAME="$OPTARG" ;;
    d) APP_DESCRIPTION="$OPTARG" ;;
    t) TEMPLATE="$OPTARG" ;;
  esac
done

# Validate required arguments
if [ -z "$APP_NAME" ]; then
    error "Usage: $0 -n <app_name> [-d <app_description>] [-t <template>]"
    echo "  -n <app_name>        : Application name (required)"
    echo "  -d <app_description> : Description for Claude AI customization (optional)"
    echo "  -t <template>        : Template name (default: 'new')"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Next.js App Provisioner v4                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show mode
if [ -z "$APP_DESCRIPTION" ]; then
    status "Starting provisioning for: $APP_NAME (template: $TEMPLATE) [SCAFFOLD ONLY - No Claude]"
else
    status "Starting provisioning for: $APP_NAME (template: $TEMPLATE) [WITH Claude AI]"
fi
echo ""

# Load .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

# Step 1: Find available port and generate UUID early
status "Finding available port..."
APP_PORT=$(for port in {27032..65535}; do ss -tuln | grep -q ":$port " || { echo $port; break; }; done)
success "Assigned port: $APP_PORT"

UNIQUE_SESSION_UUID=$(cat /proc/sys/kernel/random/uuid)
status "Generated session UUID: $UNIQUE_SESSION_UUID"

# Step 2: Create Cloudflare DNS record FIRST (gives it time to propagate)
status "Creating Cloudflare DNS record (early for propagation time)..."
curl -X POST https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records \
    -H "Authorization: Bearer $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"type\": \"A\", \"name\": \"$APP_NAME.$DEFAULT_DOMAIN\", \"content\": \"$SERVER_PUBLIC_IP\", \"ttl\": 0, \"proxied\": false}" \
    > /dev/null 2>&1
success "DNS record created (propagating in background)"

# Step 3: Create Next.js app
if [ "$TEMPLATE" = "new" ]; then
    status "Creating Next.js application from scratch..."
    cd /var/www/
    npx -y create-next-app@latest "$APP_NAME" --ts --tailwind --eslint --app --src-dir --yes
    success "Next.js application created"
else
    status "Creating Next.js application from template: $TEMPLATE"

    # Check if template exists
    if [ ! -d "$SCRIPT_DIR/templates/$TEMPLATE" ]; then
        error "Template '$TEMPLATE' not found in $SCRIPT_DIR/templates/"
        exit 1
    fi

    # Copy template to destination
    cp -r "$SCRIPT_DIR/templates/$TEMPLATE" "/var/www/$APP_NAME"
    cd "/var/www/$APP_NAME"
    success "Next.js application created from template: $TEMPLATE"
fi

# Step 4: Initialize Git
status "Initializing Git repository..."
cd /var/www/"$APP_NAME"
git init
git add . && git commit -m "build: initial commit"
git branch -m master main
success "Git repository initialized"

# Step 5: Create .env file
status "Creating environment configuration..."
cat > .env << EOF
APP_NAME=$APP_NAME
PORT=$APP_PORT
EOF
success "Environment configured"

# Step 6: Install dependencies & create GitHub repo in parallel
status "Installing dependencies and creating GitHub repo in parallel..."

npm install &
NPM_PID=$!

gh repo create "$APP_NAME" --public --source=. --remote=origin --push &
GH_PID=$!

wait $NPM_PID
success "Dependencies installed"

wait $GH_PID
success "GitHub repository created"

# Step 7: Build the application and prepare nginx in parallel
status "Building Next.js application (this may take 30-40 seconds)..."

npm run build &
BUILD_PID=$!

# Nginx config (backgrounded)
(
    sudo cp /etc/nginx/base.config /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{appName}/$APP_NAME/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{appPort}/$APP_PORT/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{SERVER_PUBLIC_IP}/$SERVER_PUBLIC_IP/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
) &
NGINX_PID=$!

# Wait for both to complete
wait $BUILD_PID
success "Next.js build completed"

wait $NGINX_PID
success "Nginx configuration prepared"

# Step 8: Start PM2 process
status "Starting PM2 process..."
PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run start
success "Application started on port $APP_PORT"

# Step 9: Test and restart nginx
status "Testing and restarting nginx..."
sudo nginx -t && sudo systemctl restart nginx
success "Nginx configured and restarted"

# Step 10: Obtain SSL certificate (NO WAIT - DNS has had time to propagate)
status "DNS has been propagating during setup - attempting SSL now..."
run_certbot_with_retry "$APP_NAME.$DEFAULT_DOMAIN" "$CERTBOT_ACCOUNT_ID"

# Step 11: Restart nginx after SSL
status "Restarting nginx with SSL configuration..."
sudo nginx -t && sudo systemctl restart nginx
success "Nginx restarted with SSL"

# Step 12: Run Claude AI customization (only if description provided)
if [ -n "$APP_DESCRIPTION" ]; then
    status "Running Claude AI customization (this may take 2-3 minutes)..."
    echo -e "${YELLOW}   Claude is now designing and implementing your landing page...${NC}"
    CLAUDE_START=$(date +%s)

    claude -p "Please configure this base site to be a landing page for $APP_NAME an $APP_DESCRIPTION. Run 'npm run lint' and type checking to verify everything works, but DO NOT run 'npm run build' as that will be done separately after. Just ensure the code is correct and lint passes." \
        --model claude-haiku-4-5-20251001 \
        --session-id "$UNIQUE_SESSION_UUID" \
        --dangerously-skip-permissions \
        --output-format=json

    CLAUDE_END=$(date +%s)
    CLAUDE_DURATION=$((CLAUDE_END - CLAUDE_START))
    success "Claude AI customization completed in ${CLAUDE_DURATION}s"

    # Step 13: Rebuild and restart
    status "Rebuilding application with Claude's changes..."
    pm2 stop $APP_NAME
    npm run build
    pm2 start $APP_NAME
    success "Application rebuilt and restarted"

    # Step 14: Commit and push changes
    status "Committing and pushing changes to GitHub..."
    git add . && git commit -m "build: post claude one shot" && git push
    success "Changes pushed to GitHub"
else
    warning "Skipping Claude AI customization (no description provided)"
    warning "Application is ready but has default/template content"
fi

# Calculate total time
SCRIPT_END=$(date +%s)
TOTAL_DURATION=$((SCRIPT_END - SCRIPT_START))
TOTAL_MINUTES=$((TOTAL_DURATION / 60))
TOTAL_SECONDS=$((TOTAL_DURATION % 60))

# Final Analysis Report
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              PROVISIONING COMPLETE!                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📊 Deployment Summary:${NC}"
echo -e "   ${GREEN}✓${NC} Application: $APP_NAME"
echo -e "   ${GREEN}✓${NC} Template: $TEMPLATE"
echo -e "   ${GREEN}✓${NC} Website URL: ${GREEN}https://$APP_NAME.$DEFAULT_DOMAIN${NC}"
echo -e "   ${GREEN}✓${NC} GitHub Repo: ${GREEN}https://github.com/$(gh api user --jq .login)/$APP_NAME${NC}"
echo -e "   ${GREEN}✓${NC} Port: $APP_PORT"
echo -e "   ${GREEN}✓${NC} Total Time: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s"

# Show Claude session info only if Claude was run
if [ -n "$APP_DESCRIPTION" ]; then
    echo ""
    echo -e "${BLUE}🤖 Claude Session:${NC}"
    echo -e "   ${GREEN}✓${NC} Session UUID: ${YELLOW}$UNIQUE_SESSION_UUID${NC}"
    echo -e "   ${BLUE}ℹ${NC}  Continue customizing: ${YELLOW}claude --resume $UNIQUE_SESSION_UUID${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠  Claude Customization:${NC}"
    echo -e "   ${YELLOW}⚠${NC}  Skipped (no description provided)"
    echo -e "   ${BLUE}ℹ${NC}  To customize later: ${YELLOW}claude --session-id $UNIQUE_SESSION_UUID${NC}"
fi

echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo -e "   1. Visit your site: ${GREEN}https://$APP_NAME.$DEFAULT_DOMAIN${NC}"

if [ -n "$APP_DESCRIPTION" ]; then
    echo -e "   2. Continue with Claude: ${YELLOW}claude --resume $UNIQUE_SESSION_UUID${NC}"
    echo -e "   3. View logs: ${YELLOW}pm2 logs $APP_NAME${NC}"
else
    echo -e "   2. Customize your site: ${YELLOW}cd /var/www/$APP_NAME${NC}"
    echo -e "   3. View logs: ${YELLOW}pm2 logs $APP_NAME${NC}"
fi
echo ""
