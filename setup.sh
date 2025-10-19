#!/bin/bash

# Terminal UI Color Codes
COLOR_RESET='\033[0m'
COLOR_BG_PRIMARY='\033[48;5;16m'
COLOR_TEXT_PRIMARY='\033[38;5;255m'
COLOR_TEXT_SECONDARY='\033[38;5;246m'
COLOR_TEXT_ACCENT='\033[38;5;208m'
COLOR_TEXT_SUCCESS='\033[38;5;34m'
COLOR_TEXT_WARNING='\033[38;5;220m'
COLOR_TEXT_ERROR='\033[38;5;196m'
COLOR_BORDER='\033[38;5;240m'
COLOR_PROMPT='\033[38;5;208m'

# Terminal UI Characters
CHAR_DOT='●'
CHAR_ARROW='⎿'
CHAR_PROMPT='>'
CHAR_SUCCESS='✓'
CHAR_ERROR='✗'
CHAR_WARNING='⚠'
CHAR_INFO='ℹ'
CHAR_STEP='▸'

# Track setup progress
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_LOG="$SCRIPT_DIR/setup.log"
TOTAL_STEPS=7
CURRENT_STEP=0

# Terminal Box Drawing Functions
draw_header() {
    local text="$1"
    local width=76
    echo ""
    echo -e "${COLOR_BORDER}┌$(printf '─%.0s' {1..76})┐${COLOR_RESET}"
    printf "${COLOR_BORDER}│${COLOR_RESET} ${COLOR_TEXT_ACCENT}%-74s${COLOR_RESET} ${COLOR_BORDER}│${COLOR_RESET}\n" "$text"
    echo -e "${COLOR_BORDER}└$(printf '─%.0s' {1..76})┘${COLOR_RESET}"
    echo ""
}

draw_section() {
    local title="$1"
    local subtitle="$2"
    echo ""
    echo -e "${COLOR_BORDER}╭$(printf '─%.0s' {1..76})╮${COLOR_RESET}"
    printf "${COLOR_BORDER}│${COLOR_RESET} ${COLOR_TEXT_SUCCESS}${CHAR_DOT}${COLOR_RESET} ${COLOR_TEXT_PRIMARY}%-71s${COLOR_RESET} ${COLOR_BORDER}│${COLOR_RESET}\n" "$title"
    if [[ -n "$subtitle" ]]; then
        printf "${COLOR_BORDER}│${COLOR_RESET}   ${COLOR_TEXT_SECONDARY}${CHAR_ARROW} %-69s${COLOR_RESET} ${COLOR_BORDER}│${COLOR_RESET}\n" "$subtitle"
    fi
    echo -e "${COLOR_BORDER}╰$(printf '─%.0s' {1..76})╯${COLOR_RESET}"
    echo ""
}

draw_manual_section() {
    local step_num="$1"
    local title="$2"
    echo ""
    echo -e "${COLOR_BORDER}┏$(printf '━%.0s' {1..76})┓${COLOR_RESET}"
    printf "${COLOR_BORDER}┃${COLOR_RESET} ${COLOR_TEXT_WARNING}Step ${step_num}:${COLOR_RESET} ${COLOR_TEXT_PRIMARY}%-64s${COLOR_RESET} ${COLOR_BORDER}┃${COLOR_RESET}\n" "$title"
    echo -e "${COLOR_BORDER}┗$(printf '━%.0s' {1..76})┛${COLOR_RESET}"
}

draw_command_box() {
    local command="$1"
    echo -e "   ${COLOR_BORDER}┌─────────────────────────────────────────────────────────────────────┐${COLOR_RESET}"
    printf "   ${COLOR_BORDER}│${COLOR_RESET} ${COLOR_PROMPT}${CHAR_PROMPT}${COLOR_RESET} ${COLOR_TEXT_ACCENT}%-64s${COLOR_RESET} ${COLOR_BORDER}│${COLOR_RESET}\n" "$command"
    echo -e "   ${COLOR_BORDER}└─────────────────────────────────────────────────────────────────────┘${COLOR_RESET}"
}

draw_separator() {
    echo -e "${COLOR_BORDER}$(printf '─%.0s' {1..78})${COLOR_RESET}"
}

