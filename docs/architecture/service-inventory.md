# Service Inventory

This document details the machine role assignments and planned network services for Phase 1 of the Private Network Service Platform.

## Machine Roles and Planned Services

| Machine | Phase 1 Role | Planned Service | Port |
|---|---|---|---|
| Mac 1 | Private DNS + Client | dnsmasq | 53/UDP |
| Mac 2 | Edge / Reverse Proxy + Load Balancer | nginx / HTTPS | 443/TCP |
| Mac 3 | Backend Server A | REST application | 3001/TCP |
| Mac 4 | Backend Server B + Client | REST application | 3002/TCP |

> [!IMPORTANT]
> These services are part of the planned Phase 1 architecture. Task A only establishes the underlying LAN connectivity. The services listed above are **not** currently running and will be deployed in subsequent Phase 1 tasks.

## Required Domain Records (Planned)

The private DNS server (`dnsmasq` on Mac 1) will be configured with the following authoritative A records in Task B:

- `app.teamX.test` → `10.7.9.11` (Mac 2)
- `api.teamX.test` → `10.7.9.11` (Mac 2)

## Current Network

| Machine | IPv4 Address | Status |
|---|---|---|
| Mac 1 | 10.7.17.222 | Connected to LAN ✅ |
| Mac 2 | 10.7.9.11 | Connected to LAN ✅ |
| Mac 3 | 10.7.13.5 | Connected to LAN ✅ |
| Mac 4 | 10.7.11.88 | Connected to LAN ✅ |
