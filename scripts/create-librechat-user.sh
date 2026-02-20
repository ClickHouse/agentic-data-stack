#!/bin/bash

# Script to create an initial LibreChat admin user
# Run this after LibreChat is started: ./scripts/create-librechat-user.sh

set -e

echo "Creating LibreChat admin user..."

# Load .env file to read Langfuse credentials
if [ -f .env ]; then
    export $(grep -v '^#' .env | grep -E '^(LANGFUSE_INIT_USER_EMAIL|LANGFUSE_INIT_USER_PASSWORD|LANGFUSE_INIT_USER_NAME)=' | xargs)
fi

# Read credentials from .env - reuse Langfuse user credentials
LIBRECHAT_USER_EMAIL=${LANGFUSE_INIT_USER_EMAIL:-admin@example.com}
LIBRECHAT_USER_PASSWORD=${LANGFUSE_INIT_USER_PASSWORD:-changeme123}
LIBRECHAT_USER_NAME=${LANGFUSE_INIT_USER_NAME:-Admin}

# Get MongoDB connection from .env
MONGO_URI=${MONGO_URI:-mongodb://mongodb:27017/LibreChat}

echo "Email: ${LIBRECHAT_USER_EMAIL}"
echo "Password: ${LIBRECHAT_USER_PASSWORD}"
echo "Name: ${LIBRECHAT_USER_NAME}"
echo ""

# Check if LibreChat service is running
LIBRECHAT_STATUS=$(docker compose ps librechat --format "{{.Status}}" 2>/dev/null || echo "")
if [ -z "$LIBRECHAT_STATUS" ] || ! echo "$LIBRECHAT_STATUS" | grep -qiE "(up|running)"; then
    echo "❌ Error: LibreChat service is not running"
    echo "   Start it first with: docker compose up -d librechat"
    echo ""
    echo "Current LibreChat status:"
    docker compose ps librechat 2>/dev/null || echo "   (service not found)"
    exit 1
fi

echo "LibreChat is running!"
echo ""

# Create admin user using LibreChat's create-user command
# Usage: npm run create-user <email> <name> <username> [password]
# Username will be derived from email if not provided
USERNAME=$(echo ${LIBRECHAT_USER_EMAIL} | cut -d'@' -f1)

echo "Creating admin user in LibreChat container..."
echo "Email: ${LIBRECHAT_USER_EMAIL}"
echo "Name: ${LIBRECHAT_USER_NAME}"
echo "Username: ${USERNAME}"
echo ""

# Pass arguments directly to the command
docker compose exec -T librechat npm run create-user \
  "${LIBRECHAT_USER_EMAIL}" \
  "${LIBRECHAT_USER_NAME}" \
  "${USERNAME}" \
  "${LIBRECHAT_USER_PASSWORD}"

# Make the user an admin by updating MongoDB directly
echo ""
echo "Setting user as admin..."
# docker compose exec uses service names
docker compose exec -T mongodb mongosh LibreChat --eval "
db.users.updateOne(
  { email: '${LIBRECHAT_USER_EMAIL}' },
  { \$set: { role: 'ADMIN' } }
)
"

echo ""
echo "✅ User created successfully!"
echo ""
echo "📝 Login credentials:"
echo "   Email: ${LIBRECHAT_USER_EMAIL}"
echo "   Password: ${LIBRECHAT_USER_PASSWORD}"
echo ""
echo "⚠️  IMPORTANT: Change the password after first login!"
echo "   Access LibreChat at: http://localhost:${LIBRECHAT_PORT:-3080}"
echo ""
