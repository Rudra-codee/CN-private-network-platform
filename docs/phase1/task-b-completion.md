# Task B — Completion Report

## Objective

Configure a private DNS server on Mac 1 using `dnsmasq` to provide authoritative name resolution for the project's private domains (`app.teamX.test` and `api.teamX.test`), and verify that at least two other machines on the LAN use it as their DNS resolver.

## Requirements

| Requirement | Status |
|---|---|
| dnsmasq installed and configured on Mac 1 | ✅ |
| dnsmasq listening on 10.7.17.222:53 | ✅ Confirmed via lsof |
| `app.teamX.test` resolves to Mac 2 (10.7.9.11) | ✅ |
| `api.teamX.test` resolves to Mac 2 (10.7.9.11) | ✅ |
| At least two client Macs use Mac 1 as DNS resolver | ✅ Mac 2 and Mac 4 |
| dig evidence collected from DNS server | ✅ |
| dig evidence collected from DNS clients | ✅ |

## DNS Server

| Property | Value |
|---|---|
| Host | Mac 1 — 10.7.17.222 |
| Software | dnsmasq 2.93 |
| Port | 53/UDP |
| Interface | en0 |

## DNS Records

| Domain | Resolved IP | Target |
|---|---|---|
| app.teamX.test | 10.7.9.11 | Mac 2 (Edge / Reverse Proxy) |
| api.teamX.test | 10.7.9.11 | Mac 2 (Edge / Reverse Proxy) |

## DNS Clients Verified

| Client | DNS Server | app.teamX.test | api.teamX.test |
|---|---|---|---|
| Mac 2 (10.7.9.11) | 10.7.17.222 | ✅ → 10.7.9.11 | ✅ → 10.7.9.11 |
| Mac 4 (10.7.11.88) | 10.7.17.222 | ✅ → 10.7.9.11 | ✅ → 10.7.9.11 |

## Evidence

| Document | Location |
|---|---|
| DNS server verification | `evidence/02-dns/dns-server-verification.md` |
| DNS client verification | `evidence/02-dns/client-verification.md` |
| dnsmasq configuration | `configs/dns/dnsmasq.conf` |
| DNS architecture | `docs/architecture/dns.md` |

## Result

Task B has been completed and documented. The private DNS server is operational on Mac 1, both configured client machines resolve the project domains correctly, and all verification evidence has been recorded.

## Boundary

Task B covers DNS server setup and verification only. The following are **NOT** part of this task:

- Backend application services (Task C)
- nginx reverse proxy / load balancing (Task D)
- HTTPS / TLS termination (Task E)
- HTTP caching (Task F)
- Wireshark packet captures (Task G)
- Failure scenario demonstrations (Task H)
