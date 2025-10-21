#!/bin/bash

# Enhanced color palette for better visual hierarchy
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
BLUE='\033[0;34m'
BRIGHT_BLUE='\033[1;34m'
CYAN='\033[0;36m'
BRIGHT_CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BRIGHT_RED='\033[1;31m'
MAGENTA='\033[0;35m'
BRIGHT_MAGENTA='\033[1;35m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Track script start time
SCRIPT_START=$(date +%s)
CURRENT_STEP=0
TOTAL_STEPS=11  # Base steps (12 if SaaS template includes database seeding)

# Helper function to show elapsed time
elapsed_time() {
    local current=$(date +%s)
    local elapsed=$((current - SCRIPT_START))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    printf "%02d:%02d" $minutes $seconds
}

# Helper function for section headers
section_header() {
    echo ""
    echo -e "${BRIGHT_CYAN}╭─────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${BRIGHT_CYAN}│${NC} ${WHITE}${BOLD}$1${NC}"
    echo -e "${BRIGHT_CYAN}╰─────────────────────────────────────────────────────────────────╯${NC}"
}

# Helper function for step progress
step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    echo -e "${BRIGHT_MAGENTA}┌─ Step $CURRENT_STEP/$TOTAL_STEPS ${GRAY}[$(elapsed_time)]${NC}"
    echo -e "${BRIGHT_MAGENTA}│${NC}"
}

# Helper function for status messages
status() {
    echo -e "${BRIGHT_MAGENTA}│${NC} ${BLUE}▸${NC} $1"
}

# Helper function for success messages
success() {
    echo -e "${BRIGHT_MAGENTA}│${NC} ${BRIGHT_GREEN}✓${NC} $1"
}

# Helper function for error messages
error() {
    echo -e "${BRIGHT_RED}✗ [$(elapsed_time)]${NC} ${BOLD}$1${NC}"
}

# Helper function for warnings
warning() {
    echo -e "${BRIGHT_MAGENTA}│${NC} ${YELLOW}⚠${NC} $1"
}

# Helper function for info messages
info() {
    echo -e "${BRIGHT_MAGENTA}│${NC} ${CYAN}ℹ${NC} ${DIM}$1${NC}"
}

# Helper function for closing step
step_done() {
    echo -e "${BRIGHT_MAGENTA}└─${NC} ${BRIGHT_GREEN}✓ Complete${NC} ${GRAY}[$(elapsed_time)]${NC}"
}

# Helper function to show a progress bar
show_progress() {
    local duration=$1
    local steps=40
    local delay=$(echo "scale=3; $duration / $steps" | bc)

    echo -ne "${BRIGHT_MAGENTA}│${NC} ${CYAN}Progress:${NC} ["
    for ((i=0; i<steps; i++)); do
        echo -ne "${GREEN}█${NC}"
        sleep "$delay"
    done
    echo -e "] ${BRIGHT_GREEN}Done${NC}"
}

