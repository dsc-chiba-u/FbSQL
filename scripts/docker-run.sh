#!/usr/bin/env bash
# Run the FbSQL development database in the foreground (Ctrl-C to stop).
#
# Dev-only settings: trust authentication, throwaway container, port 5432
# published to the host. Connect from the host with:
#   psql -h localhost -U postgres
set -euo pipefail
docker run --rm -it \
    --name fbsql-dev \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -p 5432:5432 \
    fbsql-dev
