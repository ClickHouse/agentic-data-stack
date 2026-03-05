#!/bin/bash

# Script to verify AWS Bedrock configuration
# This checks that all necessary AWS credentials and settings are properly configured

set -e

echo "🔍 Checking AWS Bedrock Configuration..."
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found${NC}"
    echo "Please run: ./scripts/generate-env.sh first"
    exit 1
fi

# Source the .env file
source .env

echo -e "${BLUE}📋 Configuration Summary${NC}"
echo "================================"

# Check AWS Profile vs explicit credentials
if [ -n "$SRV_BEDROCK_AWS_PROFILE" ]; then
    echo -e "${BLUE}AWS Profile:${NC} $SRV_BEDROCK_AWS_PROFILE"

    # Check if profile exists in ~/.aws/credentials
    if [ -f ~/.aws/credentials ]; then
        if grep -q "\[$SRV_BEDROCK_AWS_PROFILE\]" ~/.aws/credentials; then
            echo -e "${GREEN}✅ AWS Profile found in ~/.aws/credentials${NC}"
        else
            echo -e "${RED}❌ AWS Profile '$SRV_BEDROCK_AWS_PROFILE' not found in ~/.aws/credentials${NC}"
            echo "   Available profiles:"
            grep "^\[" ~/.aws/credentials | sed 's/\[\|\]//g' | sed 's/^/     /'
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  ~/.aws/credentials not found, relying on environment variables${NC}"
    fi
else
    echo -e "${BLUE}AWS Credentials:${NC} Using AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"

    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo -e "${RED}❌ AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY not set${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ AWS credentials are set${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Bedrock Configuration:${NC}"
echo -e "  Region: ${YELLOW}$SRV_BEDROCK_REGION${NC}"
echo -e "  Model ID: ${YELLOW}$SRV_BEDROCK_MODEL_ID${NC}"
echo -e "  Anthropic Version: ${YELLOW}$SRV_BEDROCK_ANTHROPIC_VERSION${NC}"
echo -e "  Max Tokens: ${YELLOW}$SRV_BEDROCK_MAX_TOKENS${NC}"
echo -e "  Temperature: ${YELLOW}$SRV_BEDROCK_TEMPERATURE${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    echo "   Please install it from: https://aws.amazon.com/cli/"
    exit 1
else
    echo -e "${GREEN}✅ AWS CLI is installed${NC}"
fi

# Check AWS credentials validity
echo ""
echo -e "${BLUE}Testing AWS Credentials...${NC}"

# Set the region for AWS CLI calls
export AWS_REGION=$SRV_BEDROCK_REGION
if [ -n "$SRV_BEDROCK_AWS_PROFILE" ]; then
    export AWS_PROFILE=$SRV_BEDROCK_AWS_PROFILE
fi

if aws sts get-caller-identity --query 'Account' --output text &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    echo -e "${GREEN}✅ AWS credentials are valid${NC}"
    echo -e "   Account ID: ${YELLOW}$ACCOUNT_ID${NC}"
else
    echo -e "${RED}❌ AWS credentials are invalid or not set correctly${NC}"
    echo "   Please check your AWS configuration"
    exit 1
fi

# Check if Bedrock is available in the region
echo ""
echo -e "${BLUE}Checking Bedrock availability in region: $SRV_BEDROCK_REGION${NC}"

if aws bedrock list-foundation-models --region $SRV_BEDROCK_REGION --output json &> /dev/null; then
    echo -e "${GREEN}✅ Bedrock is available in region: $SRV_BEDROCK_REGION${NC}"

    # List available Anthropic models
    echo ""
    echo -e "${BLUE}Available Anthropic Claude models:${NC}"
    aws bedrock list-foundation-models \
        --region $SRV_BEDROCK_REGION \
        --by-provider ANTHROPIC \
        --query 'modelSummaries[*].[modelId,modelName]' \
        --output table || echo -e "${YELLOW}Could not list models${NC}"
else
    echo -e "${RED}❌ Bedrock is not available in region: $SRV_BEDROCK_REGION${NC}"
    echo "   Please check that:"
    echo "   1. The region is correct (e.g., eu-west-3, us-east-1)"
    echo "   2. Bedrock is available in that region"
    echo "   3. Your AWS account has Bedrock access"
    exit 1
fi

# Extract the model provider and name from the model ID
IFS='.' read -r PROVIDER_REGION PROVIDER MODEL_ID <<< "$SRV_BEDROCK_MODEL_ID"
echo ""
echo -e "${BLUE}Checking if the configured model is available...${NC}"
echo -e "  Looking for model: ${YELLOW}$SRV_BEDROCK_MODEL_ID${NC}"

# Check if the model exists
if aws bedrock get-foundation-model \
    --region $SRV_BEDROCK_REGION \
    --model-identifier "$SRV_BEDROCK_MODEL_ID" \
    --output json &> /dev/null; then
    echo -e "${GREEN}✅ Model is available: $SRV_BEDROCK_MODEL_ID${NC}"
else
    echo -e "${YELLOW}⚠️  Model not found or not available yet${NC}"
    echo "   You may need to:"
    echo "   1. Request access to the model in your AWS console"
    echo "   2. Wait for access to be granted (can take a few minutes)"
    echo "   3. Try a different region"
fi

echo ""
echo -e "${BLUE}💡 Next Steps:${NC}"
echo "1. Configure your .env file with AWS credentials (already done ✅)"
echo "2. Start the stack: ${YELLOW}docker compose up -d${NC}"
echo "3. Check LiteLLM logs: ${YELLOW}docker compose logs litellm -f${NC}"
echo "4. Test the connection:"
echo "   ${YELLOW}curl http://localhost:8002/health${NC}"
echo ""
echo -e "${GREEN}✅ AWS Bedrock configuration is ready!${NC}"
