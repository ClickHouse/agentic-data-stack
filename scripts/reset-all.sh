#!/bin/bash

# Script to completely reset the Docker Compose setup
# WARNING: This will delete ALL data (databases, volumes, etc.)
# Use this for a clean slate when testing/demoing

set -e

echo "⚠️  WARNING: This will delete ALL containers, volumes, and data!"
echo "   This includes:"
echo "   - All PostgreSQL data (Langfuse)"
echo "   - All ClickHouse data"
echo "   - All MongoDB data (LibreChat)"
echo "   - All Redis data"
echo "   - All MinIO data"
echo "   - All other volumes"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Reset cancelled"
    exit 1
fi

echo ""
echo "🛑 Stopping all containers, removing volumes, and cleaning up orphans..."
docker compose down -v --remove-orphans

echo ""
echo "✅ Reset complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Regenerate credentials: ./scripts/prepare-demo.sh"
echo "   2. Start services: docker compose up -d"
echo "   3. Navigate to: http://localhost:3000 (Langfuse) and http://localhost:3080 (LibreChat) and login"
echo ""
