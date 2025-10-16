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

# Parse arguments
SKIP_GITHUB=false
AUTO_YES=false
while getopts "n:gy" opt; do
  case $opt in
    n) APP_NAME="$OPTARG" ;;
    g) SKIP_GITHUB=true ;;
    y) AUTO_YES=true ;;
  esac
done

# Validate required arguments
if [ -z "$APP_NAME" ]; then
    error "Usage: $0 -n <app_name> [-g] [-y]"
    echo "  -n <app_name>  : Application name to unprovision"
    echo "  -g             : Skip GitHub repository deletion"
    echo "  -y             : Auto-accept all prompts"
    exit 1
fi

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║           Next.js App Unprovision Script                   ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show flags if used
if [ "$SKIP_GITHUB" = true ] || [ "$AUTO_YES" = true ]; then
    echo -e "${BLUE}Flags:${NC}"
    [ "$SKIP_GITHUB" = true ] && echo -e "   ${YELLOW}✓${NC} Skip GitHub deletion (-g)"
    [ "$AUTO_YES" = true ] && echo -e "   ${YELLOW}✓${NC} Auto-accept prompts (-y)"
    echo ""
fi

echo -e "${YELLOW}⚠  WARNING: This will remove the following:${NC}"
echo ""

# Load .env file for Cloudflare credentials
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

# Check what exists and build removal list
ITEMS_TO_REMOVE=()

# Check PM2 process
if pm2 list | grep -q "$APP_NAME"; then
    ITEMS_TO_REMOVE+=("   - PM2 process: $APP_NAME")
fi

# Check nginx config
if [ -f "/etc/nginx/sites-enabled/$APP_NAME.$DEFAULT_DOMAIN" ]; then
    ITEMS_TO_REMOVE+=("   - Nginx config: /etc/nginx/sites-enabled/$APP_NAME.$DEFAULT_DOMAIN")
fi

# Check application directory
if [ -d "/var/www/$APP_NAME" ]; then
    ITEMS_TO_REMOVE+=("   - Application directory: /var/www/$APP_NAME")
fi

# Check DNS record
DNS_RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=$APP_NAME.$DEFAULT_DOMAIN" \
    -H "Authorization: Bearer $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json" | jq -r '.result[0].id // empty')

if [ -n "$DNS_RECORD_ID" ] && [ "$DNS_RECORD_ID" != "null" ]; then
    ITEMS_TO_REMOVE+=("   - Cloudflare DNS record: $APP_NAME.$DEFAULT_DOMAIN")
fi

# Check SSL certificate
if sudo certbot certificates 2>/dev/null | grep -q "$APP_NAME.$DEFAULT_DOMAIN"; then
    ITEMS_TO_REMOVE+=("   - SSL certificate: $APP_NAME.$DEFAULT_DOMAIN")
fi

# Check GitHub repository (unless -g flag is set)
if [ "$SKIP_GITHUB" = false ]; then
    if gh repo view "$APP_NAME" >/dev/null 2>&1; then
        GITHUB_URL=$(gh repo view "$APP_NAME" --json url -q .url)
        ITEMS_TO_REMOVE+=("   - GitHub repository: $GITHUB_URL")
    fi
fi

