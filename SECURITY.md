# Security Policy

Security and least privilege are central principles of **Devphic VPS Starter**.

---

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

---

## Reporting a Vulnerability

If you discover a security vulnerability in Devphic VPS Starter, please **do not** disclose it publicly via GitHub Issues.

Instead, please send an encrypted or direct email to `security@devphic.com` (or open a private GitHub Security Advisory). Include:
- A description of the vulnerability.
- Step-by-step instructions or Proof of Concept (PoC) to reproduce the issue.
- Potential impact and suggested mitigations if known.

We aim to acknowledge reports within **48 hours** and provide a patch/fix within **7 business days**.

---

## Security Principles Implemented

1. **Non-Root Execution**: The Node.js application runs as unprivileged user `node` (UID 1000) inside an Alpine-based container.
2. **Internal Network Isolation**: The application port (3000) is never published directly to the public network interface. All external traffic must pass through the Nginx reverse proxy.
3. **Automated TLS & Modern Ciphers**: Only TLSv1.2 and TLSv1.3 are enabled. SSL session tickets are disabled, and HSTS headers are enforced.
4. **Rate Limiting**: Nginx restricts burst and per-IP request frequency to prevent Denial-of-Service and brute-force abuse.
5. **No Secret Leakage**: Secrets are decoupled into `.env`, protected with strict file permissions (`chmod 600`), and excluded from Git commits via `.gitignore`.