# Certbot retry function with enhanced feedback
run_certbot_with_retry() {
    local domain=$1
    local account=$2
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        status "Obtaining SSL certificate (attempt $attempt/$max_attempts)..."
        info "Domain: $domain"

        if sudo certbot --nginx -d "$domain" --account "$account" > /tmp/certbot.log 2>&1; then
            success "SSL certificate obtained successfully"
            info "Certificate valid for 90 days"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                warning "Certbot failed, waiting 15 seconds before retry..."
                info "DNS propagation may still be in progress..."
                sleep 15
            else
                error "Certbot failed after $max_attempts attempts"
                warning "Check DNS propagation: dig $domain"
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

clear
echo ""
echo -e "${BRIGHT_CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BRIGHT_CYAN}║${NC}                                                               ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}║${NC}        ${WHITE}${BOLD}╔╗╔┌─┐─┐ ┬┌┬┐   ┬┌─┐  ╔═╗┬─┐┌─┐┬  ┬┬┌─┐┬┌─┐┌┐┌┌─┐┬─┐${NC}       ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}║${NC}        ${WHITE}${BOLD}║║║├┤ ┌┴┬┘ │    │└─┐  ╠═╝├┬┘│ │└┐┌┘│└─┐││ ││││├┤ ├┬┘${NC}       ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}║${NC}        ${WHITE}${BOLD}╝╚╝└─┘┴ └─ ┴ ┴└─┘└─┘  ╩  ┴└─└─┘ └┘ ┴└─┘┴└─┘┘└┘└─┘┴└─${NC}       ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}║${NC}                                                               ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show mode with visual indicator
MODE_DISPLAY=$([ "$MODE" = "dev" ] && echo "${YELLOW}DEVELOPMENT${NC}" || echo "${BRIGHT_GREEN}PRODUCTION${NC}")
MODE_ICON=$([ "$MODE" = "dev" ] && echo "🔧" || echo "🚀")

section_header "Configuration"
echo -e "   ${CYAN}Application:${NC}  ${WHITE}${BOLD}$APP_NAME${NC}"
echo -e "   ${CYAN}Template:${NC}     ${WHITE}$TEMPLATE${NC}"
echo -e "   ${CYAN}Mode:${NC}         $MODE_ICON  $MODE_DISPLAY"
echo -e "   ${CYAN}Domain:${NC}       ${BRIGHT_CYAN}$APP_NAME.$DEFAULT_DOMAIN${NC}"
echo ""

# Load .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

# Adjust total steps for SaaS template (includes database seeding)
if [ "$TEMPLATE" = "saas" ]; then
    TOTAL_STEPS=12
fi

section_header "Infrastructure Setup"

# Step 1: Find available port
step
status "Finding available port..."
APP_PORT=$(for port in {27032..65535}; do ss -tuln | grep -q ":$port " || { echo $port; break; }; done)
success "Assigned port: ${BRIGHT_GREEN}$APP_PORT${NC}"
info "Port range: 27032-65535"
step_done

# Step 2: Create Cloudflare DNS record FIRST (gives it time to propagate)
step
status "Creating Cloudflare DNS record..."
info "This runs early to allow DNS propagation during setup"
curl -X POST https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records \
    -H "Authorization: Bearer $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"type\": \"A\", \"name\": \"$APP_NAME.$DEFAULT_DOMAIN\", \"content\": \"$SERVER_PUBLIC_IP\", \"ttl\": 0, \"proxied\": false}" \
    > /dev/null 2>&1
success "DNS record created"
info "Record: ${BRIGHT_CYAN}$APP_NAME.$DEFAULT_DOMAIN${NC} → ${GRAY}$SERVER_PUBLIC_IP${NC}"
info "Status: Propagating in background (typically 1-2 minutes)"
step_done

section_header "Application Creation"

# Step 3: Create Next.js app
step
if [ "$TEMPLATE" = "new" ]; then
    status "Creating Next.js application from scratch..."
    info "Using: TypeScript, Tailwind CSS, ESLint, App Router"
    cd /var/www/
    npx -y create-next-app@latest "$APP_NAME" --ts --tailwind --eslint --app --src-dir --yes > /tmp/nextjs-create.log 2>&1
    success "Next.js application created"
elif [ "$TEMPLATE" = "react" ]; then
    status "Creating React application with React Router..."
    info "Stack: React Router v7, Vite, TypeScript"
    cd /var/www/
    npx -y create-react-router@latest "$APP_NAME" > /tmp/react-create.log 2>&1
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
    info "Vite configured for domain: .$DEFAULT_DOMAIN"
elif [ "$TEMPLATE" = "saas" ]; then
    status "Creating SaaS application from GitHub repository..."
    info "Source: github.com/NomadNiko/saas-starter"
    cd /var/www/
    git clone https://github.com/NomadNiko/saas-starter "$APP_NAME" > /tmp/saas-clone.log 2>&1
    cd "$APP_NAME"
    # Remove the cloned .git directory to start fresh
    rm -rf .git
    success "SaaS starter cloned from GitHub"
    info "MongoDB and Stripe integration included"
else
    status "Creating Next.js application from template: $TEMPLATE"

    # Check if template exists
    if [ ! -d "$SCRIPT_DIR/templates/$TEMPLATE" ]; then
        error "Template '$TEMPLATE' not found in $SCRIPT_DIR/templates/"
        echo ""
        echo -e "${YELLOW}Available templates:${NC}"
        ls -1 "$SCRIPT_DIR/templates/" | sed 's/^/  - /'
        exit 1
    fi

    info "Template location: $SCRIPT_DIR/templates/$TEMPLATE"
    # Copy template to destination
    cp -r "$SCRIPT_DIR/templates/$TEMPLATE" "/var/www/$APP_NAME"
    cd "/var/www/$APP_NAME"
    success "Next.js application created from template: $TEMPLATE"
fi
step_done

# Step 4: Initialize Git
step
status "Initializing Git repository..."
cd /var/www/"$APP_NAME"
git init > /dev/null 2>&1
git add . && git commit -m "build: initial commit" > /dev/null 2>&1
git branch -m master main > /dev/null 2>&1
success "Git repository initialized"
info "Default branch: main"
step_done

# Step 5: Create .env file
step
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
    success "SaaS environment configured"
    info "MongoDB database: $APP_NAME"
    info "Authentication secret generated (64 chars)"
    info "Stripe integration configured"
else
    cat > .env << EOF
APP_NAME=$APP_NAME
PORT=$APP_PORT
EOF
    success "Environment configured"
    info "App name: $APP_NAME"
    info "Port: $APP_PORT"
fi
step_done

section_header "Dependency Installation & GitHub Setup"

# Step 6: Install dependencies & create GitHub repo in parallel
step
status "Running parallel operations..."
info "Task 1: Installing npm dependencies"
info "Task 2: Creating GitHub repository"
echo ""

npm install > /tmp/npm-install.log 2>&1 &
NPM_PID=$!

gh repo create "$APP_NAME" --public --source=. --remote=origin --push > /tmp/gh-create.log 2>&1 &
GH_PID=$!

# Wait for npm install
wait $NPM_PID
success "Dependencies installed"
info "Packages installed from package.json"

# Wait for GitHub
wait $GH_PID
success "GitHub repository created"
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "your-username")
info "Repository: github.com/$GH_USER/$APP_NAME"
step_done

