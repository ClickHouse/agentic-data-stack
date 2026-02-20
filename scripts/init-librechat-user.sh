#!/bin/sh

# Automatic LibreChat user initialization script
# This runs once during docker-compose up and creates the default admin user
# This script runs in a docker:cli container with access to docker socket

set -e

echo "=================================================="
echo "LibreChat User Initialization"
echo "=================================================="
echo ""

# Read credentials from environment variables (passed from .env)
LIBRECHAT_USER_EMAIL=${LANGFUSE_INIT_USER_EMAIL:-admin@admin.com}
LIBRECHAT_USER_PASSWORD=${LANGFUSE_INIT_USER_PASSWORD:-password}
LIBRECHAT_USER_NAME=${LANGFUSE_INIT_USER_NAME:-Admin}
USERNAME=$(echo ${LIBRECHAT_USER_EMAIL} | cut -d'@' -f1)

echo "Target user: ${LIBRECHAT_USER_EMAIL}"
echo ""

# Get exact container names from docker
LIBRECHAT_CONTAINER=$(docker ps --filter "name=librechat" --filter "status=running" --format "{{.Names}}" | grep -E "librechat-[0-9]+$" | head -n1)
MONGODB_CONTAINER=$(docker ps --filter "name=mongodb" --filter "status=running" --format "{{.Names}}" | grep -E "mongodb-[0-9]+$" | head -n1)

if [ -z "$LIBRECHAT_CONTAINER" ]; then
    echo "❌ Error: Could not find running LibreChat container"
    exit 1
fi

if [ -z "$MONGODB_CONTAINER" ]; then
    echo "❌ Error: Could not find running MongoDB container"
    exit 1
fi

echo "LibreChat container: ${LIBRECHAT_CONTAINER}"
echo "MongoDB container: ${MONGODB_CONTAINER}"
echo ""

# Wait a moment for containers to settle
sleep 3

# Check if user already exists
echo "Checking if user already exists..."
USER_EXISTS=$(docker exec ${MONGODB_CONTAINER} mongosh LibreChat --quiet --eval "
db.users.countDocuments({ email: '${LIBRECHAT_USER_EMAIL}' })
" 2>/dev/null | tail -n 1 | tr -d '[:space:]' || echo "0")

if ! echo "$USER_EXISTS" | grep -Eq '^[0-9]+$'; then
    USER_EXISTS="0"
fi
if [ "$USER_EXISTS" -gt 0 ]; then
    echo "✅ User ${LIBRECHAT_USER_EMAIL} already exists"
    echo "   Skipping user creation"
    echo ""
    echo "🌐 LibreChat is ready at: http://localhost:${LIBRECHAT_PORT:-3080}"
    echo ""
    exit 0
fi

echo "📝 User does not exist, creating..."
echo ""

# Create the user using LibreChat's npm command
echo "Creating user with LibreChat CLI..."
echo "Y" | docker exec -i ${LIBRECHAT_CONTAINER} npm run create-user \
  "${LIBRECHAT_USER_EMAIL}" \
  "${LIBRECHAT_USER_NAME}" \
  "${USERNAME}" \
  "${LIBRECHAT_USER_PASSWORD}"

# Make the user an admin
echo ""
echo "Setting user as admin..."
docker exec ${MONGODB_CONTAINER} mongosh LibreChat --quiet --eval "
db.users.updateOne(
  { email: '${LIBRECHAT_USER_EMAIL}' },
  { \$set: { role: 'ADMIN' } }
)
" > /dev/null 2>&1

echo ""
echo "=================================================="
echo "✅ LibreChat Initialization Complete!"
echo "=================================================="
echo ""
echo "📝 Login credentials:"
echo "   Email:    ${LIBRECHAT_USER_EMAIL}"
echo "   Password: ${LIBRECHAT_USER_PASSWORD}"
echo "   Role:     ADMIN"
echo ""
echo "🌐 LibreChat is ready at: http://localhost:${LIBRECHAT_PORT:-3080}"
echo ""
