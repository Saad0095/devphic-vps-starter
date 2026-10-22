#!/usr/bin/env bash
# ==============================================================================
# Devphic VPS Starter — Automated Setup Wizard for Ubuntu 24.04 VPS
# ==============================================================================
# This script configures environment variables, verifies DNS, configures
# UFW firewall, generates Let's Encrypt SSL certificates, and launches the
# production Docker stack.
# ==============================================================================

set -euo pipefail

# Color codes for terminal UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper Logging Functions
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
heading() {
  echo -e "\n${BOLD}${BLUE}====================================================================${NC}"
  echo -e "${BOLD}${BLUE}  $1${NC}"
  echo -e "${BOLD}${BLUE}====================================================================${NC}\n"
}

# Resolve script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

heading "Devphic VPS Starter — Setup & Deployment Wizard"
echo "Target Platform: Ubuntu 24.04 LTS (Noble Numbat) / Debian Linux"
echo "Project Directory: ${PROJECT_ROOT}"
echo ""

# ------------------------------------------------------------------------------
# 1. System & Privilege Validation
# ------------------------------------------------------------------------------
heading "1/6: Validating Server Prerequisites"

# Privilege Check
if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    warn "Running as non-root user. Commands requiring elevated privileges will use sudo."
    SUDO="sudo"
  else
    error "This script requires superuser privileges or sudo. Please run as root or install sudo."
    exit 1
  fi
else
  SUDO=""
fi

# Operating System Detection
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  info "Detected Operating System: ${NAME:-Linux} ${VERSION_ID:-Unknown}"
  if [[ "${ID:-}" == "ubuntu" ]]; then
    if [[ "${VERSION_ID:-}" != "24.04" ]]; then
      warn "This kit is optimized for Ubuntu 24.04 LTS. Detected Ubuntu ${VERSION_ID}."
    else
      success "Ubuntu 24.04 LTS confirmed."
    fi
  else
    warn "Non-Ubuntu distribution detected (${ID:-Unknown}). The setup will attempt standard Debian/Ubuntu commands."
  fi
else
  warn "/etc/os-release not found. Proceeding with standard Linux commands."
fi

# Resource Verification
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}' || echo "0")
FREE_DISK_GB=$(df -BG "${PROJECT_ROOT}" | awk 'NR==2 {gsub("G","",$4); print $4}' || echo "0")
ARCH=$(uname -m)

info "System Architecture: ${ARCH}"
info "Total Memory: ${TOTAL_RAM_MB} MB"
info "Available Disk Space: ${FREE_DISK_GB} GB"

if [[ ${TOTAL_RAM_MB} -lt 900 ]]; then
  warn "Total RAM is below 1 GB (${TOTAL_RAM_MB} MB). Node.js and Docker builds may require a swapfile on low-tier VPS."
fi

# ------------------------------------------------------------------------------
# 2. Docker & Docker Compose Verification / Installation
# ------------------------------------------------------------------------------
heading "2/6: Verifying Docker & Container Tools"

install_docker() {
  info "Installing Docker Engine and Compose plugin via official Docker repository..."
  ${SUDO} apt-get update -y
  ${SUDO} apt-get install -y ca-certificates curl gnupg lsb-release

  ${SUDO} install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | ${SUDO} gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
  ${SUDO} chmod a+r /etc/apt/keyrings/docker.gpg

  UBUNTU_CODENAME="${VERSION_CODENAME:-noble}"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" | \
    ${SUDO} tee /etc/apt/sources.list.d/docker.list > /dev/null

  ${SUDO} apt-get update -y
  ${SUDO} apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  ${SUDO} systemctl enable docker
  ${SUDO} systemctl start docker

  # Add current user to docker group if not root
  if [[ -n "${SUDO}" && -n "${SUDO_USER:-}" ]]; then
    ${SUDO} usermod -aG docker "${SUDO_USER}"
    info "Added user '${SUDO_USER}' to docker group."
  fi

  success "Docker installed successfully."
}

if ! command -v docker >/dev/null 2>&1; then
  warn "Docker is not currently installed."
  read -rp "Would you like to automatically install Docker Engine now? [Y/n]: " INSTALL_DOCKER_CHOICE
  INSTALL_DOCKER_CHOICE=${INSTALL_DOCKER_CHOICE:-Y}
  if [[ "${INSTALL_DOCKER_CHOICE}" =~ ^[Yy]$ ]]; then
    install_docker
  else
    error "Docker is required to run Devphic VPS Starter. Aborting."
    exit 1
  fi