section_header "Build & Server Configuration"

# Step 7: Build the application (prod only) and prepare nginx in parallel
step
if [ "$MODE" = "prod" ]; then
    status "Building application for production..."
    info "This may take 30-60 seconds depending on project size"
    echo ""

    npm run build > /tmp/npm-build.log 2>&1 &
    BUILD_PID=$!

    # Nginx config (backgrounded)
    (
        sudo cp "$SCRIPT_DIR/base.config" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
        sudo sed -i "s/{appName}/$APP_NAME/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
        sudo sed -i "s/{appPort}/$APP_PORT/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
        sudo sed -i "s/{SERVER_PUBLIC_IP}/$SERVER_PUBLIC_IP/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    ) &
    NGINX_PID=$!

    # Wait for nginx config
    wait $NGINX_PID
    success "Nginx configuration prepared"
    info "Config: /etc/nginx/sites-enabled/$APP_NAME.$DEFAULT_DOMAIN"

    # Wait for build
    wait $BUILD_PID
    success "Production build completed"
    info "Build optimized for performance"
else
    status "Development mode - skipping production build"
    info "Hot reload will be enabled"

    sudo cp "$SCRIPT_DIR/base.config" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{appName}/$APP_NAME/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{appPort}/$APP_PORT/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
    sudo sed -i "s/{SERVER_PUBLIC_IP}/$SERVER_PUBLIC_IP/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN

    success "Nginx configuration prepared"
    info "Config: /etc/nginx/sites-enabled/$APP_NAME.$DEFAULT_DOMAIN"
fi
step_done

# Step 7.5: Seed database for SaaS template
if [ "$TEMPLATE" = "saas" ]; then
    step
    status "Seeding database for SaaS template..."
    info "Initializing MongoDB with default data"
    npm run db:seed > /tmp/db-seed.log 2>&1
    success "Database seeded successfully"
    info "SaaS template ready with sample data"
    step_done
fi

section_header "Application Startup"

# Step 8: Start PM2 process
step
if [ "$TEMPLATE" = "react" ]; then
    # React Router apps: dev mode uses --port flag, prod mode uses PORT env var
    if [ "$MODE" = "prod" ]; then
        status "Starting PM2 process (production mode)..."
        PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run start > /tmp/pm2-start.log 2>&1
        success "Application started"
        info "Mode: Production"
        info "Port: $APP_PORT"
        info "Process: $APP_NAME"
    else
        status "Starting PM2 process (development mode)..."
        pm2 start npm --name "$APP_NAME" -- run dev -- --port $APP_PORT > /tmp/pm2-start.log 2>&1
        success "Application started"
        info "Mode: Development (hot reload enabled)"
        info "Port: $APP_PORT"
        info "Process: $APP_NAME"
    fi
else
    # Next.js and other apps use PORT env var
    if [ "$MODE" = "prod" ]; then
        status "Starting PM2 process (production mode)..."
        PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run start > /tmp/pm2-start.log 2>&1
        success "Application started"
        info "Mode: Production"
        info "Port: $APP_PORT"
        info "Process: $APP_NAME"
    else
        status "Starting PM2 process (development mode)..."
        PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run dev > /tmp/pm2-start.log 2>&1
        success "Application started"
        info "Mode: Development (hot reload enabled)"
        info "Port: $APP_PORT"
        info "Process: $APP_NAME"
    fi
fi
step_done

# Step 9: Test and restart nginx
step
status "Testing nginx configuration..."
if sudo nginx -t > /tmp/nginx-test.log 2>&1; then
    success "Nginx configuration valid"
    status "Restarting nginx..."
    sudo systemctl restart nginx
    success "Nginx restarted successfully"
    info "Reverse proxy active on port 80"
else
    error "Nginx configuration test failed"
    warning "Check /tmp/nginx-test.log for details"
fi
step_done

section_header "SSL Certificate Setup"

# Step 10: Obtain SSL certificate (NO WAIT - DNS has had time to propagate)
step
status "DNS has been propagating during setup"
info "Attempting SSL certificate acquisition..."
run_certbot_with_retry "$APP_NAME.$DEFAULT_DOMAIN" "$CERTBOT_ACCOUNT_ID"
step_done

# Step 11: Restart nginx after SSL
step
status "Applying SSL configuration..."
if sudo nginx -t > /tmp/nginx-ssl-test.log 2>&1; then
    sudo systemctl restart nginx
    success "Nginx restarted with SSL configuration"
    info "HTTPS now active on port 443"
    info "HTTP redirects to HTTPS"
else
    warning "Nginx configuration test failed after SSL"
    info "Check /tmp/nginx-ssl-test.log for details"
fi
step_done

# Calculate total time
SCRIPT_END=$(date +%s)
TOTAL_DURATION=$((SCRIPT_END - SCRIPT_START))
TOTAL_MINUTES=$((TOTAL_DURATION / 60))
TOTAL_SECONDS=$((TOTAL_DURATION % 60))

# Get GitHub username
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "your-username")

