#!/usr/bin/env bash
# Build and install the fbsql extension inside a temporary fbsql-dev container,
# then run the pg_regress suite (make installcheck). Assumes the image was
# built with scripts/docker-build.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER=fbsql-installcheck

docker run --rm -d --name "$CONTAINER" \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -v "$PWD":/workspace -w /workspace \
    fbsql-dev >/dev/null

cleanup() {
    # pg_regress output lands in the bind mount as root-owned files;
    # hand them back to the invoking user before stopping the container.
    docker exec "$CONTAINER" chown -R "$(id -u):$(id -g)" test/ \
        >/dev/null 2>&1 || true
    docker stop "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

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

docker exec -e PGUSER=postgres "$CONTAINER" make
docker exec -e PGUSER=postgres "$CONTAINER" make install
docker exec -e PGUSER=postgres "$CONTAINER" make installcheck

echo "OK: extension installs and pg_regress passes."
