#!/bin/sh
# Railway-compatible LibreChat startup script.
# Creates the initial admin user before starting the server.
# Used by Dockerfile.librechat — does not affect docker-compose users.

set -e

MONGO_URI="${MONGO_URI:-mongodb://mongodb:27017/LibreChat}"

echo "=================================================="
echo "LibreChat Railway Init"
echo "=================================================="

# Wait for MongoDB to be reachable
echo "Waiting for MongoDB..."
until node -e "
const { MongoClient } = require('mongodb');
MongoClient.connect(process.env.MONGO_URI || '$MONGO_URI')
  .then(c => { c.close(); process.exit(0); })
  .catch(() => process.exit(1));
" 2>/dev/null; do
  echo "  MongoDB not ready, retrying in 3s..."
  sleep 3
done
echo "MongoDB is ready!"
echo ""

# Create initial user if credentials are provided
if [ -n "$LIBRECHAT_USER_EMAIL" ] && [ -n "$LIBRECHAT_USER_PASSWORD" ]; then
  USERNAME=$(echo "$LIBRECHAT_USER_EMAIL" | cut -d'@' -f1)
  LIBRECHAT_USER_NAME="${LIBRECHAT_USER_NAME:-Admin}"

  echo "Creating user: $LIBRECHAT_USER_EMAIL"
  echo "Y" | npm run create-user \
    "$LIBRECHAT_USER_EMAIL" \
    "$LIBRECHAT_USER_NAME" \
    "$USERNAME" \
    "$LIBRECHAT_USER_PASSWORD" 2>&1 || true

  # Set user as admin using the mongodb driver already installed in LibreChat
  node -e "
const { MongoClient } = require('mongodb');
(async () => {
  const client = await MongoClient.connect(process.env.MONGO_URI || '$MONGO_URI');
  const db = client.db();
  const result = await db.collection('users').updateOne(
    { email: '$LIBRECHAT_USER_EMAIL' },
    { \$set: { role: 'ADMIN' } }
  );
  if (result.matchedCount > 0) {
    console.log('User set as ADMIN');
  } else {
    console.log('Warning: user not found for admin role update');
  }
  await client.close();
})().catch(e => console.error('Failed to set admin role:', e.message));
" 2>&1 || true

  echo ""
  echo "User initialization complete!"
  echo ""
fi

# Start LibreChat
echo "Starting LibreChat..."
exec node api/server/index.js