draw_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))

    printf "\r${COLOR_TEXT_SECONDARY}Progress: [${COLOR_RESET}"
    printf "${COLOR_TEXT_SUCCESS}%0.s█${COLOR_RESET}" $(seq 1 $filled)
    printf "${COLOR_BORDER}%0.s░${COLOR_RESET}" $(seq 1 $empty)
    printf "${COLOR_TEXT_SECONDARY}] %3d%% (%d/%d)${COLOR_RESET}" $percent $current $total
}

# Helper functions
status() {
    echo -e "${COLOR_TEXT_SECONDARY}  ${CHAR_STEP} $1${COLOR_RESET}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$SETUP_LOG"
}

success() {
    echo -e "${COLOR_TEXT_SUCCESS}  ${CHAR_SUCCESS} $1${COLOR_RESET}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$SETUP_LOG"
}

error() {
    echo -e "${COLOR_TEXT_ERROR}  ${CHAR_ERROR} $1${COLOR_RESET}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$SETUP_LOG"
}

warning() {
    echo -e "${COLOR_TEXT_WARNING}  ${CHAR_WARNING} $1${COLOR_RESET}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$SETUP_LOG"
}

info() {
    echo -e "${COLOR_TEXT_SECONDARY}  ${CHAR_INFO} $1${COLOR_RESET}"
}

bullet() {
    echo -e "   ${COLOR_TEXT_SECONDARY}•${COLOR_RESET} $1"
}

step_complete() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    draw_progress $CURRENT_STEP $TOTAL_STEPS
    echo ""
}

# ASCII Art Header
print_ascii_header() {
    clear
    echo ""
    echo -e "${COLOR_TEXT_ACCENT}"
    cat << 'EOF'
    ┏┓┓ ┏┓┳┓┓ ┓┓ ┏┓┳┓┏┓┓┏o┏┓o┏┓┓┓┏┓┳┓
    ┃ ┃ ┣┫┃┃┃ ┣┫┃┃┃┃┃┃┃┫┃┗┓┃┃┃┃┃┣ ┣┫
    ┗┛┗┛┛┗┗┛┗┛┛┗┗┛┗┛┗┛┗┻┗┗┛┗┗┛┛┗┗┛┛┗
EOF
    echo -e "${COLOR_RESET}"
    echo -e "${COLOR_TEXT_PRIMARY}    Next.js Provisioner - Server Setup Script${COLOR_RESET}"
    echo -e "${COLOR_TEXT_SECONDARY}    Automated deployment with Claude AI integration${COLOR_RESET}"
    echo ""
}

# Start setup
print_ascii_header

draw_separator
echo ""
echo -e "${COLOR_TEXT_SECONDARY}This script will install and configure:${COLOR_RESET}"
bullet "Node.js & npm (LTS version)"
bullet "PM2 process manager"
bullet "Nginx web server"
bullet "Certbot for SSL certificates"
bullet "jq JSON processor"
bullet "GitHub CLI"
bullet "Directory structure and environment configuration"
echo ""
warning "This script requires sudo access and will modify system packages"
echo ""
draw_separator

echo ""
read -p "$(echo -e ${COLOR_PROMPT}${CHAR_PROMPT}${COLOR_RESET}) Continue with setup? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${COLOR_TEXT_SECONDARY}Setup cancelled.${COLOR_RESET}"
    exit 0
fi

# Initialize log
echo "Setup started at $(date)" > "$SETUP_LOG"
echo ""

# Check if running on Ubuntu/Debian
draw_section "System Check" "Verifying operating system compatibility"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    status "Detected OS: $NAME $VERSION"
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        warning "This script is designed for Ubuntu/Debian"
        warning "You may need to adapt commands for $NAME"
        echo ""
        read -p "$(echo -e ${COLOR_PROMPT}${CHAR_PROMPT}${COLOR_RESET}) Press Enter to continue or Ctrl+C to abort..."
        echo ""
    else
        success "Operating system compatible"
    fi
else
    error "Cannot detect OS - this script requires Ubuntu or Debian"
    exit 1
fi
step_complete

# Update package list
draw_section "Package Manager Update" "Refreshing system package lists"
status "Running apt update..."
if sudo apt-get update -qq 2>/dev/null; then
    success "Package lists updated successfully"
else
    error "Failed to update package lists"
    exit 1
fi
step_complete

# Install Node.js
draw_section "Node.js & npm Installation" "JavaScript runtime environment"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    success "Node.js already installed: $NODE_VERSION"
else
    status "Installing Node.js LTS from NodeSource..."
    if curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs; then
        success "Node.js installed: $(node --version)"
    else
        error "Failed to install Node.js"
        exit 1
    fi
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    info "npm version: $NPM_VERSION"
fi
step_complete

