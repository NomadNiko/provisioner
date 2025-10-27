#!/bin/bash

# Template Builder Script
# Rebuilds all templates with dependencies and production builds
# Run this after cloning the repository to a new server

set -e  # Exit on error

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Enhanced color palette
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

# Helper functions
section_header() {
    echo ""
    echo -e "${BRIGHT_CYAN}╭─────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${BRIGHT_CYAN}│${NC} ${WHITE}${BOLD}$1${NC}"
    echo -e "${BRIGHT_CYAN}╰─────────────────────────────────────────────────────────────────╯${NC}"
}

status() {
    echo -e "${BLUE}▸${NC} $1"
}

success() {
    echo -e "${BRIGHT_GREEN}✓${NC} $1"
}

error() {
    echo -e "${BRIGHT_RED}✗${NC} ${BOLD}$1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ${NC} ${DIM}$1${NC}"
}

# Clear screen and show header
clear
echo ""
echo -e "${BRIGHT_CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BRIGHT_CYAN}║${NC}                                                               ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}║${NC}              ${WHITE}${BOLD}Template Build System${NC}                         ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}║${NC}                                                               ${BRIGHT_CYAN}║${NC}"
echo -e "${BRIGHT_CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

section_header "System Check"
echo ""

# Check if templates directory exists
if [ ! -d "$TEMPLATES_DIR" ]; then
    error "Templates directory not found: $TEMPLATES_DIR"
    exit 1
fi

success "Templates directory found"
info "Location: $TEMPLATES_DIR"

# Count templates
TEMPLATE_COUNT=$(ls -1 "$TEMPLATES_DIR" | wc -l)
success "Found $TEMPLATE_COUNT templates"
echo ""

# Track results
declare -a SUCCESSFUL_TEMPLATES
declare -a FAILED_TEMPLATES
declare -a SKIPPED_TEMPLATES

START_TIME=$(date +%s)

section_header "Building Templates"
echo ""

