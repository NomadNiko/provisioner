#!/bin/bash

# Color codes for better visibility
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║              SCRIPT DEPRECATED                             ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠  This script has been deprecated.${NC}"
echo ""
echo -e "Claude AI integration has been removed from the provisioning system"
echo -e "due to stability issues and system crashes."
echo ""
echo -e "The provisioner now only scaffolds Next.js applications without"
echo -e "automated Claude engineering."
echo ""
echo -e "To customize your application:"
echo -e "  1. Navigate to your app directory: ${YELLOW}cd /var/www/<app-name>${NC}"
echo -e "  2. Make manual changes or use Claude CLI directly"
echo -e "  3. Test and deploy your changes manually"
echo ""
exit 1
