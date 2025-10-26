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

# Helper function for section headers
section_header() {
    echo ""
    echo -e "${BRIGHT_CYAN}╭─────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${BRIGHT_CYAN}│${NC} ${WHITE}${BOLD}$1${NC}"
    echo -e "${BRIGHT_CYAN}╰─────────────────────────────────────────────────────────────────╯${NC}"
}

# Helper function for status messages
status() {
    echo -e "${BLUE}▸${NC} $1"
}

# Helper function for success messages
success() {
    echo -e "${BRIGHT_GREEN}✓${NC} $1"
}

# Helper function for error messages
error() {
    echo -e "${BRIGHT_RED}✗${NC} ${BOLD}$1${NC}"
}

# Helper function for warnings
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Helper function for info messages
info() {
    echo -e "${CYAN}ℹ${NC} ${DIM}$1${NC}"
}

# Parse arguments
while getopts "n:" opt; do
  case $opt in
    n) APP_NAME="$OPTARG" ;;
  esac
done

# Validate required arguments
if [ -z "$APP_NAME" ]; then
    error "Usage: $0 -n <app_name>"
    echo "  -n <app_name> : Application name (required)"
    exit 1
fi

clear
echo ""
echo -e "${BRIGHT_CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BRIGHT_CYAN}║${NC}                                                               ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}║${NC}              ${WHITE}${BOLD}Mode Switch Utility${NC}                          ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}║${NC}                                                               ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

section_header "Analyzing Current Configuration"

# Check if PM2 process exists
if ! pm2 jlist | jq -e ".[] | select(.name==\"$APP_NAME\")" > /dev/null 2>&1; then
    error "Application '$APP_NAME' not found in PM2"
    echo ""
    echo -e "${YELLOW}Available PM2 processes:${NC}"
    pm2 list
    exit 1
fi

# Get PM2 process info
PM2_INFO=$(pm2 jlist | jq ".[] | select(.name==\"$APP_NAME\")")
PM2_COMMAND=$(echo "$PM2_INFO" | jq -r '.pm2_env.pm_exec_path')
PM2_ARGS=$(echo "$PM2_INFO" | jq -r '.pm2_env.args | join(" ")')
PM2_CWD=$(echo "$PM2_INFO" | jq -r '.pm2_env.pm_cwd')

success "Found PM2 process: $APP_NAME"
info "Working directory: $PM2_CWD"

# Determine current mode by checking the PM2 args
CURRENT_MODE=""
if echo "$PM2_ARGS" | grep -q "run dev"; then
    CURRENT_MODE="dev"
    CURRENT_MODE_DISPLAY="${YELLOW}Development${NC}"
elif echo "$PM2_ARGS" | grep -q "run start"; then
    CURRENT_MODE="prod"
    CURRENT_MODE_DISPLAY="${BRIGHT_GREEN}Production${NC}"
else
    error "Could not determine current mode from PM2 configuration"
    echo ""
    echo -e "${YELLOW}PM2 Arguments:${NC} $PM2_ARGS"
    exit 1
fi

success "Current mode: $CURRENT_MODE_DISPLAY"

# Determine target mode
if [ "$CURRENT_MODE" = "dev" ]; then
    TARGET_MODE="prod"
    TARGET_MODE_DISPLAY="${BRIGHT_GREEN}Production${NC}"
else
    TARGET_MODE="dev"
    TARGET_MODE_DISPLAY="${YELLOW}Development${NC}"
fi

echo ""
info "Will switch from $CURRENT_MODE_DISPLAY to $TARGET_MODE_DISPLAY"

# Get port from .env file
if [ ! -f "$PM2_CWD/.env" ]; then
    error "Could not find .env file at $PM2_CWD/.env"
    exit 1
fi

APP_PORT=$(grep "^PORT=" "$PM2_CWD/.env" | cut -d '=' -f 2)
if [ -z "$APP_PORT" ]; then
    error "Could not find PORT in .env file"
    exit 1
fi

success "Port: $APP_PORT"

# Determine if this is a React app or Next.js app by checking package.json
IS_REACT=false
if [ -f "$PM2_CWD/package.json" ]; then
    if grep -q "@react-router/dev" "$PM2_CWD/package.json"; then
        IS_REACT=true
        info "Detected React Router app"
    else
        info "Detected Next.js/SaaS app"
    fi
fi

echo ""
section_header "Switching to $TARGET_MODE_DISPLAY Mode"