# If nothing to remove, exit
if [ ${#ITEMS_TO_REMOVE[@]} -eq 0 ]; then
    warning "No resources found for app: $APP_NAME"
    echo ""
    exit 0
fi

# Display items to remove
for item in "${ITEMS_TO_REMOVE[@]}"; do
    echo -e "${RED}$item${NC}"
done

echo ""
echo -e "${YELLOW}Application:${NC} $APP_NAME"
echo ""

# First confirmation
if [ "$AUTO_YES" = true ]; then
    echo -e "${YELLOW}Auto-accepting (--y flag)${NC}"
else
    read -p "$(echo -e ${YELLOW}Are you sure you want to remove these resources? [y/N]:${NC} )" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warning "Unprovision cancelled"
        exit 0
    fi
fi

# Second confirmation for GitHub repo deletion
DELETE_GITHUB=false
if [ "$SKIP_GITHUB" = false ] && gh repo view "$APP_NAME" >/dev/null 2>&1; then
    if [ "$AUTO_YES" = true ]; then
        echo ""
        echo -e "${YELLOW}GitHub deletion skipped (use -y with caution - repository will NOT be deleted automatically)${NC}"
        DELETE_GITHUB=false
    else
        echo ""
        echo -e "${RED}⚠  CRITICAL WARNING: GitHub Repository Deletion${NC}"
        echo -e "${YELLOW}This will PERMANENTLY delete the GitHub repository and all its history!${NC}"
        echo ""
        read -p "$(echo -e ${YELLOW}Do you want to delete the GitHub repository? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            DELETE_GITHUB=true
        fi
    fi
fi

echo ""
status "Starting unprovision for: $APP_NAME"
echo ""

# Step 1: Stop and delete PM2 process
if pm2 list | grep -q "$APP_NAME"; then
    status "Stopping and deleting PM2 process..."
    pm2 stop "$APP_NAME" 2>/dev/null || true
    pm2 delete "$APP_NAME" 2>/dev/null || true
    pm2 save 2>/dev/null || true
    success "PM2 process removed"
else
    warning "No PM2 process found for $APP_NAME"
fi

# Step 2: Remove nginx config
if [ -f "/etc/nginx/sites-enabled/$APP_NAME.$DEFAULT_DOMAIN" ]; then
    status "Removing nginx configuration..."
    sudo rm -f "/etc/nginx/sites-enabled/$APP_NAME.$DEFAULT_DOMAIN"
    sudo nginx -t && sudo systemctl restart nginx
    success "Nginx configuration removed"
else
    warning "No nginx configuration found"
fi

# Step 3: Delete SSL certificate
if sudo certbot certificates 2>/dev/null | grep -q "$APP_NAME.$DEFAULT_DOMAIN"; then
    status "Deleting SSL certificate..."
    sudo certbot delete --cert-name "$APP_NAME.$DEFAULT_DOMAIN" --non-interactive 2>/dev/null || true
    success "SSL certificate deleted"
else
    warning "No SSL certificate found"
fi

# Step 4: Delete Cloudflare DNS record
if [ -n "$DNS_RECORD_ID" ] && [ "$DNS_RECORD_ID" != "null" ]; then
    status "Deleting Cloudflare DNS record..."
    DELETE_RESULT=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$DNS_RECORD_ID" \
        -H "Authorization: Bearer $CLOUDFLARE_API_KEY" \
        -H "Content-Type: application/json")

    if echo "$DELETE_RESULT" | jq -e '.success' >/dev/null 2>&1; then
        success "DNS record deleted"
    else
        error "Failed to delete DNS record"
    fi
else
    warning "No DNS record found"
fi

# Step 5: Remove application directory
if [ -d "/var/www/$APP_NAME" ]; then
    status "Removing application directory..."
    rm -rf "/var/www/$APP_NAME"
    success "Application directory removed"
else
    warning "No application directory found"
fi

# Step 6: Delete GitHub repository (if confirmed)
if [ "$SKIP_GITHUB" = true ]; then
    warning "GitHub repository deletion skipped (-g flag)"
elif [ "$DELETE_GITHUB" = true ]; then
    status "Deleting GitHub repository..."
    if gh repo delete "$APP_NAME" --yes 2>/dev/null; then
        success "GitHub repository deleted"
    else
        error "Failed to delete GitHub repository"
    fi
else
    warning "GitHub repository kept (not deleted)"
fi

# Calculate total time
SCRIPT_END=$(date +%s)
TOTAL_DURATION=$((SCRIPT_END - SCRIPT_START))
TOTAL_MINUTES=$((TOTAL_DURATION / 60))
TOTAL_SECONDS=$((TOTAL_DURATION % 60))

# Final Report
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              UNPROVISION COMPLETE!                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📊 Removal Summary:${NC}"
echo -e "   ${GREEN}✓${NC} Application: $APP_NAME"
echo -e "   ${GREEN}✓${NC} Total Time: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s"
echo ""
echo -e "${BLUE}📝 Removed Resources:${NC}"
for item in "${ITEMS_TO_REMOVE[@]}"; do
    echo -e "${GREEN}✓${NC}$item"
done
echo ""
