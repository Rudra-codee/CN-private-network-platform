# TLS & Certificate Management Guidelines

This directory provides operational instructions and guidelines for managing TLS certificates and CA root distribution for the private network platform.

## Overview

Secure communications in Phase 1 rely on edge TLS termination at Mac 2 (`10.7.9.11`) using local certificates generated via `mkcert`.

## Certificate Specifications

| Property | Value |
|---|---|
| Domain Hostname | `app.teamX.test` |
| Subject Alternative Name (SAN) | `DNS:app.teamX.test` |
| Deployment Path | `/opt/homebrew/etc/nginx/certs/` |
| Public Certificate | `app.teamX.test.pem` |
| Private Key | `app.teamX.test-key.pem` |
| Active Port | 8443/TCP (`listen 8443 ssl;`) |

## Public CA Root Export for Clients

To enable client machines (such as Mac 1 or Mac 4) to trust HTTPS connections to `https://app.teamX.test:8443` without using insecure options like `curl -k`:

1. Identify the CA root certificate location on Mac 2:
   ```bash
   mkcert -CAROOT
   ```
2. Locate `rootCA.pem`.
3. Distribute ONLY `rootCA.pem` to client machines for installation in their local or system trust store.

## Security Rules & Key Protection

> [!CAUTION]
> **NEVER** copy, share, or commit private key files (`rootCA-key.pem` or `app.teamX.test-key.pem`).
> Private key files MUST remain strictly local to Mac 2. `.gitignore` enforces patterns to prevent accidental staging.
