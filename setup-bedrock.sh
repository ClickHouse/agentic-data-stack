#!/bin/bash

# Quick setup script for AWS Bedrock integration
# This script generates environment and checks configuration in one step

set -e

echo "🚀 Agentic Data Stack - AWS Bedrock Quick Setup"
echo "=============================================="
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: This script must be run from the agentic-data-stack directory"
    exit 1
fi

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Step 1: Generating environment variables${NC}"
echo "-------------------------------------------"

# Generate .env file
USER_EMAIL=${USER_EMAIL:-"admin@example.com"}
USER_PASSWORD=${USER_PASSWORD:-"supersecret"}
USER_NAME=${USER_NAME:-"Admin"}

echo "Generating .env with:"
echo "  Email: $USER_EMAIL"
echo "  Name: $USER_NAME"
echo ""

./scripts/generate-env.sh

echo ""
echo -e "${BLUE}Step 2: Verifying AWS Bedrock configuration${NC}"
echo "---------------------------------------------"

# Check bedrock config
./scripts/check-bedrock-config.sh

echo ""
echo -e "${BLUE}Step 3: Summary${NC}"
echo "----------------"
echo -e "${GREEN}✅ All setup complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Start the stack:      ${BLUE}docker compose up -d${NC}"
echo "2. Wait 30-60 seconds for services to start"
echo "3. Test Bedrock:         ${BLUE}./scripts/test-litellm-bedrock.sh${NC}"
echo "4. Open LibreChat:       ${BLUE}http://localhost:3080${NC}"
echo ""
echo "Your AWS Bedrock configuration:"
echo "  Region:   ${BLUE}$SRV_BEDROCK_REGION${NC}"
echo "  Model ID: ${BLUE}$SRV_BEDROCK_MODEL_ID${NC}"
echo ""