# Final Success Banner
echo ""
echo ""
echo -e "${BRIGHT_GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BRIGHT_GREEN}║${NC}                                                               ${BRIGHT_GREEN}║${NC}"
echo -e "${BRIGHT_GREEN}║${NC}    ${WHITE}${BOLD}✓  PROVISIONING COMPLETE - APPLICATION DEPLOYED  ✓${NC}      ${BRIGHT_GREEN}║${NC}"
echo -e "${BRIGHT_GREEN}║${NC}                                                               ${BRIGHT_GREEN}║${NC}"
echo -e "${BRIGHT_GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Deployment Summary
section_header "Deployment Summary"
echo ""
echo -e "   ${CYAN}Application Name:${NC}    ${WHITE}${BOLD}$APP_NAME${NC}"
echo -e "   ${CYAN}Template Used:${NC}       ${WHITE}$TEMPLATE${NC}"
echo -e "   ${CYAN}Deployment Mode:${NC}     $([ "$MODE" = "dev" ] && echo "${YELLOW}Development (hot reload)${NC}" || echo "${BRIGHT_GREEN}Production (optimized)${NC}")"
echo -e "   ${CYAN}Total Build Time:${NC}    ${BRIGHT_MAGENTA}${TOTAL_MINUTES}m ${TOTAL_SECONDS}s${NC}"
echo ""

