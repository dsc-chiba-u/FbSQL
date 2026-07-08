#!/usr/bin/env bash
# Start a temporary fbsql-dev container, verify CREATE EXTENSION plr and a
# round-trip through R, then clean up. Assumes scripts/docker-build.sh ran.
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER=fbsql-check-plr

docker run --rm -d --name "$CONTAINER" \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    fbsql-dev >/dev/null
trap 'docker stop "$CONTAINER" >/dev/null 2>&1 || true' EXIT

echo "Waiting for PostgreSQL to become ready..."
for _ in $(seq 1 60); do
    if docker exec "$CONTAINER" psql -U postgres -c "SELECT 1" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
# The official image restarts the server once after init scripts; give the
# final server a moment so we don't hit the temporary bootstrap instance.
sleep 2
docker exec "$CONTAINER" psql -U postgres -c "SELECT 1" >/dev/null

docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 < scripts/check-plr.sql

echo "OK: PL/R is installed and runs R inside PostgreSQL."