else
  DOCKER_VERSION=$(docker --version)
  success "Docker detected: ${DOCKER_VERSION}"
fi

# Verify Docker Compose v2 (docker compose)
if ! docker compose version >/dev/null 2>&1; then
  warn "Docker Compose plugin not found. Attempting to install docker-compose-plugin..."
  ${SUDO} apt-get update -y && ${SUDO} apt-get install -y docker-compose-plugin
fi
COMPOSE_VERSION=$(docker compose version)
success "Docker Compose detected: ${COMPOSE_VERSION}"

# ------------------------------------------------------------------------------
# 3. Interactive Configuration Wizard (.env)
# ------------------------------------------------------------------------------
heading "3/6: Interactive Configuration (.env Setup)"

# Safeguard existing .env
if [[ -f .env ]]; then
  warn "An existing .env file was found."
  read -rp "Do you want to reconfigure .env? A backup will be created. [y/N]: " RECONFIGURE_ENV
  RECONFIGURE_ENV=${RECONFIGURE_ENV:-N}
  if [[ "${RECONFIGURE_ENV}" =~ ^[Yy]$ ]]; then
    BACKUP_NAME="backups/.env.backup.$(date +%Y%m%d_%H%M%S)"
    mkdir -p backups
    cp .env "${BACKUP_NAME}"
    info "Backed up existing .env to ${BACKUP_NAME}"
  else
    info "Preserving existing .env configuration."
    source .env
  fi
fi

