#!/usr/bin/env bash
# ==============================================================================
# Devphic VPS Starter — Safe Cleanup / Uninstall Script
# ==============================================================================
# Safely tears down containers, cleans cron jobs, and optionally removes
# persistent volumes with explicit user confirmation.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo -e "\n${BOLD}${RED}====================================================================${NC}"
echo -e "${BOLD}${RED}  WARNING: Devphic VPS Starter Teardown / Uninstall Utility${NC}"
echo -e "${BOLD}${RED}====================================================================${NC}\n"
echo "This script will stop all running application and reverse proxy containers."
echo ""

read -rp "Are you sure you want to proceed? Type 'destroy' to confirm: " CONFIRMATION
if [[ "${CONFIRMATION}" != "destroy" ]]; then
  echo -e "${GREEN}Aborted. No changes were made.${NC}"
  exit 0
fi

# 1. Stop and remove containers
echo -e "\n${YELLOW}[INFO]${NC} Stopping and removing Docker containers..."
docker compose down || true

# 2. Remove automated cron reload task
CRON_FILE="/etc/cron.d/devphic-cert-reload"
if [[ -f "${CRON_FILE}" ]]; then
  echo -e "${YELLOW}[INFO]${NC} Removing cron reload task ${CRON_FILE}..."
  if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    sudo rm -f "${CRON_FILE}"
  else
    rm -f "${CRON_FILE}" || true
  fi
fi

# 3. Prompt for Docker Volumes removal (Certificates & Challenge data)
echo ""
read -rp "Do you want to permanently delete Let's Encrypt SSL certificate volumes? [y/N]: " REMOVE_VOLUMES
REMOVE_VOLUMES=${REMOVE_VOLUMES:-N}
if [[ "${REMOVE_VOLUMES}" =~ ^[Yy]$ ]]; then
  echo -e "${RED}[INFO]${NC} Deleting Docker volumes devphic_certbot_www and devphic_certbot_conf..."
  docker volume rm devphic_certbot_www devphic_certbot_conf 2>/dev/null || true
  echo -e "${GREEN}[OK]${NC} Volumes removed."
else
  echo -e "${GREEN}[INFO]${NC} Preserved SSL certificate volumes for future deployments."
fi

# 4. Prompt for .env removal
echo ""
read -rp "Do you want to remove the .env file? [y/N]: " REMOVE_ENV
REMOVE_ENV=${REMOVE_ENV:-N}
if [[ "${REMOVE_ENV}" =~ ^[Yy]$ ]]; then
  rm -f .env
  echo -e "${GREEN}[OK]${NC} Removed .env file."
fi

echo -e "\n${BOLD}${GREEN}Teardown complete. Devphic VPS Starter has been cleanly uninstalled.${NC}\n"
