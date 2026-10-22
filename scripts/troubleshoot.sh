#!/usr/bin/env bash
# ==============================================================================
# Devphic VPS Starter — Diagnostic & Troubleshooting Utility
# ==============================================================================
# Inspects container health, open ports, UFW rules, DNS resolution, and SSL status.
# ==============================================================================

set -uo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo -e "\n${BOLD}${CYAN}====================================================================${NC}"
echo -e "${BOLD}${CYAN}  Devphic VPS Starter — System Diagnostic Report${NC}"
echo -e "${BOLD}${CYAN}====================================================================${NC}\n"

# 1. System & Resource Overview
echo -e "${BOLD}1. Host System Overview:${NC}"
echo "• Date: $(date -u)"
echo "• Kernel: $(uname -r)"
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  echo "• OS: ${PRETTY_NAME:-Linux}"
fi
echo "• Memory: $(free -h | awk '/^Mem:/{print "Used: "$3" / Total: "$2}')"
echo "• Disk: $(df -h "${PROJECT_ROOT}" | awk 'NR==2{print "Used: "$3" / Available: "$4" ("$5")"}')"
echo ""

# 2. Docker & Compose Status
echo -e "${BOLD}2. Docker Engine & Compose Status:${NC}"
if command -v docker >/dev/null 2>&1; then
  docker --version
  docker compose version
  if docker info >/dev/null 2>&1; then
    echo -e "• Docker Daemon: ${GREEN}Active & Running${NC}"
  else
    echo -e "• Docker Daemon: ${RED}Inactive or Permission Denied${NC}"
  fi
else
  echo -e "• Docker: ${RED}Not Installed${NC}"
fi
echo ""

# 3. Running Containers Status
echo -e "${BOLD}3. Container Stack Status (docker compose ps):${NC}"
if docker compose ps >/dev/null 2>&1; then
  docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
else
  echo -e "${YELLOW}No active compose stack found in current directory.${NC}"
fi
echo ""

# 4. Container Health Status
echo -e "${BOLD}4. Node.js App Health Probe Inspection:${NC}"
if docker inspect devphic_app >/dev/null 2>&1; then
  HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' devphic_app 2>/dev/null || echo "No Healthcheck")
  if [[ "${HEALTH_STATUS}" == "healthy" ]]; then
    echo -e "• Health Status: ${GREEN}${HEALTH_STATUS}${NC}"
  else
    echo -e "• Health Status: ${YELLOW}${HEALTH_STATUS}${NC}"
  fi
  echo "• Internal Probe Test:"
  docker compose exec -T app wget -qO- http://127.0.0.1:3000/health 2>/dev/null || echo -e "${RED}Internal request to http://127.0.0.1:3000/health failed.${NC}"
else
  echo -e "${YELLOW}Container 'devphic_app' is not currently created or running.${NC}"
fi
echo ""

# 5. Network & Open Ports
echo -e "${BOLD}5. Host Open Listening Ports (HTTP/HTTPS/SSH):${NC}"
if command -v ss >/dev/null 2>&1; then
  ss -tulpn | grep -E '(:80|:443|:22|:3000)' || echo "No matching listening ports found."
elif command -v netstat >/dev/null 2>&1; then
  netstat -tulpn | grep -E '(:80|:443|:22|:3000)' || echo "No matching listening ports found."
fi
echo ""

# 6. UFW Firewall Status
echo -e "${BOLD}6. UFW Firewall Configuration:${NC}"
if command -v ufw >/dev/null 2>&1; then
  ufw status verbose 2>/dev/null || sudo ufw status verbose
else
  echo "ufw not installed."
fi
echo ""

# 7. DNS & Domain Resolution
echo -e "${BOLD}7. Domain & DNS Verification:${NC}"
if [[ -f .env ]]; then
  DOMAIN=$(grep -E '^DOMAIN=' .env | cut -d '=' -f2 | tr -d '"' | tr -d "'" || echo "")
fi
DOMAIN=${DOMAIN:-""}

if [[ -n "${DOMAIN}" ]]; then
  echo "• Configured Domain: ${DOMAIN}"
  RESOLVED_IP=$(getent hosts "${DOMAIN}" | awk '{print $1}' | head -n 1 || echo "UNRESOLVED")
  PUBLIC_IP=$(curl -s -4 --max-time 3 https://ifconfig.me 2>/dev/null || echo "UNKNOWN")
  echo "• Resolved DNS IP:  ${RESOLVED_IP}"
  echo "• VPS Public IP:    ${PUBLIC_IP}"

  if [[ "${RESOLVED_IP}" == "${PUBLIC_IP}" && "${PUBLIC_IP}" != "UNKNOWN" ]]; then
    echo -e "• Match Status:     ${GREEN}DNS correctly points to this VPS${NC}"
  else
    echo -e "• Match Status:     ${YELLOW}DNS mismatch! Ensure your domain DNS A Record points to ${PUBLIC_IP}${NC}"
  fi
else
  echo "• No DOMAIN configured in .env."
fi
echo ""

# 8. SSL Certificate Expiry Check
echo -e "${BOLD}8. Let's Encrypt SSL Certificate Inspection:${NC}"
if docker volume inspect devphic_certbot_conf >/dev/null 2>&1 && [[ -n "${DOMAIN}" ]]; then
  CERT_EXPIRY=$(docker run --rm -v devphic_certbot_conf:/etc/letsencrypt alpine sh -c "
    if [ -f '/etc/letsencrypt/live/${DOMAIN}/fullchain.pem' ]; then
      apk add --no-cache openssl >/dev/null 2>&1
      openssl x509 -enddate -noout -in '/etc/letsencrypt/live/${DOMAIN}/fullchain.pem'
    else
      echo 'NOT_FOUND'
    fi
  " 2>/dev/null || echo "CHECK_FAILED")

  if [[ "${CERT_EXPIRY}" =~ "notAfter=" ]]; then
    echo -e "• Expiration: ${GREEN}${CERT_EXPIRY}${NC}"
  elif [[ "${CERT_EXPIRY}" == "NOT_FOUND" ]]; then
    echo -e "• Expiration: ${YELLOW}No active certificate file found for ${DOMAIN}.${NC}"
  else
    echo -e "• Expiration: ${YELLOW}${CERT_EXPIRY}${NC}"
  fi
fi
echo ""

# 9. Recent Container Error Logs
echo -e "${BOLD}9. Recent Container Logs (Nginx & App):${NC}"
echo -e "${CYAN}--- Nginx Tail (Last 10 lines) ---${NC}"
docker compose logs --tail=10 nginx 2>&1 || true
echo -e "\n${CYAN}--- App Tail (Last 10 lines) ---${NC}"
docker compose logs --tail=10 app 2>&1 || true

echo -e "\n${BOLD}${GREEN}====================================================================${NC}"
echo -e "${BOLD}${GREEN}  Diagnostic Report Complete!${NC}"
echo -e "${BOLD}${GREEN}====================================================================${NC}\n"
