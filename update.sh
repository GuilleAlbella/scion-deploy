#!/usr/bin/env bash
# SCION Linux manual updater. Watchtower normally handles this every
# 6h — this script is for the impatient or for environments where
# Watchtower is disabled.
#
#   curl -fsSL https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/update.sh | bash

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main"
INSTALL_DIR="/opt/scion"

if [ ! -d "$INSTALL_DIR" ]; then
  echo "✗ $INSTALL_DIR not found. Run install.sh first." >&2
  exit 1
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

echo "▶ Refreshing compose + nginx config from $REPO_RAW"
curl -fsSL "$REPO_RAW/docker-compose.yml" -o "$INSTALL_DIR/docker-compose.yml"
curl -fsSL "$REPO_RAW/nginx.conf"         -o "$INSTALL_DIR/nginx.conf"

echo "▶ Verifying GHCR access"
ghcr_user="guillealbella"
if ! docker manifest inspect "ghcr.io/$ghcr_user/scion-backend:latest" >/dev/null 2>&1; then
  echo "✗ GHCR auth expired or missing. Re-run install.sh to refresh, or:" >&2
  echo "  docker login ghcr.io -u $ghcr_user" >&2
  exit 1
fi

echo "▶ Pulling latest images"
(cd "$INSTALL_DIR" && $SUDO docker compose pull)

echo "▶ Recreating containers"
(cd "$INSTALL_DIR" && $SUDO docker compose up -d)

echo "✓ SCION updated. Current containers:"
(cd "$INSTALL_DIR" && $SUDO docker compose ps)
