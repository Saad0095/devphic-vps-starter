#!/usr/bin/env bash
# ==============================================================================
# Devphic VPS Starter — Automated Backup Script
# ==============================================================================
# Backs up .env configurations, Nginx configs, and Let's Encrypt SSL certificates
# into a compressed tarball with automated retention rotation (keeps last 7 backups).
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

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${PROJECT_ROOT}/backups"
BACKUP_ARCHIVE="${BACKUP_DIR}/devphic_backup_${TIMESTAMP}.tar.gz"
TEMP_DIR=$(mktemp -d)

trap 'rm -rf "${TEMP_DIR}"' EXIT

echo -e "\n${BOLD}${CYAN}=== Devphic VPS Starter — Backup Utility ===${NC}\n"

mkdir -p "${BACKUP_DIR}"
mkdir -p "${TEMP_DIR}/backup_data"

# 1. Backup .env file
if [[ -f .env ]]; then
  cp .env "${TEMP_DIR}/backup_data/.env"
  echo -e "${GREEN}[OK]${NC} Backed up .env"
else
  echo -e "${YELLOW}[SKIP]${NC} .env file not found."
fi

# 2. Backup Nginx configuration
if [[ -d nginx ]]; then
  cp -r nginx "${TEMP_DIR}/backup_data/nginx"
  echo -e "${GREEN}[OK]${NC} Backed up Nginx configurations"
fi

# 3. Backup Let's Encrypt SSL certificates from Docker volume
if docker volume inspect devphic_certbot_conf >/dev/null 2>&1; then
  echo -e "${CYAN}[INFO]${NC} Exporting SSL certificates from Docker volume 'devphic_certbot_conf'..."
  docker run --rm \
    -v devphic_certbot_conf:/volume_source:ro \
    -v "${TEMP_DIR}/backup_data":/backup_dest \
    alpine sh -c "cp -a /volume_source /backup_dest/letsencrypt_certs"
  echo -e "${GREEN}[OK]${NC} Backed up Let's Encrypt SSL certificates"
fi

# 4. Create compressed tarball
echo -e "${CYAN}[INFO]${NC} Creating compressed archive: ${BACKUP_ARCHIVE}..."
tar -czf "${BACKUP_ARCHIVE}" -C "${TEMP_DIR}/backup_data" .
chmod 600 "${BACKUP_ARCHIVE}"

BACKUP_SIZE=$(du -h "${BACKUP_ARCHIVE}" | awk '{print $1}')
echo -e "${GREEN}[SUCCESS]${NC} Backup completed successfully (${BACKUP_SIZE}): ${BACKUP_ARCHIVE}"

# 5. Clean up old backups (Retain last 7 archives)
echo -e "${CYAN}[INFO]${NC} Rotating old backups (retaining newest 7 archives)..."
ls -1t "${BACKUP_DIR}"/devphic_backup_*.tar.gz 2>/dev/null | tail -n +8 | while read -r old_backup; do
  echo -e "${YELLOW}[REMOVED]${NC} Expired backup: ${old_backup}"
  rm -f "${old_backup}"
done

echo -e "${GREEN}[DONE]${NC} Backup routine finished."