# Process each template
CURRENT=0
for TEMPLATE_DIR in "$TEMPLATES_DIR"/*; do
    if [ ! -d "$TEMPLATE_DIR" ]; then
        continue
    fi

    CURRENT=$((CURRENT + 1))
    TEMPLATE_NAME=$(basename "$TEMPLATE_DIR")

    echo -e "${BRIGHT_MAGENTA}┌─ Template $CURRENT/$TEMPLATE_COUNT: ${WHITE}${BOLD}$TEMPLATE_NAME${NC}"
    echo -e "${BRIGHT_MAGENTA}│${NC}"

    # Check if package.json exists
    if [ ! -f "$TEMPLATE_DIR/package.json" ]; then
        echo -e "${BRIGHT_MAGENTA}│${NC} ${YELLOW}⚠${NC} No package.json found"
        echo -e "${BRIGHT_MAGENTA}│${NC} ${CYAN}ℹ${NC} ${DIM}Skipping (not a Node.js project)${NC}"
        echo -e "${BRIGHT_MAGENTA}└─${NC} ${GRAY}Skipped${NC}"
        echo ""
        SKIPPED_TEMPLATES+=("$TEMPLATE_NAME")
        continue
    fi

    cd "$TEMPLATE_DIR"

    # Step 1: Install dependencies
    echo -e "${BRIGHT_MAGENTA}│${NC} ${BLUE}▸${NC} Installing dependencies..."
    if npm install > /tmp/build-${TEMPLATE_NAME}-install.log 2>&1; then
        echo -e "${BRIGHT_MAGENTA}│${NC} ${BRIGHT_GREEN}✓${NC} Dependencies installed"
        PKG_COUNT=$(ls -1 node_modules | wc -l)
        echo -e "${BRIGHT_MAGENTA}│${NC} ${CYAN}ℹ${NC} ${DIM}$PKG_COUNT packages${NC}"
    else
        echo -e "${BRIGHT_MAGENTA}│${NC} ${BRIGHT_RED}✗${NC} ${BOLD}npm install failed${NC}"
        echo -e "${BRIGHT_MAGENTA}│${NC} ${CYAN}ℹ${NC} ${DIM}Check log: /tmp/build-${TEMPLATE_NAME}-install.log${NC}"
        echo -e "${BRIGHT_MAGENTA}└─${NC} ${BRIGHT_RED}Failed${NC}"
        echo ""
        FAILED_TEMPLATES+=("$TEMPLATE_NAME")
        continue
    fi

    # Step 2: Build (skip for saas template)
    if [ "$TEMPLATE_NAME" = "saas" ]; then
        echo -e "${BRIGHT_MAGENTA}│${NC} ${YELLOW}⚠${NC} Skipping build (requires MongoDB)"
        echo -e "${BRIGHT_MAGENTA}│${NC} ${CYAN}ℹ${NC} ${DIM}SaaS template builds per-deployment${NC}"
        echo -e "${BRIGHT_MAGENTA}└─${NC} ${BRIGHT_GREEN}Complete${NC} ${GRAY}(dependencies only)${NC}"
        echo ""
        SUCCESSFUL_TEMPLATES+=("$TEMPLATE_NAME (deps only)")
    else
        echo -e "${BRIGHT_MAGENTA}│${NC} ${BLUE}▸${NC} Building for production..."
        if npm run build > /tmp/build-${TEMPLATE_NAME}-build.log 2>&1; then
            echo -e "${BRIGHT_MAGENTA}│${NC} ${BRIGHT_GREEN}✓${NC} Production build completed"

            # Check for build artifacts
            if [ -f ".next/BUILD_ID" ]; then
                BUILD_ID=$(cat .next/BUILD_ID)
                echo -e "${BRIGHT_MAGENTA}│${NC} ${CYAN}ℹ${NC} ${DIM}Build ID: $BUILD_ID${NC}"
            elif [ -d "build" ]; then
                BUILD_SIZE=$(du -sh build | cut -f1)
                echo -e "${BRIGHT_MAGENTA}│${NC} ${CYAN}ℹ${NC} ${DIM}Build size: $BUILD_SIZE${NC}"
            fi

            echo -e "${BRIGHT_MAGENTA}└─${NC} ${BRIGHT_GREEN}Complete${NC}"
            echo ""
            SUCCESSFUL_TEMPLATES+=("$TEMPLATE_NAME")
        else
            echo -e "${BRIGHT_MAGENTA}│${NC} ${BRIGHT_RED}✗${NC} ${BOLD}Build failed${NC}"
            echo -e "${BRIGHT_MAGENTA}│${NC} ${CYAN}ℹ${NC} ${DIM}Check log: /tmp/build-${TEMPLATE_NAME}-build.log${NC}"
            echo -e "${BRIGHT_MAGENTA}└─${NC} ${BRIGHT_RED}Failed${NC}"
            echo ""
            FAILED_TEMPLATES+=("$TEMPLATE_NAME")
        fi
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Show summary
echo ""
echo -e "${BRIGHT_GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BRIGHT_GREEN}║${NC}                                                               ${BRIGHT_GREEN}║${NC}"
echo -e "${BRIGHT_GREEN}║${NC}          ${WHITE}${BOLD}✓  TEMPLATE BUILD COMPLETE  ✓${NC}                   ${BRIGHT_GREEN}║${NC}"
echo -e "${BRIGHT_GREEN}║${NC}                                                               ${BRIGHT_GREEN}║${NC}"
echo -e "${BRIGHT_GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

section_header "Build Summary"
echo ""
echo -e "   ${CYAN}Total Time:${NC}         ${WHITE}${MINUTES}m ${SECONDS}s${NC}"
echo -e "   ${CYAN}Templates Found:${NC}    ${WHITE}$TEMPLATE_COUNT${NC}"
echo -e "   ${CYAN}Successfully Built:${NC} ${BRIGHT_GREEN}${#SUCCESSFUL_TEMPLATES[@]}${NC}"
if [ ${#FAILED_TEMPLATES[@]} -gt 0 ]; then
    echo -e "   ${CYAN}Failed:${NC}             ${BRIGHT_RED}${#FAILED_TEMPLATES[@]}${NC}"
fi
if [ ${#SKIPPED_TEMPLATES[@]} -gt 0 ]; then
    echo -e "   ${CYAN}Skipped:${NC}            ${YELLOW}${#SKIPPED_TEMPLATES[@]}${NC}"
fi
echo ""

# Show successful templates
if [ ${#SUCCESSFUL_TEMPLATES[@]} -gt 0 ]; then
    echo -e "${BRIGHT_GREEN}Successfully Built Templates:${NC}"
    for template in "${SUCCESSFUL_TEMPLATES[@]}"; do
        echo -e "   ${BRIGHT_GREEN}✓${NC} $template"
    done
    echo ""
fi

# Show failed templates
if [ ${#FAILED_TEMPLATES[@]} -gt 0 ]; then
    echo -e "${BRIGHT_RED}Failed Templates:${NC}"
    for template in "${FAILED_TEMPLATES[@]}"; do
        echo -e "   ${BRIGHT_RED}✗${NC} $template"
        echo -e "      ${GRAY}Check logs: /tmp/build-${template}-*.log${NC}"
    done
    echo ""
fi

# Show skipped templates
if [ ${#SKIPPED_TEMPLATES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Skipped Templates:${NC}"
    for template in "${SKIPPED_TEMPLATES[@]}"; do
        echo -e "   ${YELLOW}⚠${NC} $template"
    done
    echo ""
fi

section_header "Next Steps"
echo ""
echo -e "   ${BRIGHT_GREEN}✓${NC} Templates are ready for provisioning"
echo -e "   ${CYAN}ℹ${NC} ${DIM}You can now use ./provisioner.sh to deploy apps${NC}"
echo ""
echo -e "   ${CYAN}Quick test:${NC}"
echo -e "      ${GRAY}$${NC} ${YELLOW}./provisioner.sh -n test-app -t new${NC}"
echo ""

echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${DIM}Build completed at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Exit with error if any templates failed
if [ ${#FAILED_TEMPLATES[@]} -gt 0 ]; then
    exit 1
fi

exit 0
