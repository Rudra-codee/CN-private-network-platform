# Service Inventory

This document details all network services, their host assignments, protocol types, listening ports, and operational roles within Phase 1.

## Service Mapping Table

| Service | Machine | Protocol | Port | Purpose |
|---------|---------|----------|------|---------|
| DNS | Mac 1 | UDP | 53 | Private name resolution |
| HTTPS | Mac 2 | TCP | 443 | Secure client entry point |
| Backend A | Mac 3 | TCP | 3001 | Application server A |
| Backend B | Mac 4 | TCP | 3002 | Application server B |

## Required Domain Records

The private DNS server (`dnsmasq` on Mac 1) must be configured with the following authoritative A records:

- `app.teamX.test` → `<Mac 2 Private IP>`
- `api.teamX.test` → `<Mac 2 Private IP>`
