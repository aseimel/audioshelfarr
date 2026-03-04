# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in Shelfarr, please report it responsibly:

1. **Do not** open a public issue for security vulnerabilities
2. **Email** the maintainers directly or use GitHub's private vulnerability reporting feature
3. **Include** a detailed description of the vulnerability, steps to reproduce, and potential impact

## What to Expect

- We will acknowledge your report within 48 hours
- We will provide an estimated timeline for a fix
- We will notify you when the vulnerability is fixed
- We will credit you in the release notes (unless you prefer to remain anonymous)

## Security Best Practices for Users

When deploying Shelfarr:

- **Keep your instance updated** to the latest version
- **Use strong passwords** for admin accounts
- **Secure your API keys** (Prowlarr, download clients, Audiobookshelf)
- **Run behind a reverse proxy** with HTTPS in production
- **Restrict network access** to trusted users
- **Regularly backup** your database (`storage/production.sqlite3`)

## Scope

This security policy covers the Shelfarr application itself. Third-party integrations (Prowlarr, qBittorrent, SABnzbd, Audiobookshelf) have their own security policies.