if [[ ! -f .env ]] || [[ "${RECONFIGURE_ENV:-N}" =~ ^[Yy]$ ]]; then
  echo "Please answer the following prompts to configure your production deployment:"
  echo ""

  # Prompt Domain
  while true; do
    read -rp "Enter your primary Domain Name (e.g. api.example.com): " INPUT_DOMAIN
    INPUT_DOMAIN=$(echo "${INPUT_DOMAIN}" | tr '[:upper:]' '[:lower:]' | xargs)
    if [[ "${INPUT_DOMAIN}" =~ ^([a-zA-Z0-9][-a-zA-Z0-9]*[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$ ]]; then
      break
    else
      error "Invalid domain format. Please enter a valid fully-qualified domain name (e.g., api.yourdomain.com)."
    fi
  done

  # Prompt Email for Certbot
  while true; do
    read -rp "Enter your Admin Email for Let's Encrypt SSL notices: " INPUT_EMAIL
    INPUT_EMAIL=$(echo "${INPUT_EMAIL}" | tr '[:upper:]' '[:lower:]' | xargs)
    if [[ "${INPUT_EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
      break
    else
      error "Invalid email address format. Please enter a valid email."
    fi
  done

  # Prompt App Name
  read -rp "Enter Application Name [Devphic VPS Starter API]: " INPUT_APP_NAME
  INPUT_APP_NAME=${INPUT_APP_NAME:-"Devphic VPS Starter API"}

  # Prompt CORS Origin
  read -rp "Enter Allowed CORS Origin (use * for public APIs or https://${INPUT_DOMAIN}) [*]: " INPUT_CORS
  INPUT_CORS=${INPUT_CORS:-"*"}

  # Generate Secure Random Secret Key
  GENERATED_SECRET=$(openssl rand -hex 32 2>/dev/null || tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 64 || echo "devphic_default_random_key_replace_me")

  # Write .env file
  cat <<EOF > .env
# ==============================================================================
# Devphic VPS Starter — Generated Production Configuration
# Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# ==============================================================================
NODE_ENV=production
PORT=3000
HOST=0.0.0.0
APP_NAME="${INPUT_APP_NAME}"
APP_VERSION=1.0.0
CORS_ORIGIN="${INPUT_CORS}"
TRUST_PROXY=true
SHUTDOWN_TIMEOUT_MS=10000
APP_SECRET=${GENERATED_SECRET}
DOMAIN=${INPUT_DOMAIN}
LETSENCRYPT_EMAIL=${INPUT_EMAIL}
EOF

  # Secure permissions on .env
  chmod 600 .env
  success "Generated production .env file with secure 600 permissions."
fi

# Load variables
source .env
DOMAIN="${DOMAIN:-example.com}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@example.com}"

# ------------------------------------------------------------------------------
# 4. DNS Pre-Flight Validation
# ------------------------------------------------------------------------------
heading "4/6: DNS Pre-Flight Verification"

info "Resolving public IP address of this VPS..."
SERVER_PUBLIC_IP=$(curl -s -4 --max-time 5 https://ifconfig.me || curl -s -4 --max-time 5 https://icanhazip.com || echo "UNKNOWN")
info "Detected VPS Public IPv4: ${SERVER_PUBLIC_IP}"

info "Resolving DNS 'A' record for ${DOMAIN}..."
RESOLVED_DOMAIN_IP=$(getent hosts "${DOMAIN}" | awk '{ print $1 }' | head -n 1 || echo "")

if [[ -z "${RESOLVED_DOMAIN_IP}" ]]; then
  warn "Could not resolve an IP address for domain '${DOMAIN}'."
  echo -e "Make sure you have created an ${BOLD}A Record${NC} pointing to: ${BOLD}${SERVER_PUBLIC_IP}${NC}"
  read -rp "Do you want to proceed anyway? (Certbot SSL issuance may fail if DNS is not propagated) [y/N]: " DNS_PROCEED
  DNS_PROCEED=${DNS_PROCEED:-N}
  if [[ ! "${DNS_PROCEED}" =~ ^[Yy]$ ]]; then
    info "Deployment paused. Configure your DNS A record and rerun ./scripts/setup.sh."
    exit 0
  fi
elif [[ "${SERVER_PUBLIC_IP}" != "UNKNOWN" && "${RESOLVED_DOMAIN_IP}" != "${SERVER_PUBLIC_IP}" ]]; then
  warn "DNS Mismatch! Domain '${DOMAIN}' resolves to [${RESOLVED_DOMAIN_IP}], but this VPS is [${SERVER_PUBLIC_IP}]."
  warn "Let's Encrypt requires the domain to point directly to this VPS."
  read -rp "Continue anyway? [y/N]: " DNS_PROCEED
  DNS_PROCEED=${DNS_PROCEED:-N}
  if [[ ! "${DNS_PROCEED}" =~ ^[Yy]$ ]]; then
    exit 0
  fi
else
  success "DNS verified: ${DOMAIN} -> ${RESOLVED_DOMAIN_IP}"
fi

# ------------------------------------------------------------------------------
# 5. UFW Firewall Configuration
# ------------------------------------------------------------------------------
heading "5/6: Configuring Server Firewall (UFW)"

if command -v ufw >/dev/null 2>&1; then
  # Detect current SSH port to avoid lockout
  SSH_PORT=$(ss -tlnp 2>/dev/null | grep -E 'sshd|ssh' | awk '{print $4}' | awk -F':' '{print $NF}' | head -n 1 || echo "22")
  SSH_PORT=${SSH_PORT:-22}

  info "Configuring UFW rules (SSH: ${SSH_PORT}, HTTP: 80, HTTPS: 443)..."
  ${SUDO} ufw allow "${SSH_PORT}/tcp" comment "SSH Access" >/dev/null
  ${SUDO} ufw allow 80/tcp comment "Nginx HTTP & ACME" >/dev/null
  ${SUDO} ufw allow 443/tcp comment "Nginx HTTPS" >/dev/null

  UFW_STATUS=$(${SUDO} ufw status | grep -i "Status:" | awk '{print $2}' || echo "inactive")
  if [[ "${UFW_STATUS}" != "active" ]]; then
    read -rp "UFW is currently inactive. Would you like to enable it now? [Y/n]: " ENABLE_UFW
    ENABLE_UFW=${ENABLE_UFW:-Y}
    if [[ "${ENABLE_UFW}" =~ ^[Yy]$ ]]; then
      echo "y" | ${SUDO} ufw enable
      success "UFW firewall enabled and protecting server ports."
    else
      warn "UFW remains disabled. Ensure your cloud provider firewall allows ports 80 and 443."
    fi
  else
    ${SUDO} ufw reload >/dev/null
    success "UFW rules updated and active."
  fi
else
  warn "ufw command not found. Please ensure ports 80, 443, and 22 are permitted by your hosting provider."
fi

# ------------------------------------------------------------------------------
# 6. SSL Certificate Issuance & Container Launch
# ------------------------------------------------------------------------------
heading "6/6: SSL Provisioning & Application Launch"

# Ensure named volumes exist
docker volume create devphic_certbot_www >/dev/null
docker volume create devphic_certbot_conf >/dev/null

# Check if certificates already exist for the domain
CERT_EXISTS=false
if docker run --rm -v devphic_certbot_conf:/etc/letsencrypt alpine test -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" 2>/dev/null; then
  CERT_EXISTS=true
  info "Existing Let's Encrypt certificates found for ${DOMAIN}."
fi

if [[ "${CERT_EXISTS}" == "false" ]]; then
  info "Bootstrapping initial dummy SSL certificate so Nginx can start..."

  # Generate temporary self-signed certificate inside the certbot_conf volume
  docker run --rm -v devphic_certbot_conf:/etc/letsencrypt alpine sh -c "
    mkdir -p '/etc/letsencrypt/live/${DOMAIN}' && \
    apk add --no-cache openssl >/dev/null 2>&1 && \
    openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
      -keyout '/etc/letsencrypt/live/${DOMAIN}/privkey.pem' \
      -out '/etc/letsencrypt/live/${DOMAIN}/fullchain.pem' \
      -subj '/CN=localhost' >/dev/null 2>&1
  "
  success "Bootstrap certificate generated."

  # Start Nginx and App to handle ACME challenge
  info "Starting Nginx and Node.js application stack..."
  docker compose up -d --build app nginx

  info "Requesting official Let's Encrypt SSL certificate for ${DOMAIN}..."
  # Run Certbot to acquire real certificate
  docker compose run --rm certbot certonly \
    --webroot \
    -w /var/www/certbot \
    --email "${LETSENCRYPT_EMAIL}" \
    -d "${DOMAIN}" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    --non-interactive || {
      warn "Certbot was unable to complete the ACME HTTP-01 challenge."
      warn "This usually occurs if DNS has not finished propagating to this VPS (${SERVER_PUBLIC_IP})."
      warn "The application is currently running with the bootstrap self-signed certificate."
      warn "Once DNS is ready, run: docker compose run --rm certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN} --email ${LETSENCRYPT_EMAIL} --agree-tos"
  }

  # Reload Nginx with new certificate
  info "Reloading Nginx with production TLS certificate..."
  docker compose exec -T nginx nginx -s reload || true
else
  # Certificates already exist, start full stack
  info "Starting full production container stack..."
  docker compose up -d --build
fi

# Ensure background Certbot renewal loop is running
docker compose up -d certbot

# Setup automated system cron for Nginx certificate reloading
CRON_FILE="/etc/cron.d/devphic-cert-reload"
if [[ -d /etc/cron.d ]]; then
  info "Configuring automated certificate renewal reload task..."
  cat <<CRONEOF | ${SUDO} tee "${CRON_FILE}" > /dev/null
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 3 * * * root cd ${PROJECT_ROOT} && docker compose exec -T nginx nginx -s reload > /dev/null 2>&1
CRONEOF
  ${SUDO} chmod 644 "${CRON_FILE}"
  success "Automated renewal reload configured in ${CRON_FILE} (runs daily at 03:00)."
fi

# ------------------------------------------------------------------------------
# Final Verification & Summary
# ------------------------------------------------------------------------------
heading "Deployment Completed Successfully! 🎉"

info "Waiting for application health probe to settle..."
sleep 3

# Test internal health endpoint
HEALTH_CHECK_RESULT=$(docker compose exec -T app wget -qO- http://127.0.0.1:3000/health 2>/dev/null || echo "failed")

if [[ "${HEALTH_CHECK_RESULT}" != "failed" ]]; then
  success "Internal container healthcheck PASSED."
else
  warn "Health check did not respond immediately. Check 'docker compose logs app'."
fi

echo -e "\n${BOLD}${GREEN}====================================================================${NC}"
echo -e "${BOLD}${GREEN}  Devphic VPS Starter is Live!${NC}"
echo -e "${BOLD}${GREEN}====================================================================${NC}"
echo -e "• Web URL:           ${CYAN}https://${DOMAIN}${NC}"
echo -e "• Health Endpoint:   ${CYAN}https://${DOMAIN}/health${NC}"
echo -e "• API Endpoint:      ${CYAN}https://${DOMAIN}/api${NC}"
echo -e ""
echo -e "${BOLD}Management Commands:${NC}"
echo -e "• View logs:         ${YELLOW}docker compose logs -f${NC}"
echo -e "• Check status:      ${YELLOW}docker compose ps${NC}"
echo -e "• Restart stack:     ${YELLOW}docker compose restart${NC}"
echo -e "• Run Diagnostics:   ${YELLOW}./scripts/troubleshoot.sh${NC}"
echo -e "• Safe Update:       ${YELLOW}./scripts/update.sh${NC}"
echo -e "• Create Backup:     ${YELLOW}./scripts/backup.sh${NC}"
echo -e "====================================================================\n"
