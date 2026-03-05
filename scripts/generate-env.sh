#!/bin/bash

# Script to generate cryptographically random credentials for all services
# This creates a .env file with secure passwords and keys

set -e

echo "Generating cryptographically random credentials..."

# Generate random passwords using openssl
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
CLICKHOUSE_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
REDIS_AUTH=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
MINIO_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)

# Generate Langfuse-specific keys
ENCRYPTION_KEY=$(openssl rand -hex 32)
NEXTAUTH_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
SALT=$(openssl rand -hex 16)

# Generate Langfuse initialization IDs (required for headless initialization)
LANGFUSE_INIT_ORG_ID="org-$(openssl rand -hex 8)"
LANGFUSE_INIT_ORG_NAME="Default Organization"
LANGFUSE_INIT_PROJECT_ID="proj-$(openssl rand -hex 8)"
LANGFUSE_INIT_PROJECT_NAME="Default Project"

# Generate Langfuse API keys (format: pk-lf-... and sk-lf-...)
LANGFUSE_INIT_PROJECT_PUBLIC_KEY="pk-lf-$(openssl rand -hex 16)"
LANGFUSE_INIT_PROJECT_SECRET_KEY="sk-lf-$(openssl rand -hex 16)"

# Generate ClickHouse MCP auth token (for HTTP transport)
CLICKHOUSE_MCP_AUTH_TOKEN=$(openssl rand -hex 32)

# Generate LibreChat-specific credentials
LIBRECHAT_PORT=${LIBRECHAT_PORT:-3080}
RAG_PORT=${RAG_PORT:-8001}
MEILI_MASTER_KEY=$(openssl rand -hex 32)
VECTORDB_DB=${VECTORDB_DB:-librechat_vectordb}
VECTORDB_USER=${VECTORDB_USER:-vectordb_user}
VECTORDB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)


# Generate LibreChat JWT secret (required for authentication)
JWT_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
JWT_REFRESH_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)

# # Prompt for user email or use default
# read -p "Enter initial Langfuse user email (default: admin@example.com): " USER_EMAIL
# USER_EMAIL=${USER_EMAIL:-admin@example.com}

# # Prompt for user password or generate one
# read -p "Enter initial Langfuse user password (default: will generate random): " USER_PASSWORD
# if [ -z "$USER_PASSWORD" ]; then
#     USER_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
#     echo "Generated password: $USER_PASSWORD"
# fi

USER_EMAIL=${USER_EMAIL:-admin@admin.com}
USER_PASSWORD=${USER_PASSWORD:-password}
USER_NAME=${USER_NAME:-Admin}


# LibreChat uses the same credentials as Langfuse
LIBRECHAT_USER_EMAIL=${USER_EMAIL}
LIBRECHAT_USER_PASSWORD=${USER_PASSWORD}
LIBRECHAT_USER_NAME=${LANGFUSE_INIT_USER_NAME}

# ClickHouse user (default is 'clickhouse' per Langfuse config)
CLICKHOUSE_USER=${CLICKHOUSE_USER:-clickhouse}

# Write to .env file
cat > .env << EOF
# Auto-generated credentials - $(date)
# DO NOT COMMIT THIS FILE - It contains secrets!

# ============================================
# PostgreSQL Configuration
# ============================================
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=postgres

# ============================================
# ClickHouse Configuration
# ============================================
CLICKHOUSE_USER=${CLICKHOUSE_USER}
CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD}

# ============================================
# ClickHouse MCP Configuration
# ============================================
CLICKHOUSE_MCP_AUTH_TOKEN=${CLICKHOUSE_MCP_AUTH_TOKEN}

# ============================================
# Redis Configuration
# ============================================
REDIS_AUTH=${REDIS_AUTH}

# ============================================
# MinIO Configuration
# ============================================
MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}

# ============================================
# Langfuse Configuration
# ============================================
ENCRYPTION_KEY=${ENCRYPTION_KEY}
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
SALT=${SALT}

# Langfuse Initialization (required for headless setup)
LANGFUSE_INIT_ORG_ID=${LANGFUSE_INIT_ORG_ID}
LANGFUSE_INIT_ORG_NAME=${LANGFUSE_INIT_ORG_NAME}
LANGFUSE_INIT_PROJECT_ID=${LANGFUSE_INIT_PROJECT_ID}
LANGFUSE_INIT_PROJECT_NAME=${LANGFUSE_INIT_PROJECT_NAME}

# Langfuse Project Keys (used by the hook)
LANGFUSE_INIT_PROJECT_PUBLIC_KEY=${LANGFUSE_INIT_PROJECT_PUBLIC_KEY}
LANGFUSE_INIT_PROJECT_SECRET_KEY=${LANGFUSE_INIT_PROJECT_SECRET_KEY}

# Your login credentials
LANGFUSE_INIT_USER_EMAIL=${USER_EMAIL}
LANGFUSE_INIT_USER_PASSWORD=${USER_PASSWORD}
LANGFUSE_INIT_USER_NAME=${USER_NAME}

# ============================================
# Langfuse Environment Variables
# ============================================
NEXTAUTH_URL=http://localhost:3000
DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/postgres
CLICKHOUSE_MIGRATION_URL=clickhouse://clickhouse:9000
CLICKHOUSE_URL=http://clickhouse:8123
CLICKHOUSE_CLUSTER_ENABLED=false

# S3/MinIO Configuration
LANGFUSE_S3_EVENT_UPLOAD_BUCKET=langfuse
LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID=minio
LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD}
LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT=http://minio:9000

