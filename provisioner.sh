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
TEMPLATE="new"           # Default template
MODE="prod"              # Default mode
while getopts "n:t:m:" opt; do
  case $opt in
    n) APP_NAME="$OPTARG" ;;
    t) TEMPLATE="$OPTARG" ;;
    m) MODE="$OPTARG" ;;
  esac
done

# Validate required arguments
if [ -z "$APP_NAME" ]; then
    error "Usage: $0 -n <app_name> [-t <template>] [-m <mode>]"
    echo "  -n <app_name> : Application name (required)"
    echo "  -t <template> : Template name (default: 'new')"
    echo "  -m <mode>     : Mode - 'prod' or 'dev' (default: 'prod')"
    exit 1
fi

# Validate mode
if [ "$MODE" != "prod" ] && [ "$MODE" != "dev" ]; then
    error "Invalid mode: $MODE. Must be 'prod' or 'dev'"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Next.js App Provisioner                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show mode
MODE_DISPLAY=$([ "$MODE" = "dev" ] && echo "DEV MODE" || echo "PRODUCTION MODE")
status "Starting provisioning for: $APP_NAME (template: $TEMPLATE) [$MODE_DISPLAY]"
echo ""

# Load .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

# Step 1: Find available port
status "Finding available port..."
APP_PORT=$(for port in {27032..65535}; do ss -tuln | grep -q ":$port " || { echo $port; break; }; done)
success "Assigned port: $APP_PORT"

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
elif [ "$TEMPLATE" = "react" ]; then
    status "Creating React application with React Router..."
    cd /var/www/
    npx -y create-react-router@latest "$APP_NAME"
    cd "$APP_NAME"

    # Configure Vite to allow all hosts (for reverse proxy)
    status "Configuring Vite for reverse proxy..."
    cat > vite.config.ts << EOF
import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  server: {
    host: true,
    allowedHosts: [".$DEFAULT_DOMAIN"]
  },
  plugins: [tailwindcss(), reactRouter(), tsconfigPaths()],
});
EOF
    success "React application created and configured"
elif [ "$TEMPLATE" = "saas" ]; then
    status "Creating SaaS application from GitHub repository..."
    cd /var/www/
    git clone https://github.com/NomadNiko/saas-starter "$APP_NAME"
    cd "$APP_NAME"
    # Remove the cloned .git directory to start fresh
    rm -rf .git
    success "SaaS starter cloned from GitHub"
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

if [ "$TEMPLATE" = "saas" ]; then
    # Generate secure AUTH_SECRET
    AUTH_SECRET=$(openssl rand -hex 32)

    # Read MongoDB URI template from .env and replace placeholder
    # Use grep to get the raw line without bash variable expansion
    MONGODB_URI_TEMPLATE=$(grep "^MONGODB_URI=" "$SCRIPT_DIR/.env" | cut -d '=' -f 2-)
    MONGODB_URI_REPLACED="${MONGODB_URI_TEMPLATE//\{\$APP_NAME\}/$APP_NAME}"

    status "Generating SaaS environment with MongoDB and Stripe integration..."
    cat > .env << EOF
APP_NAME=$APP_NAME
PORT=$APP_PORT

# Base URL
BASE_URL=https://$APP_NAME.$DEFAULT_DOMAIN

# Authentication Secret (generated securely)
AUTH_SECRET=$AUTH_SECRET

# MongoDB Connection
MONGODB_URI=$MONGODB_URI_REPLACED

# Stripe Configuration
STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET
EOF
    success "SaaS environment configured with MongoDB and Stripe"
else
    cat > .env << EOF
APP_NAME=$APP_NAME
PORT=$APP_PORT
EOF
    success "Environment configured"
fi

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

# Step 7: Build the application (prod only) and prepare nginx in parallel
if [ "$MODE" = "prod" ]; then
    status "Building Next.js application (this may take 30-40 seconds)..."

    npm run build &
    BUILD_PID=$!

    # Nginx config (backgrounded)
    (
        sudo cp "$SCRIPT_DIR/base.config" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
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
else
    status "Skipping build (dev mode) - preparing nginx configuration..."

    sudo cp "$SCRIPT_DIR/base.config" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{appName}/$APP_NAME/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{appPort}/$APP_PORT/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{SERVER_PUBLIC_IP}/$SERVER_PUBLIC_IP/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN

    success "Nginx configuration prepared"
fi

# Step 7.5: Seed database for SaaS template
if [ "$TEMPLATE" = "saas" ]; then
    status "Seeding database for SaaS template..."
    npm run db:seed
    success "Database seeded successfully"
fi

# Step 8: Start PM2 process
if [ "$TEMPLATE" = "react" ]; then
    # React Router apps: dev mode uses --port flag, prod mode uses PORT env var
    if [ "$MODE" = "prod" ]; then
        status "Starting PM2 process (production mode)..."
        PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run start
        success "Application started on port $APP_PORT (production)"
    else
        status "Starting PM2 process (development mode)..."
        pm2 start npm --name "$APP_NAME" -- run dev -- --port $APP_PORT
        success "Application started on port $APP_PORT (development with hot reload)"
    fi
else
    # Next.js and other apps use PORT env var
    if [ "$MODE" = "prod" ]; then
        status "Starting PM2 process (production mode)..."
        PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run start
        success "Application started on port $APP_PORT (production)"
    else
        status "Starting PM2 process (development mode)..."
        PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run dev
        success "Application started on port $APP_PORT (development with hot reload)"
    fi
fi

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
echo -e "   ${GREEN}✓${NC} Mode: $([ "$MODE" = "dev" ] && echo "${YELLOW}Development (hot reload)${NC}" || echo "${GREEN}Production${NC}")"
echo -e "   ${GREEN}✓${NC} Website URL: ${GREEN}https://$APP_NAME.$DEFAULT_DOMAIN${NC}"
echo -e "   ${GREEN}✓${NC} GitHub Repo: ${GREEN}https://github.com/$(gh api user --jq .login)/$APP_NAME${NC}"
echo -e "   ${GREEN}✓${NC} Port: $APP_PORT"
echo -e "   ${GREEN}✓${NC} Total Time: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s"

echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo -e "   1. Visit your site: ${GREEN}https://$APP_NAME.$DEFAULT_DOMAIN${NC}"
echo -e "   2. Customize your site: ${YELLOW}cd /var/www/$APP_NAME${NC}"
echo -e "   3. View logs: ${YELLOW}pm2 logs $APP_NAME${NC}"
echo ""
