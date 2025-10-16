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
if [ -z "$APP_NAME" ] || [ -z "$APP_DESCRIPTION" ]; then
    error "Usage: $0 -n <app_name> -d <app_description> [-t <template>]"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Next.js App Provisioner v2                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
status "Starting provisioning for: $APP_NAME (template: $TEMPLATE)"
echo ""

# Load .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

# Step 1: Create Next.js app
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

# Step 2: Initialize Git
status "Initializing Git repository..."
cd /var/www/"$APP_NAME"
git init
git add . && git commit -m "build: initial commit"
git branch -m master main
success "Git repository initialized"

# Step 3: Create GitHub repository
status "Creating GitHub repository..."
gh repo create "$APP_NAME" --public --source=. --remote=origin --push
success "GitHub repository created"

# Step 4: Find available port
status "Finding available port..."
APP_PORT=$(for port in {27032..65535}; do ss -tuln | grep -q ":$port " || { echo $port; break; }; done)
success "Assigned port: $APP_PORT"

# Step 5: Generate session UUID
UNIQUE_SESSION_UUID=$(cat /proc/sys/kernel/random/uuid)
status "Generated session UUID: $UNIQUE_SESSION_UUID"

# Step 6: Create .env file
status "Creating environment configuration..."
cat > .env << EOF
APP_NAME=$APP_NAME
PORT=$APP_PORT
EOF
success "Environment configured"

# Step 7: Install dependencies
status "Installing dependencies..."
npm install
success "Dependencies installed"

# Step 8: Build the application (this takes time)
status "Building Next.js application (this may take 2-3 minutes)..."

# Run build in background and capture PID
npm run build &
BUILD_PID=$!

# While build is running, prepare nginx config and DNS in parallel
status "Preparing nginx configuration and DNS record in parallel..."

# Nginx config (backgrounded)
(
    sudo cp /etc/nginx/base.config /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{appName}/$APP_NAME/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{appPort}/$APP_PORT/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{SERVER_PUBLIC_IP}/$SERVER_PUBLIC_IP/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
) &
NGINX_PID=$!

# Cloudflare DNS record (backgrounded)
(
    curl -X POST https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records \
        -H "Authorization: Bearer $CLOUDFLARE_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"type\": \"A\", \"name\": \"$APP_NAME.$DEFAULT_DOMAIN\", \"content\": \"$SERVER_PUBLIC_IP\", \"ttl\": 0, \"proxied\": false}" \
        > /dev/null 2>&1
) &
DNS_PID=$!

# Wait for build to complete first
wait $BUILD_PID
success "Next.js build completed"

# Wait for nginx and DNS tasks
wait $NGINX_PID
success "Nginx configuration prepared"

wait $DNS_PID
success "DNS record created"

# Step 9: Start PM2 process
status "Starting PM2 process..."
PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run start
success "Application started on port $APP_PORT"

# Step 10: Test and restart nginx
status "Testing and restarting nginx..."
sudo nginx -t && sudo systemctl restart nginx
success "Nginx configured and restarted"

# Step 11: Wait for DNS propagation
status "Waiting 30 seconds for DNS propagation..."
sleep 30
success "DNS propagation wait complete"

# Step 12: Obtain SSL certificate with retry logic
run_certbot_with_retry "$APP_NAME.$DEFAULT_DOMAIN" "$CERTBOT_ACCOUNT_ID"

# Step 13: Restart nginx after SSL
status "Restarting nginx with SSL configuration..."
sudo nginx -t && sudo systemctl restart nginx
success "Nginx restarted with SSL"

# Step 14: Run Claude AI customization (this takes time)
status "Running Claude AI customization (this may take 3-5 minutes)..."
echo -e "${YELLOW}   Claude is now designing and implementing your landing page...${NC}"
CLAUDE_START=$(date +%s)

claude -p "Please configure this base site to be a landing page for $APP_NAME an $APP_DESCRIPTION, perform a npm run build and clear any errors before calling this complete" \
    --model claude-haiku-4-5-20251001 \
    --session-id "$UNIQUE_SESSION_UUID" \
    --dangerously-skip-permissions \
    --output-format=json

CLAUDE_END=$(date +%s)
CLAUDE_DURATION=$((CLAUDE_END - CLAUDE_START))
success "Claude AI customization completed in ${CLAUDE_DURATION}s"

# Step 15: Rebuild and restart
status "Rebuilding application with Claude's changes..."
pm2 stop $APP_NAME
npm run build
pm2 start $APP_NAME
success "Application rebuilt and restarted"

# Step 16: Commit and push changes
status "Committing and pushing changes to GitHub..."
git add . && git commit -m "build: post claude one shot" && git push
success "Changes pushed to GitHub"

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
echo ""
echo -e "${BLUE}🤖 Claude Session:${NC}"
echo -e "   ${GREEN}✓${NC} Session UUID: ${YELLOW}$UNIQUE_SESSION_UUID${NC}"
echo -e "   ${BLUE}ℹ${NC}  Continue customizing: ${YELLOW}claude --resume $UNIQUE_SESSION_UUID${NC}"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo -e "   1. Visit your site: ${GREEN}https://$APP_NAME.$DEFAULT_DOMAIN${NC}"
echo -e "   2. Continue with Claude: ${YELLOW}claude --resume $UNIQUE_SESSION_UUID${NC}"
echo -e "   3. View logs: ${YELLOW}pm2 logs $APP_NAME${NC}"
echo ""