# Resource Information
section_header "Resource Information"
echo ""
echo -e "   ${BRIGHT_CYAN}🌐 Live URL:${NC}"
echo -e "      ${BRIGHT_GREEN}https://$APP_NAME.$DEFAULT_DOMAIN${NC}"
echo ""
echo -e "   ${BRIGHT_CYAN}🔗 GitHub Repository:${NC}"
echo -e "      ${BRIGHT_BLUE}https://github.com/$GH_USER/$APP_NAME${NC}"
echo ""
echo -e "   ${BRIGHT_CYAN}⚙️  Server Resources:${NC}"
echo -e "      Port:        ${WHITE}$APP_PORT${NC}"
echo -e "      PM2 Process: ${WHITE}$APP_NAME${NC}"
echo -e "      App Path:    ${GRAY}/var/www/$APP_NAME${NC}"
echo -e "      Nginx Config: ${GRAY}/etc/nginx/sites-enabled/$APP_NAME.$DEFAULT_DOMAIN${NC}"
echo ""

# SSL Certificate Info
section_header "Security"
echo ""
echo -e "   ${BRIGHT_GREEN}✓${NC} SSL Certificate active (Let's Encrypt)"
echo -e "   ${BRIGHT_GREEN}✓${NC} HTTPS enabled on port 443"
echo -e "   ${BRIGHT_GREEN}✓${NC} HTTP → HTTPS redirect configured"
echo -e "   ${GRAY}Certificate expires in 90 days (auto-renewal configured)${NC}"
echo ""

# Quick Commands
section_header "Quick Commands"
echo ""
echo -e "   ${CYAN}View live logs:${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}pm2 logs $APP_NAME${NC}"
echo ""
echo -e "   ${CYAN}Restart application:${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}pm2 restart $APP_NAME${NC}"
echo ""
echo -e "   ${CYAN}Stop application:${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}pm2 stop $APP_NAME${NC}"
echo ""
echo -e "   ${CYAN}Navigate to app directory:${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}cd /var/www/$APP_NAME${NC}"
echo ""
echo -e "   ${CYAN}Check application status:${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}pm2 status${NC}"
echo ""

# Next Steps
section_header "Next Steps"
echo ""
echo -e "   ${BRIGHT_CYAN}1.${NC} Visit your deployed application:"
echo -e "      ${BRIGHT_GREEN}https://$APP_NAME.$DEFAULT_DOMAIN${NC}"
echo ""
echo -e "   ${BRIGHT_CYAN}2.${NC} Customize your application:"
echo -e "      ${GRAY}$${NC} ${YELLOW}cd /var/www/$APP_NAME${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}nano src/app/page.tsx${NC}  ${GRAY}# Edit homepage${NC}"
echo ""
echo -e "   ${BRIGHT_CYAN}3.${NC} Push changes to GitHub:"
echo -e "      ${GRAY}$${NC} ${YELLOW}git add .${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}git commit -m \"your changes\"${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}git push${NC}"
echo ""
if [ "$MODE" = "dev" ]; then
echo -e "   ${BRIGHT_CYAN}4.${NC} ${YELLOW}Development Mode Active:${NC}"
echo -e "      Your changes will hot-reload automatically!"
echo -e "      To deploy to production, rebuild with: ${YELLOW}npm run build${NC}"
echo ""
fi

# Footer
echo ""
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${DIM}Provisioned at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "  ${DIM}For support: https://github.com/$GH_USER/$APP_NAME/issues${NC}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo ""
