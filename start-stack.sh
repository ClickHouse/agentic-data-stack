#!/bin/bash

# Complete Startup Guide for AWS Bedrock Integration
# This script starts all services and verifies they're running

set -e

echo "🚀 Starting AWS Bedrock + LiteLLM Stack"
echo "========================================"
echo ""

# Check we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found"
    echo "Please run this script from the agentic-data-stack directory"
    exit 1
fi

echo "📋 Step 1: Starting all services..."
docker compose up -d

echo ""
echo "⏱️  Step 2: Waiting for services to start (30 seconds)..."
sleep 30

echo ""
echo "🔍 Step 3: Checking service status..."
docker compose ps

echo ""
echo "📊 Step 4: Checking LiteLLM logs..."
docker compose logs litellm --tail 20

echo ""
echo "🧪 Step 5: Testing LiteLLM health..."
if curl -s http://localhost:8002/health > /dev/null 2>&1; then
    echo "✅ LiteLLM is responding on port 8002"
else
    echo "⚠️  LiteLLM not responding yet. Check logs:"
    echo "   docker compose logs litellm -f"
fi

echo ""
echo "🎯 Next steps:"
echo "1. Wait a few more seconds if services are still starting"
echo "2. Run: ./scripts/test-litellm-bedrock.sh"
echo "3. Open: http://localhost:3080"
echo ""
