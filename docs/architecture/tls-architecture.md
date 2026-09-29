# TLS Termination & HTTPS Architecture

This document describes the server-side TLS architecture implemented on Mac 2 for Task E, providing secure HTTPS traffic termination at the nginx edge proxy.

## Architecture Overview

HTTPS termination is configured at the nginx edge on Mac 2 (`10.7.9.11`). Client requests sent to `https://app.teamX.test:8443` undergo TLS negotiation and decryption directly on Mac 2. The decrypted requests are then proxied unencrypted over the private LAN to the upstream backend pool (`Backend A` on Mac 3 and `Backend B` on Mac 4).

| Component | Property / Value |
|---|---|
| Edge Host | Mac 2 (`10.7.9.11`) |
| Edge Software | nginx 1.31.6 |
| HTTPS Listener | TCP Port 8443 (`listen 8443 ssl;`) |
| HTTP Listener (Task D) | TCP Port 8080 (`listen 8080;`) |
| Target Hostname | `app.teamX.test` |
| Certificate Path | `/opt/homebrew/etc/nginx/certs/app.teamX.test.pem` |
| Key Path | `/opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem` |
| Upstream Pool | `backend_pool` (`10.7.13.5:3001` & `10.7.29.244:3002`) |

## TLS Termination Model

```mermaid
flowchart TD
    Client["Client Machine"]
    DNS["Mac 1 — 10.7.17.222\n(dnsmasq)"]
    Edge["Mac 2 — 10.7.9.11\nnginx 1.31.6\nPort 8443 (HTTPS / TLS)"]
    BackA["Mac 3 — 10.7.13.5:3001\nBackend A (HTTP)"]
    BackB["Mac 4 — 10.7.29.244:3002\nBackend B (HTTP)"]

    Client -->|1. DNS Query| DNS
    DNS -->|2. app.teamX.test → 10.7.9.11| Client
    Client -->|3. HTTPS Request (TLS 1.3 Port 8443)| Edge
    Edge -.->|TLS Handshake & Decryption| Edge
    Edge -->|4a. HTTP Proxy Request| BackA
    Edge -->|4b. HTTP Proxy Request| BackB
```

### ASCII Flow

```
Client Machine
  │
  ├─► 1. HTTPS GET https://app.teamX.test:8443/api/status (TLS 1.3 Encrypted)
  │
  ▼
Mac 2 Edge Proxy (10.7.9.11:8443)
  │
  ├─► 2. TLS Termination & Decryption (nginx)
  │
  ├─► 3a. Proxy Request (HTTP) ──► Backend A (Mac 3 — 10.7.13.5:3001)
  │
  └─► 3b. Proxy Request (HTTP) ──► Backend B (Mac 4 — 10.7.29.244:3002)
```

> [!IMPORTANT]
> TLS terminates at nginx on Mac 2. Upstream traffic between Mac 2 and Backend A (`10.7.13.5:3001`) or Backend B (`10.7.29.244:3002`) uses HTTP. TLS is not directly executed on the backend Node.js processes.

## Conceptual TLS Handshake Mechanics

When a client initiates an HTTPS session to `https://app.teamX.test:8443`, the following TLS 1.3 handshake sequence takes place at the transport layer:

```
Client                                                  Server (nginx on Mac 2)
  │                                                                │
  │ ─── 1. ClientHello (Cipher suites, Key Share, Extensions) ──► │
  │                                                                │
  │ ◄── 2. ServerHello (Selected Cipher, Server Key Share) ────── │
  │ ◄── 3. EncryptedExtensions & Certificate (app.teamX.test.pem)  │
  │ ◄── 4. CertificateVerify (Digital signature over handshake) ── │
  │ ◄── 5. Finished (Server handshake MAC) ─────────────────────── │
  │                                                                │
  │ ─── 6. Finished (Client handshake MAC) ──────────────────────► │
  │                                                                │
  │ ◄════════════ 7. Encrypted Application Data (HTTP) ══════════► │
```

1. **ClientHello**: Client proposes supported TLS versions (TLS 1.3), cipher suites (e.g., `TLS_CHACHA20_POLY1305_SHA256`), and key exchange parameters.
2. **ServerHello**: nginx selects the cipher suite and provides its key exchange parameter.
3. **Certificate**: nginx sends `app.teamX.test.pem` containing its public key and Subject Alternative Name (`DNS:app.teamX.test`).
4. **Key Exchange & CertificateVerify**: Diffie-Hellman key exchange establishes session keys; server signs handshake data with `app.teamX.test-key.pem` to prove ownership.
5. **Finished**: Both endpoints verify message integrity.
6. **Encrypted Application Data**: All subsequent HTTP request/response payloads are transmitted securely using symmetric session encryption.

## Simultaneous HTTP & HTTPS Support

Task E preserves the working Task D HTTP listener on port 8080 alongside the new HTTPS listener on port 8443:
- **Port 8080**: Handles unencrypted HTTP traffic.
- **Port 8443**: Handles encrypted HTTPS / TLS traffic.

Both server blocks forward requests to the unified `upstream backend_pool`.
