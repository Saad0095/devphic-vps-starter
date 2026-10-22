# Hostinger VPS Deployment & Review Guide

This guide covers deploying **Devphic VPS Starter** on Hostinger KVM VPS, configuring DNS via Hostinger hPanel, and understanding the review criteria for open-source application submissions.

---

## 1. Setting Up Your Hostinger VPS

### Step 1: Create a VPS Instance
1. Log in to [Hostinger hPanel](https://hpanel.hostinger.com/).
2. Navigate to **VPS** -> **Manage** (or purchase a KVM 1 / KVM 2 plan).
3. Under **OS & Panel** -> **Operating System**:
   - Choose **Plain OS**.
   - Select **Ubuntu 24.04 64bit (Noble Numbat)**.
   - Click **Save & Restart**.

### Step 2: Configure SSH Key Authentication
1. In hPanel, navigate to **SSH Keys**.
2. Click **Add SSH Key** and paste your public key (`~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`).
3. Connect to your VPS via terminal:
   ```bash
   ssh root@YOUR_HOSTINGER_VPS_IP
   ```

---

## 2. DNS Zone Configuration in Hostinger

For automated Let's Encrypt SSL issuance to succeed, your domain or subdomain must point directly to your Hostinger VPS IP before running the setup script.

1. In hPanel, go to **Domains** -> select your domain -> **DNS / Nameservers**.
2. Add or edit the **A Record**:
   - **Type:** `A`
   - **Name:** `@` (or `api` if using a subdomain like `api.yourdomain.com`)
   - **Points to:** `YOUR_HOSTINGER_VPS_IP`
   - **TTL:** `300` (5 minutes for faster propagation)
3. Allow 2–10 minutes for DNS propagation. You can verify propagation using:
   ```bash
   dig +short yourdomain.com
   ```

---

## 3. Fast-Track Deployment on Hostinger VPS

Run the following commands on your newly provisioned Hostinger Ubuntu 24.04 VPS:

```bash
# 1. Update system packages
apt update && apt upgrade -y

# 2. Clone the repository
git clone https://github.com/Saad0095/devphic-vps-starter.git /opt/devphic-vps-starter
cd /opt/devphic-vps-starter

# 3. Launch the automated setup wizard
chmod +x scripts/*.sh
./scripts/setup.sh
```

The script will automatically:
- Detect Ubuntu 24.04 and verify resources.
- Install Docker Engine and Docker Compose v2 if not already present.
- Guide you through domain and email configuration.
- Validate DNS propagation.
- Configure UFW firewall (permitting SSH, HTTP, and HTTPS).
- Generate Let's Encrypt SSL certificates.
- Build and launch the container stack.
- Set up an automated daily certificate renewal reload cron.

---

## 4. Hostinger Open Source App Submission & Review Checklist

When submitting an open-source application for Hostinger's Docker catalog, VPS templates, or developer partnership programs, repositories are evaluated on six core technical pillars:

| Requirement Category | Review Criteria | Devphic VPS Starter Compliance |
| :--- | :--- | :--- |
| **1. Licensing & Governance** | Permissive OSI-approved open-source license (MIT, Apache 2.0, BSD) | :white_check_mark: Full MIT License provided |
| **2. Container Standards** | Standard `docker-compose.yml` with multi-stage `Dockerfile`, explicit service names, and bridge networking | :white_check_mark: Node 20 LTS Alpine multi-stage build, unprivileged user |
| **3. Security & Isolation** | No hardcoded secrets, `.env.example` template provided, non-root container execution, internal service ports unexposed | :white_check_mark: App runs as `node` (UID 1000), internal port 3000 not bound to host, UFW firewall integration |
| **4. High Availability** | Container `healthcheck` directives, `restart: unless-stopped`, and graceful signal shutdown handling | :white_check_mark: `/health` probe endpoint, Docker healthchecks, SIGTERM/SIGINT listeners |
| **5. Reverse Proxy & SSL** | Production-ready reverse proxy (Nginx) handling TLS termination and automated Certbot renewal | :white_check_mark: Dual-mode Nginx template, ACME HTTP-01 challenge, automated background renewal |
| **6. Documentation & Maintenance** | Clear setup instructions, troubleshooting steps, backup/update procedures, and active CI pipeline | :white_check_mark: Complete README, test suite (12 tests), GitHub Actions CI, and troubleshooting script |

---

## 5. Deployment Button Integration

Hostinger provides official deployment badges and referral links through its affiliate and partner portal.

To insert your official Hostinger deployment button once approved:
1. Obtain your tracked URL from your Hostinger partner dashboard.
2. Replace the placeholder in [README.md](file:///README.md):
   ```markdown
   [![Deploy to Hostinger](https://img.shields.io/badge/Deploy%20to-Hostinger%20VPS-673DE6?style=for-the-badge&logo=hostinger&logoColor=white)](YOUR_OFFICIAL_HOSTINGER_REFERRAL_URL)
   ```
