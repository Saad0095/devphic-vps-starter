# Contributing to Devphic VPS Starter

Thank you for your interest in contributing to **Devphic VPS Starter**! We welcome bug reports, documentation enhancements, security improvements, and feature contributions from the open-source community.

---

## Code of Conduct

Please treat all members with respect, courtesy, and constructive collaboration. Maintain inclusive, professional language across all issues, pull requests, and discussions.

---

## How to Contribute

### 1. Reporting Bugs
- Check existing GitHub Issues to see if the bug has already been reported.
- If not, open a new issue detailing:
  - Your server environment (e.g., Ubuntu 24.04 LTS, VPS provider, CPU arch).
  - Exact steps to reproduce.
  - Relevant logs (`./scripts/troubleshoot.sh` output or `docker compose logs`).
  - Expected vs. actual behavior.

### 2. Suggesting Improvements
- Open a GitHub Discussion or Issue describing the proposed feature and why it benefits developers deploying Node.js apps.
- Keep in mind the project goal: **minimal, secure, reliable, and free from unnecessary enterprise bloat**.

### 3. Submitting Pull Requests
1. Fork the repository and create your branch from `main`:
   ```bash
   git checkout -b feature/my-cool-feature
   ```
2. Make your modifications cleanly.
3. Ensure automated tests pass locally:
   ```bash
   npm test
   ```
4. If modifying shell scripts (`scripts/*.sh`):
   - Enforce POSIX/Bash best practices (`set -euo pipefail`).
   - Ensure LF line endings are preserved.
   - Run a syntax check:
     ```bash
     bash -n scripts/*.sh
     ```
5. Commit your changes with clear, semantic commit messages (e.g., `feat: add IPv6 support to nginx template`).
6. Push to your fork and submit a Pull Request against the `main` branch.

---

## Local Development Workflow

1. Clone your fork:
   ```bash
   git clone https://github.com/devphic/devphic-vps-starter.git
   cd devphic-vps-starter
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Run the application in development mode with auto-reload:
   ```bash
   npm run dev
   ```
4. Run tests:
   ```bash
   npm test
   ```

---

## Licensing
By contributing to Devphic VPS Starter, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
