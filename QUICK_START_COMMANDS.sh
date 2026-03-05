#!/bin/bash

# AWS Bedrock Integration - Copy & Paste Commands
# Run these commands in order to get started

echo "🚀 AWS Bedrock + LiteLLM - Quick Start Commands"
echo "=============================================="
echo ""
echo "Copy & paste these commands in your terminal:"
echo ""

cat << 'EOF'
# 1. Navigate to the project directory
cd /Users/cbismuth/Desktop/backup/git/github/cbismuth/agentic-data-stack

# 2. Generate environment configuration with AWS Bedrock settings
./scripts/generate-env.sh

# 3. Verify AWS Bedrock configuration (IMPORTANT - catches most issues)
./scripts/check-bedrock-config.sh

# 4. Start all services including LiteLLM
docker compose up -d

# 5. Wait 30-60 seconds for services to start, then test the connection
./scripts/test-litellm-bedrock.sh

# 6. Open LibreChat in your browser
open http://localhost:3080

# 7. In LibreChat:
#    - Login with the credentials from .env
#    - Click Settings → Model Selection
#    - Choose "AWS Bedrock (via LiteLLM)"
#    - Select a Claude model (Sonnet, Opus, or Haiku)
#    - Start chatting!

EOF

echo ""
echo "✨ That's it! You're done!"
echo ""
echo "📚 Documentation:"
echo "   - Start with: AWS_BEDROCK_SETUP.md"
echo "   - Architecture: LITELLM_INTEGRATION.md"
echo "   - Changes made: IMPLEMENTATION_CHECKLIST.md"
echo ""