# Install PM2
draw_section "PM2 Process Manager" "Production process manager for Node.js"
if command -v pm2 &> /dev/null; then
    PM2_VERSION=$(pm2 --version)
    success "PM2 already installed: v$PM2_VERSION"
else
    status "Installing PM2 globally..."
    if sudo npm install -g pm2; then
        success "PM2 installed: v$(pm2 --version)"
    else
        error "Failed to install PM2"
        exit 1
    fi
fi

status "Configuring PM2 to start on system boot..."
if sudo pm2 startup systemd -u $USER --hp $HOME > /dev/null 2>&1; then
    success "PM2 startup script configured"
else
    warning "PM2 startup configuration may have failed"
fi
step_complete

# Install Nginx
draw_section "Nginx Web Server" "High-performance HTTP server and reverse proxy"
if command -v nginx &> /dev/null; then
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
    success "Nginx already installed: $NGINX_VERSION"
else
    status "Installing Nginx..."
    if sudo apt-get install -y nginx && sudo systemctl enable nginx && sudo systemctl start nginx; then
        success "Nginx installed and started"
        info "Service enabled to start on boot"
    else
        error "Failed to install Nginx"
        exit 1
    fi
fi
step_complete

# Install Certbot
draw_section "Certbot SSL Manager" "Automated SSL certificate management"
if command -v certbot &> /dev/null; then
    CERTBOT_VERSION=$(certbot --version 2>&1 | cut -d' ' -f2)
    success "Certbot already installed: $CERTBOT_VERSION"
else
    status "Installing Certbot and Nginx plugin..."
    if sudo apt-get install -y certbot python3-certbot-nginx; then
        success "Certbot installed successfully"
    else
        error "Failed to install Certbot"
        exit 1
    fi
fi
step_complete

# Install jq
draw_section "jq JSON Processor" "Command-line JSON manipulation tool"
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version)
    success "jq already installed: $JQ_VERSION"
else
    status "Installing jq..."
    if sudo apt-get install -y jq; then
        success "jq installed: $(jq --version)"
    else
        error "Failed to install jq"
        exit 1
    fi
fi
step_complete

# Install GitHub CLI
draw_section "GitHub CLI" "GitHub's official command-line tool"
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -1)
    success "GitHub CLI already installed: $GH_VERSION"
else
    status "Adding GitHub CLI repository..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

    status "Installing GitHub CLI..."
    if sudo apt-get update -qq && sudo apt-get install -y gh; then
        success "GitHub CLI installed: $(gh --version | head -1)"
    else
        error "Failed to install GitHub CLI"
        exit 1
    fi
fi
step_complete

# Create directory structure
draw_section "Directory Structure" "Creating provisioner directories"
status "Creating required directories..."
mkdir -p "$SCRIPT_DIR/data"
mkdir -p "$SCRIPT_DIR/templates"
mkdir -p "$SCRIPT_DIR/bkups"
success "Directories created:"
info "  $SCRIPT_DIR/data (application data)"
info "  $SCRIPT_DIR/templates (Next.js templates)"
info "  $SCRIPT_DIR/bkups (backup storage)"

# Create .env file if it doesn't exist
echo ""
status "Checking environment configuration..."
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    warning ".env file already exists - skipping creation"
    info "Existing configuration preserved"
else
    if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
        status "Creating .env from .env.example template..."
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        success ".env file created from template"
    else
        status "Creating basic .env template..."
        cat > "$SCRIPT_DIR/.env" << 'EOF'
# Domain & DNS Configuration
DEFAULT_DOMAIN=your-domain.com
CLOUDFLARE_ZONE_ID=your_zone_id_here

# Server Configuration
SERVER_PUBLIC_IP=your_server_public_ip

# API Keys
CLOUDFLARE_API_KEY=your_cloudflare_api_token
CERTBOT_ACCOUNT_ID=your_certbot_account_id

# Claude AI Model IDs (update as models change)
CLAUDE_MODEL_HAIKU=claude-3-5-haiku-20241022
CLAUDE_MODEL_SONNET=claude-3-5-sonnet-20241022
CLAUDE_MODEL_OPUS=claude-opus-4-20250514
EOF
        success "Basic .env template created"
    fi
    warning "You MUST edit .env with your actual configuration values"
