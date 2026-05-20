#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="flu-postgres"
PASSWORD="fluwarehouse123"
PORT="5432"
DB_NAME="flu_warehouse"

echo "Checking Docker..."
if ! docker ps >/dev/null 2>&1; then
  echo "Start Docker Desktop (or the Docker daemon) first."
  exit 1
fi

wait_ready() {
  for i in $(seq 1 30); do
    if docker exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Postgres did not become ready in time."
  exit 1
}

if docker ps -a --filter "name=$CONTAINER_NAME" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Starting existing container $CONTAINER_NAME"
  docker start "$CONTAINER_NAME" >/dev/null
  wait_ready
else
  echo "Creating container $CONTAINER_NAME"
  docker run -d \
    --name "$CONTAINER_NAME" \
    -e POSTGRES_PASSWORD="$PASSWORD" \
    -e POSTGRES_DB="$DB_NAME" \
    -p "${PORT}:5432" \
    postgres:16 >/dev/null
  echo "Waiting for Postgres to accept connections..."
  wait_ready
fi

export POSTGRES_URL="postgresql://postgres:${PASSWORD}@localhost:${PORT}/${DB_NAME}"
echo "POSTGRES_URL=$POSTGRES_URL"
echo "Run: ./run_pipeline_warehouse.sh"
