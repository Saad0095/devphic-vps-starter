#!/usr/bin/env bash
# ==============================================================================
# Devphic VPS Starter — Safe Application Update Script
# ==============================================================================
# Performs zero/near-zero downtime updates, pulls the latest code, rebuilds the
# application container, tests the health check, and reloads Nginx.
# ==============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo -e "\n${BOLD}${CYAN}=== Devphic VPS Starter — Safe Update Wizard ===${NC}\n"

# 1. Check Git Repository Status
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo -e "${CYAN}[INFO]${NC} Fetching updates from remote repository..."
  git fetch origin || true

  LOCAL_HASH=$(git rev-parse HEAD)
  REMOTE_HASH=$(git rev-parse "@{u}" 2>/dev/null || echo "${LOCAL_HASH}")

  if [[ "${LOCAL_HASH}" == "${REMOTE_HASH}" ]]; then
    echo -e "${YELLOW}[NOTICE]${NC} Your local repository is already up to date (${LOCAL_HASH:0:7})."
    read -rp "Do you still want to rebuild and restart the containers? [y/N]: " FORCE_REBUILD
    FORCE_REBUILD=${FORCE_REBUILD:-N}
    if [[ ! "${FORCE_REBUILD}" =~ ^[Yy]$ ]]; then
      echo -e "${GREEN}[OK]${NC} Update cancelled."
      exit 0
    fi
  else
    echo -e "${GREEN}[INFO]${NC} Updates available from remote! Pulling latest changes..."
    git pull origin "$(git rev-parse --abbrev-ref HEAD)"
  fi
else
  echo -e "${YELLOW}[WARNING]${NC} Not a Git repository or Git not found. Proceeding with container rebuild."
fi

# 2. Automatically backup .env before proceeding
if [[ -f .env ]]; then
  mkdir -p backups
  cp .env "backups/.env.pre_update_$(date +%Y%m%d_%H%M%S)"
fi

# 3. Build the new application image
echo -e "${CYAN}[INFO]${NC} Building updated Node.js application image..."
docker compose build --pull app

# 4. Gracefully restart the app container without downtime for Nginx
echo -e "${CYAN}[INFO]${NC} Recreating app container..."
docker compose up -d --no-deps app

# 5. Verify Health Check
echo -e "${CYAN}[INFO]${NC} Verifying application health probe..."
HEALTHY=false
for i in {1..15}; do
  if docker compose exec -T app wget -qO- http://127.0.0.1:3000/health >/dev/null 2>&1; then
    HEALTHY=true
    break
  fi
  echo -n "."
  sleep 2
done
echo ""

if [[ "${HEALTHY}" == "true" ]]; then
  # Reload Nginx to reset any keepalive sockets to old containers
  docker compose exec -T nginx nginx -s reload >/dev/null 2>&1 || true
  echo -e "${GREEN}[SUCCESS]${NC} Application updated and healthy! 🎉"
  docker compose ps app
else
  echo -e "${RED}[ERROR]${NC} Healthcheck failed after update! Checking logs:"
  docker compose logs --tail=30 app
  echo -e "${YELLOW}[TIP]${NC} If needed, you can roll back with 'git checkout HEAD@{1}' and rerun './scripts/update.sh'."
  exit 1
fi