fi

echo ""
draw_progress $TOTAL_STEPS $TOTAL_STEPS
echo ""
echo ""

# Installation complete banner
echo -e "${COLOR_TEXT_SUCCESS}"
cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                  AUTOMATED SETUP COMPLETED!                           ║
    ╚═══════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${COLOR_RESET}"
echo ""
success "All system dependencies installed successfully"
echo ""

# Manual configuration steps
echo ""
echo -e "${COLOR_TEXT_WARNING}"
cat << 'EOF'
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    ┃                  MANUAL CONFIGURATION REQUIRED                        ┃
    ┃                                                                        ┃
    ┃  Complete the following steps to finish the provisioner setup         ┃
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
EOF
echo -e "${COLOR_RESET}"
echo ""

# Step 1: GitHub Authentication
draw_manual_section "1" "GitHub Authentication"
echo ""
echo -e "${COLOR_TEXT_SECONDARY}   Authenticate GitHub CLI to enable repository creation:${COLOR_RESET}"
echo ""
draw_command_box "gh auth login"
echo ""
bullet "Choose: ${COLOR_TEXT_PRIMARY}GitHub.com${COLOR_RESET}"
bullet "Protocol: ${COLOR_TEXT_PRIMARY}HTTPS${COLOR_RESET}"
bullet "Authentication: ${COLOR_TEXT_PRIMARY}Login with a web browser${COLOR_RESET} (recommended)"
bullet "Follow the browser prompts to complete authentication"
echo ""

# Step 2: Certbot Registration
draw_manual_section "2" "Certbot Registration"
echo ""
echo -e "${COLOR_TEXT_SECONDARY}   Register your email with Let's Encrypt:${COLOR_RESET}"
echo ""
draw_command_box "sudo certbot register --email your@email.com"
echo ""
bullet "Replace ${COLOR_TEXT_WARNING}your@email.com${COLOR_RESET} with your actual email address"
bullet "Accept the Terms of Service when prompted"
echo ""
echo -e "${COLOR_TEXT_SECONDARY}   After registration, retrieve your account ID:${COLOR_RESET}"
echo ""
draw_command_box "sudo ls /etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory/"
echo ""
bullet "Copy the directory name shown (this is your ${COLOR_TEXT_ACCENT}CERTBOT_ACCOUNT_ID${COLOR_RESET})"
echo ""

# Step 3: Cloudflare Setup
draw_manual_section "3" "Cloudflare DNS Configuration"
echo ""
echo -e "${COLOR_TEXT_SECONDARY}   You need two pieces of information from Cloudflare:${COLOR_RESET}"
echo ""
echo -e "   ${COLOR_TEXT_PRIMARY}A. Zone ID:${COLOR_RESET}"
bullet "Log in to Cloudflare Dashboard"
bullet "Select your domain from the list"
bullet "Find Zone ID in the right sidebar (API section)"
bullet "Copy the Zone ID value"
echo ""
echo -e "   ${COLOR_TEXT_PRIMARY}B. API Token:${COLOR_RESET}"
bullet "Navigate to: ${COLOR_TEXT_SECONDARY}Profile → API Tokens → Create Token${COLOR_RESET}"
bullet "Use template: ${COLOR_TEXT_PRIMARY}'Edit zone DNS'${COLOR_RESET}"
bullet "Zone Resources: ${COLOR_TEXT_SECONDARY}Include → Specific zone → [Your domain]${COLOR_RESET}"
bullet "Click ${COLOR_TEXT_PRIMARY}'Create Token'${COLOR_RESET} and copy it immediately"
bullet "${COLOR_TEXT_WARNING}Warning:${COLOR_RESET} Token is shown only once"
echo ""