LANGFUSE_S3_MEDIA_UPLOAD_BUCKET=langfuse
LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID=minio
LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD}
LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT=http://localhost:9090

REDIS_HOST=redis
REDIS_PORT=6379

# ============================================
# LibreChat Configuration
# ============================================
LIBRECHAT_PORT=${LIBRECHAT_PORT:-3080}
RAG_PORT=${RAG_PORT:-8001}
MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
VECTORDB_DB=${VECTORDB_DB:-librechat_vectordb}
VECTORDB_USER=${VECTORDB_USER:-vectordb_user}
VECTORDB_PASSWORD=${VECTORDB_PASSWORD}

# ============================================
# LibreChat Configuration
# ============================================
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}

# LibreChat Initial User
# Note: These are the same as the Langfuse credentials by default
LIBRECHAT_USER_EMAIL=${USER_EMAIL}
LIBRECHAT_USER_PASSWORD=${USER_PASSWORD}
LIBRECHAT_USER_NAME=${USER_NAME}

# LibreChat Encryption Keys (required for encrypting user API keys)
# CREDS_KEY: 64-character hex string (32 bytes) for AES-256 encryption
# CREDS_IV: 32-character hex string (16 bytes) for AES-CBC initialization vector
CREDS_KEY=$(openssl rand -hex 32)
CREDS_IV=$(openssl rand -hex 16)

# LibreChat API Keys - Set to "user_provided" to allow users to configure their own keys in the UI
ANTHROPIC_API_KEY=user_provided
GOOGLE_KEY=user_provided
OPENAI_API_KEY=user_provided

# ============================================
# LiteLLM Configuration (Optional)
# ============================================
# LiteLLM provides OpenAI-compatible proxy for AWS Bedrock and other LLM providers
LITELLM_PORT=8002

# ============================================
# AWS Bedrock Configuration (Optional)
# ============================================
# AWS credentials - can be set via AWS_PROFILE or explicit credentials
SRV_BEDROCK_AWS_PROFILE=${SRV_BEDROCK_AWS_PROFILE:-dev1}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}

# AWS Bedrock region (e.g., eu-west-3, us-east-1)
SRV_BEDROCK_REGION=${SRV_BEDROCK_REGION:-eu-west-3}

# Bedrock model ID (full ARN path)
# Examples:
#   - eu.anthropic.claude-sonnet-4-5-20250929-v1:0
#   - eu.anthropic.claude-opus-4-1-20250805-v1:0
#   - eu.anthropic.claude-haiku-3-5-sonnet-20241022-v1:0
SRV_BEDROCK_MODEL_ID=${SRV_BEDROCK_MODEL_ID:-eu.anthropic.claude-sonnet-4-5-20250929-v1:0}

# Bedrock Anthropic version
SRV_BEDROCK_ANTHROPIC_VERSION=${SRV_BEDROCK_ANTHROPIC_VERSION:-bedrock-2023-05-31}

# Model parameters
SRV_BEDROCK_MAX_TOKENS=${SRV_BEDROCK_MAX_TOKENS:-500}
SRV_BEDROCK_TEMPERATURE=${SRV_BEDROCK_TEMPERATURE:-0.7}
SRV_BEDROCK_MESSAGE_ROLE=${SRV_BEDROCK_MESSAGE_ROLE:-user}

EOF

echo ""
echo "✅ Credentials generated successfully!"
echo ""
echo "📝 Generated .env file with:"
echo "   - PostgreSQL password"
echo "   - ClickHouse password"
echo "   - Redis auth token"
echo "   - MinIO root password"
echo "   - Langfuse encryption key"
echo "   - Langfuse NextAuth secret"
echo "   - Langfuse salt"
echo "   - Langfuse API keys"
echo "   - Initial user credentials (preset)"
echo "   - ClickHouse MCP auth token"
echo "   - LiteLLM & AWS Bedrock configuration"
echo ""
echo "👤 Preset User Credentials:"
echo "   Email: ${USER_EMAIL}"
# echo "   Password: ${USER_PASSWORD}"
echo ""
echo "💡 To customize credentials, run with environment variables:"
echo "   USER_EMAIL=your@email.com USER_PASSWORD=yourpass USER_NAME=yourname ./scripts/generate-env.sh"
echo ""
echo "📡 ClickHouse MCP will be available at: http://clickhouse-mcp:8000"
echo "   Auth token: ${CLICKHOUSE_MCP_AUTH_TOKEN}"
echo ""
echo "💬 LibreChat will be available at: http://localhost:${LIBRECHAT_PORT}"
echo "   MongoDB: localhost:27017"
echo "   Meilisearch: localhost:7700"
echo "   VectorDB: localhost:5433"
echo ""
echo "🚀 LiteLLM (AWS Bedrock) will be available at: http://litellm:8000"
echo "   Configured models:"
echo "     - bedrock-claude (Claude Sonnet 4.5)"
echo "     - bedrock-claude-opus (Claude Opus 4.1)"
echo "     - bedrock-claude-haiku (Claude Haiku 3.5)"
echo "   Region: ${SRV_BEDROCK_REGION}"
echo "   Model ID: ${SRV_BEDROCK_MODEL_ID}"
echo ""
echo "📝 LibreChat Initial User (same as Langfuse)"
echo "   Email: ${USER_EMAIL}"
echo "   Password: ${USER_PASSWORD}"
echo "   Name: ${USER_NAME}"
echo "   Role: ADMIN (set automatically)"
echo ""
