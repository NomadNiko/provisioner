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
CLAUDE_MODEL_CHOICE="haiku"  # Default Claude model
while getopts "n:c:s:p:" opt; do
  case $opt in
    n) APP_NAME="$OPTARG" ;;
    c) CLAUDE_MODEL_CHOICE="$OPTARG" ;;
    s) SESSION_UUID="$OPTARG" ;;
    p) PROMPT="$OPTARG" ;;
  esac
done

# Validate required arguments
if [ -z "$APP_NAME" ] || [ -z "$PROMPT" ]; then
    error "Usage: $0 -n <app_name> -p <prompt> [-s <session_uuid>] [-c <claude_model>]"
    echo "  -n <app_name>     : Application name (required)"
    echo "  -p <prompt>       : Prompt to send to Claude (required)"
    echo "  -s <session_uuid> : Claude session UUID to resume (optional - will lookup from data)"
    echo "  -c <claude_model> : Claude model - 'haiku', 'sonnet', or 'opus' (default: 'haiku')"
    exit 1
fi

# Validate Claude model choice
if [ "$CLAUDE_MODEL_CHOICE" != "haiku" ] && [ "$CLAUDE_MODEL_CHOICE" != "sonnet" ] && [ "$CLAUDE_MODEL_CHOICE" != "opus" ]; then
    error "Invalid Claude model: $CLAUDE_MODEL_CHOICE. Must be 'haiku', 'sonnet', or 'opus'"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Site Update Script                               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Load .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    error ".env file not found at $SCRIPT_DIR/.env"
    exit 1
fi
source "$SCRIPT_DIR/.env"

# Map Claude model choice to model ID from .env
case "$CLAUDE_MODEL_CHOICE" in
    haiku)
        CLAUDE_MODEL_ID="$CLAUDE_MODEL_HAIKU"
        ;;
    sonnet)
        CLAUDE_MODEL_ID="$CLAUDE_MODEL_SONNET"
        ;;
    opus)
        CLAUDE_MODEL_ID="$CLAUDE_MODEL_OPUS"
        ;;
esac

# Verify application directory exists
APP_DIR="/var/www/$APP_NAME"
if [ ! -d "$APP_DIR" ]; then
    error "Application directory not found: $APP_DIR"
    exit 1
fi

# Look up UUID if not provided
if [ -z "$SESSION_UUID" ]; then
    UUID_DATA_FILE="$SCRIPT_DIR/data/uuid.json"
    if [ ! -f "$UUID_DATA_FILE" ]; then
        error "UUID data file not found at $UUID_DATA_FILE"
        error "Please provide session UUID with -s flag"
        exit 1
    fi

    SESSION_UUID=$(jq -r --arg app "$APP_NAME" '.[$app] // empty' "$UUID_DATA_FILE")

    if [ -z "$SESSION_UUID" ]; then
        error "No UUID found for application: $APP_NAME"
        error "Please provide session UUID with -s flag"
        exit 1
    fi

    status "UUID retrieved from data store: $SESSION_UUID"
fi

status "Updating site: $APP_NAME"
status "Using Claude model: $CLAUDE_MODEL_CHOICE ($CLAUDE_MODEL_ID)"
status "Session UUID: $SESSION_UUID"
echo ""

# Change to application directory
cd "$APP_DIR" || exit 1
status "Changed directory to: $APP_DIR"

# Run Claude command
status "Running Claude AI update..."
echo -e "${YELLOW}   Prompt: $PROMPT${NC}"
echo ""
CLAUDE_START=$(date +%s)

claude -p "$PROMPT" \
    --model "$CLAUDE_MODEL_ID" \
    --resume "$SESSION_UUID" \
    --dangerously-skip-permissions \
    --output-format=json < /dev/null

CLAUDE_EXIT_CODE=$?
CLAUDE_END=$(date +%s)
CLAUDE_DURATION=$((CLAUDE_END - CLAUDE_START))

echo ""

# Check if Claude command succeeded
if [ $CLAUDE_EXIT_CODE -eq 0 ]; then
    success "Claude AI update completed in ${CLAUDE_DURATION}s"
else
    error "Claude AI update failed with exit code: $CLAUDE_EXIT_CODE"
    exit $CLAUDE_EXIT_CODE
fi

# Calculate total time
SCRIPT_END=$(date +%s)
TOTAL_DURATION=$((SCRIPT_END - SCRIPT_START))
TOTAL_MINUTES=$((TOTAL_DURATION / 60))
TOTAL_SECONDS=$((TOTAL_DURATION % 60))

# Final Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              UPDATE COMPLETE!                              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📊 Update Summary:${NC}"
echo -e "   ${GREEN}✓${NC} Application: $APP_NAME"
echo -e "   ${GREEN}✓${NC} Directory: $APP_DIR"
echo -e "   ${GREEN}✓${NC} Claude Model: $CLAUDE_MODEL_CHOICE ($CLAUDE_MODEL_ID)"
echo -e "   ${GREEN}✓${NC} Session UUID: $SESSION_UUID"
echo -e "   ${GREEN}✓${NC} Update Duration: ${CLAUDE_DURATION}s"
echo -e "   ${GREEN}✓${NC} Total Time: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo -e "   1. Review changes: ${YELLOW}cd $APP_DIR && git status${NC}"
echo -e "   2. Test locally: ${YELLOW}npm run dev${NC}"
echo -e "   3. Continue session: ${YELLOW}claude --resume $SESSION_UUID${NC}"
echo ""