# Step 4: Environment Configuration
draw_manual_section "4" "Environment Configuration"
echo ""
echo -e "${COLOR_TEXT_SECONDARY}   Edit the .env file with your configuration:${COLOR_RESET}"
echo ""
draw_command_box "nano $SCRIPT_DIR/.env"
echo ""
echo -e "${COLOR_TEXT_SECONDARY}   Update the following values:${COLOR_RESET}"
echo ""
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your.server.ip.address")
echo -e "   ${COLOR_BORDER}┌─────────────────────────────────────────────────────────────────────┐${COLOR_RESET}"
printf "   ${COLOR_BORDER}│${COLOR_RESET} ${COLOR_TEXT_ACCENT}%-23s${COLOR_RESET} ${COLOR_TEXT_SECONDARY}→${COLOR_RESET} %-41s ${COLOR_BORDER}│${COLOR_RESET}\n" "DEFAULT_DOMAIN" "your-domain.com"
printf "   ${COLOR_BORDER}│${COLOR_RESET} ${COLOR_TEXT_ACCENT}%-23s${COLOR_RESET} ${COLOR_TEXT_SECONDARY}→${COLOR_RESET} %-41s ${COLOR_BORDER}│${COLOR_RESET}\n" "CLOUDFLARE_ZONE_ID" "from step 3A"
printf "   ${COLOR_BORDER}│${COLOR_RESET} ${COLOR_TEXT_ACCENT}%-23s${COLOR_RESET} ${COLOR_TEXT_SECONDARY}→${COLOR_RESET} %-41s ${COLOR_BORDER}│${COLOR_RESET}\n" "SERVER_PUBLIC_IP" "$SERVER_IP"
printf "   ${COLOR_BORDER}│${COLOR_RESET} ${COLOR_TEXT_ACCENT}%-23s${COLOR_RESET} ${COLOR_TEXT_SECONDARY}→${COLOR_RESET} %-41s ${COLOR_BORDER}│${COLOR_RESET}\n" "CLOUDFLARE_API_KEY" "from step 3B"
printf "   ${COLOR_BORDER}│${COLOR_RESET} ${COLOR_TEXT_ACCENT}%-23s${COLOR_RESET} ${COLOR_TEXT_SECONDARY}→${COLOR_RESET} %-41s ${COLOR_BORDER}│${COLOR_RESET}\n" "CERTBOT_ACCOUNT_ID" "from step 2"
echo -e "   ${COLOR_BORDER}└─────────────────────────────────────────────────────────────────────┘${COLOR_RESET}"
echo ""

# Step 5: API Setup (if needed)
if [[ -d "/var/www/provisioner" ]]; then
    draw_manual_section "5" "API Setup (Optional)"
    echo ""
    echo -e "${COLOR_TEXT_SECONDARY}   If you want to use the REST API and web interface:${COLOR_RESET}"
    echo ""
    draw_command_box "cd /var/www/provisioner"
    draw_command_box "npm install"
    draw_command_box "npm run build"
    draw_command_box "PORT=27032 pm2 start dist/index.js --name provisioner-api"
    draw_command_box "pm2 save"
    echo ""
    bullet "The API will be available at ${COLOR_TEXT_PRIMARY}http://your-server:27032${COLOR_RESET}"
    bullet "Check status with: ${COLOR_TEXT_ACCENT}pm2 logs provisioner-api${COLOR_RESET}"
    echo ""
fi

# Verification steps
draw_manual_section "6" "Verify Installation"
echo ""
echo -e "${COLOR_TEXT_SECONDARY}   After completing all configuration steps, test the provisioner:${COLOR_RESET}"
echo ""
echo -e "   ${COLOR_TEXT_PRIMARY}A. Create a test application:${COLOR_RESET}"
draw_command_box "./provisioner.sh -n test-app -t new -m dev"
echo ""
bullet "This creates a development-mode Next.js app"
bullet "Wait for the process to complete"
echo ""
echo -e "   ${COLOR_TEXT_PRIMARY}B. Remove the test application:${COLOR_RESET}"
draw_command_box "./unprovision.sh -n test-app -y"
echo ""
bullet "Cleans up all resources created during testing"
echo ""

# Final summary
echo ""
echo -e "${COLOR_TEXT_SUCCESS}"
cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                      SETUP SCRIPT COMPLETE                            ║
    ╚═══════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${COLOR_RESET}"
echo ""
success "Automated installation completed successfully"
info "Setup log saved to: ${COLOR_TEXT_ACCENT}$SETUP_LOG${COLOR_RESET}"
echo ""
echo -e "${COLOR_TEXT_WARNING}IMPORTANT:${COLOR_RESET} Complete the ${COLOR_TEXT_PRIMARY}6 manual configuration steps${COLOR_RESET} above before running the provisioner."
echo ""
echo -e "${COLOR_TEXT_SECONDARY}For detailed documentation, see:${COLOR_RESET} ${COLOR_TEXT_ACCENT}$SCRIPT_DIR/README.md${COLOR_RESET}"
echo ""
draw_separator
echo ""
