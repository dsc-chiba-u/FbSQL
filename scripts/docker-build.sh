#!/usr/bin/env bash
# Build the FbSQL development image (PostgreSQL 16 + PL/R + R).
set -euo pipefail
cd "$(dirname "$0")/.."
docker build -t fbsql-dev -f docker/Dockerfile .
