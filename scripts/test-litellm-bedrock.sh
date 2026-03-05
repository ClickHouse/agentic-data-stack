#!/bin/bash

# Script to test LiteLLM connection with AWS Bedrock
# This verifies that LiteLLM can communicate with AWS Bedrock

set -e

LITELLM_PORT=${LITELLM_PORT:-8002}
LITELLM_URL="http://localhost:$LITELLM_PORT"
API_KEY="sk-litellm-default-key"

echo "🧪 Testing LiteLLM and AWS Bedrock Connection..."
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if LiteLLM is running
echo -e "${BLUE}Checking if LiteLLM is running on port $LITELLM_PORT...${NC}"

if curl -s "$LITELLM_URL/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ LiteLLM is running${NC}"
else
    echo -e "${RED}❌ LiteLLM is not responding on port $LITELLM_PORT${NC}"
    echo "   Make sure to start the stack first:"
    echo "   ${YELLOW}docker compose up -d${NC}"
    exit 1
fi

echo ""

# Test 1: Get available models
echo -e "${BLUE}Test 1: Fetching available models${NC}"
echo "GET $LITELLM_URL/v1/models"

MODELS_RESPONSE=$(curl -s -X GET "$LITELLM_URL/v1/models" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json")

if echo "$MODELS_RESPONSE" | grep -q "bedrock-claude"; then
    echo -e "${GREEN}✅ Successfully fetched models${NC}"
    echo "Available models:"
    echo "$MODELS_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sed 's/^/   - /'
else
    echo -e "${RED}❌ Failed to fetch models or bedrock-claude not found${NC}"
    echo "Response:"
    echo "$MODELS_RESPONSE" | jq . 2>/dev/null || echo "$MODELS_RESPONSE"
    exit 1
fi

echo ""

# Test 2: Test a simple completion
echo -e "${BLUE}Test 2: Testing Claude model with a simple prompt${NC}"
echo "POST $LITELLM_URL/v1/chat/completions"

COMPLETION_RESPONSE=$(curl -s -X POST "$LITELLM_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "bedrock-claude",
    "messages": [
      {"role": "user", "content": "What is 2+2? Answer in one sentence."}
    ],
    "max_tokens": 100,
    "temperature": 0.7
  }')

if echo "$COMPLETION_RESPONSE" | grep -q "choices"; then
    echo -e "${GREEN}✅ Successfully received completion from AWS Bedrock${NC}"

    # Extract and display the response
    ASSISTANT_MESSAGE=$(echo "$COMPLETION_RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null || echo "Could not parse response")

    echo "Response from Claude:"
    echo "  ${YELLOW}$ASSISTANT_MESSAGE${NC}"

    # Show usage stats
    if echo "$COMPLETION_RESPONSE" | jq '.usage' > /dev/null 2>&1; then
        INPUT_TOKENS=$(echo "$COMPLETION_RESPONSE" | jq '.usage.prompt_tokens')
        OUTPUT_TOKENS=$(echo "$COMPLETION_RESPONSE" | jq '.usage.completion_tokens')
        echo "Tokens:"
        echo "  Input: $INPUT_TOKENS"
        echo "  Output: $OUTPUT_TOKENS"
    fi
else
    echo -e "${RED}❌ Failed to receive completion${NC}"
    echo "Response:"
    echo "$COMPLETION_RESPONSE" | jq . 2>/dev/null || echo "$COMPLETION_RESPONSE"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All tests passed!${NC}"
echo ""
echo -e "${BLUE}💡 Next Steps:${NC}"
echo "1. Open LibreChat: ${YELLOW}http://localhost:3080${NC}"
echo "2. Login with your credentials"
echo "3. Select 'AWS Bedrock (via LiteLLM)' as the model provider"
echo "4. Start chatting with Claude via AWS Bedrock!"
echo ""