# If switching to production, build first
if [ "$TARGET_MODE" = "prod" ]; then
    echo ""
    status "Building application for production..."
    info "This may take 30-60 seconds depending on project size"

    cd "$PM2_CWD"
    if npm run build > /tmp/switch-mode-build.log 2>&1; then
        success "Production build completed"
        info "Build output: /tmp/switch-mode-build.log"
    else
        error "Build failed"
        echo ""
        echo -e "${YELLOW}Last 20 lines of build output:${NC}"
        tail -20 /tmp/switch-mode-build.log
        echo ""
        warning "Full build log: /tmp/switch-mode-build.log"
        exit 1
    fi
fi

# Stop the current PM2 process
echo ""
status "Stopping current PM2 process..."
pm2 delete "$APP_NAME" > /tmp/pm2-delete.log 2>&1
success "Process stopped and deleted"

# Start PM2 with the new mode
echo ""
status "Starting PM2 in $TARGET_MODE_DISPLAY mode..."

cd "$PM2_CWD"

if [ "$IS_REACT" = true ]; then
    # React Router apps: dev mode uses --port flag, prod mode uses PORT env var
    if [ "$TARGET_MODE" = "prod" ]; then
        PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run start > /tmp/pm2-start.log 2>&1
    else
        pm2 start npm --name "$APP_NAME" -- run dev -- --port $APP_PORT > /tmp/pm2-start.log 2>&1
    fi
else
    # Next.js and other apps use PORT env var
    if [ "$TARGET_MODE" = "prod" ]; then
        PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run start > /tmp/pm2-start.log 2>&1
    else
        PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run dev > /tmp/pm2-start.log 2>&1
    fi
fi

# Check if PM2 process started successfully
sleep 2
if pm2 jlist | jq -e ".[] | select(.name==\"$APP_NAME\")" > /dev/null 2>&1; then
    success "Application restarted in $TARGET_MODE_DISPLAY mode"

    # Get process status
    PM2_STATUS=$(pm2 jlist | jq -r ".[] | select(.name==\"$APP_NAME\") | .pm2_env.status")

    if [ "$PM2_STATUS" = "online" ]; then
        success "Process status: ${BRIGHT_GREEN}online${NC}"
    else
        warning "Process status: ${YELLOW}$PM2_STATUS${NC}"
        info "Check logs with: pm2 logs $APP_NAME"
    fi
else
    error "Failed to start PM2 process"
    echo ""
    echo -e "${YELLOW}PM2 start log:${NC}"
    cat /tmp/pm2-start.log
    exit 1
fi

# Save PM2 configuration
pm2 save > /dev/null 2>&1

# Final Success Banner
echo ""
echo ""
echo -e "${BRIGHT_GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BRIGHT_GREEN}║${NC}                                                               ${BRIGHT_GREEN}║${NC}"
echo -e "${BRIGHT_GREEN}║${NC}          ${WHITE}${BOLD}✓  MODE SWITCH COMPLETED SUCCESSFULLY  ✓${NC}          ${BRIGHT_GREEN}║${NC}"
echo -e "${BRIGHT_GREEN}║${NC}                                                               ${BRIGHT_GREEN}║${NC}"
echo -e "${BRIGHT_GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

section_header "Summary"
echo ""
echo -e "   ${CYAN}Application:${NC}      ${WHITE}${BOLD}$APP_NAME${NC}"
echo -e "   ${CYAN}Previous Mode:${NC}    $CURRENT_MODE_DISPLAY"
echo -e "   ${CYAN}New Mode:${NC}         $TARGET_MODE_DISPLAY"
echo -e "   ${CYAN}Port:${NC}             ${WHITE}$APP_PORT${NC}"
echo -e "   ${CYAN}Process Status:${NC}   ${BRIGHT_GREEN}online${NC}"
echo ""

section_header "Quick Commands"
echo ""
echo -e "   ${CYAN}View live logs:${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}pm2 logs $APP_NAME${NC}"
echo ""
echo -e "   ${CYAN}Check status:${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}pm2 status${NC}"
echo ""
echo -e "   ${CYAN}Switch back to $CURRENT_MODE mode:${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}./switch_mode.sh -n $APP_NAME${NC}"
echo ""

# Load .env for domain info
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
    echo -e "   ${CYAN}Live URL:${NC}"
    echo -e "      ${BRIGHT_GREEN}https://$APP_NAME.$DEFAULT_DOMAIN${NC}"
    echo ""
fi

echo ""
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${DIM}Mode switched at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo ""
