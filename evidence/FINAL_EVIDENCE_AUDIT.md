# Final Technical Evidence Audit Report

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** Comprehensive Evidence Audit, Quality Review, Defect Catalog & Readiness Assessment  
**Target Path:** `evidence/FINAL_EVIDENCE_AUDIT.md`  
**Classification:** Senior Technical Evaluation Report  
**Lead Auditor:** Bhargav (Senior Computer Networks Project Evaluator & Technical Evidence Auditor)  
**Workstation Demarcation:** Mac4 (Documentation Workstation Only — NOT an Active Project Server)  
**Date of Audit:** 2026-11-25  

---

## 1. Executive Summary & Audit Methodology

As the senior technical evidence auditor, this report delivers an exhaustive, evidence-driven evaluation of the **Private Network Service Platform**. The audit reviews all empirical artifacts, configuration files, terminal logs, and documentation committed to the repository to verify that all claims are backed by reproducible proof.

### 1.1 Summary of Evaluated Infrastructure

The active operational platform is deployed across three macOS hardware nodes operating within the private `10.7.0.0/19` subnet:
- **Mac1 (`10.7.19.129`):** Primary Authoritative DNS Resolver (`dnsmasq` v2.93) & Test Client
- **Mac2 (`10.7.9.219`):** Primary Edge Reverse Proxy, TLS 1.3 Terminator & Cache (`nginx` v1.31.6 on `8080` & `8443`)
- **Mac3 (`10.7.24.216`):** Multi-tenant host running Backend A (`:3001`), Backend B (`:3002`), Backup DNS (`:53`), Standby Nginx (`:80`, `:443`), and Packet Filter (`pf`) firewall.
- **Mac4:** Documentation Workstation Only. **Not an active infrastructure server.**

---

## 2. Directories Inspected & File Inventory

The audit inspected all directories under `evidence/` and core documentation roots:

### 2.1 Evidence Directories Inspected

| Directory Path | Files Found | Artifact Description | Audit Classification |
|---|---|---|---|
| `evidence/dns/` | 19 files | Complete suite of raw `dig` outputs, config dumps, syntax tests, socket listeners, and reports. | **VERIFIED** |
| `evidence/nginx-http-tls/` | 7 files | Structured reports for edge proxying, TLS 1.3, load balancing, caching, and protocol traces. | **VERIFIED** |
| `evidence/01-lan/` | 2 files | Network interface inventory and 4-machine ICMP ping reachability matrix. | **HISTORICAL** |
| `evidence/02-dns/` | 2 files | Initial Phase 1 DNS server and client resolution evidence (`10.7.17.222`). | **HISTORICAL** |
| `evidence/03-backends/` | 2 files | Backend A (`10.7.13.5:3001`) and Backend B (`10.7.29.244:3002`) startup and curl evidence. | **HISTORICAL** |
| `evidence/04-nginx/` | 2 files | Nginx port 8080 proxy verification and 10-request load balancing loop. | **HISTORICAL** |
| `evidence/05-tls/` | 4 files | Leaf certificate SAN validation, port 8443 TLS 1.3 verification, and client CA trust evidence. | **HISTORICAL** |
| `evidence/06-caching/` | 4 files | Proxy cache directives, `X-Cache-Status` transitions, and Backend A/B ETag compatibility. | **HISTORICAL** |
| `evidence/07-wireshark/mac1/` | 4 files | 3 PNG frame capture screenshots and comprehensive protocol dissection README. | **VERIFIED** |
| `evidence/08-failures/` | 0 files | Directory contains `.gitkeep` only; no raw failure logs stored. | **INCOMPLETE** |
| `evidence/resilience-security/` | *None* | Directory does not exist in repository; firewall & failover logs missing. | **MISSING** |

**Total Genuine Non-Hidden Evidence Files Found:** **46 files** (plus 8 archival `.gitkeep` files).

---

## 3. Evidence Coverage by Feature

### 3.1 Phase 1 Mandatory Tasks

| Feature Requirement | Required Telemetry | Evidence Artifact Available | Evaluation Finding | Status |
|---|---|---|---|---|
| **LAN Connectivity (Task A)** | 0% packet loss across all pairs | [`evidence/01-lan/ping-verification.md`](01-lan/ping-verification.md) | Verified 4-node ping matrix with 0% loss; uses Phase 1 IPs. | **HISTORICAL** |
| **Private DNS Setup (Task B)** | `dnsmasq` port 53 listener | [`evidence/dns/primary-dns-config/mac1-port53-listeners.txt`](dns/primary-dns-config/mac1-port53-listeners.txt) | Netstat confirms listeners on `127.0.0.1.53` and `10.7.19.129.53`. | **VERIFIED** |
| **Domain Resolution (Task B)** | Resolve `app` & `api` to edge | [`evidence/dns/resolution-tests/dig-mac1-app.txt`](dns/resolution-tests/dig-mac1-app.txt) | `dig` confirms `app` -> `10.7.24.216` and `api` -> `10.7.9.219`. | **VERIFIED** |
| **Backend A & B Responses (Task C)** | HTTP 200, `X-Backend` header | [`evidence/03-backends/backend-a-verification.md`](03-backends/backend-a-verification.md) | Backend A returns `X-Backend: A`; Backend B returns `X-Backend: B`. | **VERIFIED** |
| **Nginx Reverse Proxy (Task D)** | Port 8080 proxying | [`evidence/nginx-http-tls/http/http-reverse-proxy.md`](nginx-http-tls/http/http-reverse-proxy.md) | Confirmed HTTP/1.1 200 OK via Nginx proxy to backends. | **VERIFIED** |
| **Round-Robin Load Balancing (Task D)** | Alternating responses | [`evidence/nginx-http-tls/load-balancing/load-balancing-verification.md`](nginx-http-tls/load-balancing/load-balancing-verification.md) | 10-request loop proves deterministic alternation. | **VERIFIED** |
| **Edge TLS Termination (Task E)** | Port 8443, TLS 1.3 | [`evidence/nginx-http-tls/https-tls/https-tls-verification.md`](nginx-http-tls/https-tls/https-tls-verification.md) | OpenSSL and curl verify TLS 1.3 handshake and SAN. | **VERIFIED** |
| **Certificate Trust (Task E)** | No `curl -k` flag | [`evidence/05-tls/mac1-client-verification.md`](05-tls/mac1-client-verification.md) | Clean HTTPS connection without `-k` or insecure flags. | **VERIFIED** |
| **HTTP Caching (Task F)** | `MISS` -> `HIT`, `304` | [`evidence/nginx-http-tls/caching/caching-verification.md`](nginx-http-tls/caching/caching-verification.md) | Verified `X-Cache-Status: MISS` then `HIT`; `304 Not Modified`. | **VERIFIED** |
| **Wireshark Capture (Task G)** | DNS, TCP, TLS frames | [`evidence/07-wireshark/mac1/`](07-wireshark/mac1/) | 3 PNG screenshots dissect DNS, TCP 3-way, and TLS 1.3 frames. | **VERIFIED** |

### 3.2 Phase 2 Extensions (Extensions A–F)

| Extension | Objective | Evidence Location | Audit Finding | Status |
|---|---|---|---|---|
| **Extension A** | Backup DNS Resolver | [`evidence/dns/backup-dns-comparison/`](dns/backup-dns-comparison/) | Mac3 resolves all domains authoritatively with matching IPs and TTL=30. | **VERIFIED** |
| **Extension B** | DNS TTL (30s) | [`evidence/dns/ttl/`](dns/ttl/) | Wire packet carries `TTL: 30`. Client OS cache retention unverified. | **VERIFIED (Wire) / INCOMPLETE (OS Cache)** |
| **Extension C** | PF Firewall | [`docs/architecture/sections/04_Security_Resilience_and_Troubleshooting.md`](../docs/architecture/sections/04_Security_Resilience_and_Troubleshooting.md) | Ruleset documented; raw terminal logs missing from evidence tree. | **INCOMPLETE** |
| **Extension D** | Backend Failover | [`evidence/nginx-http-tls/load-balancing/`](nginx-http-tls/load-balancing/) | Process-level failover documented; raw terminal kill loop uncommitted. | **INCOMPLETE** |
| **Extension E** | DNS Edge Migration | [`evidence/dns/ttl/controlled-record-change-evidence.md`](dns/ttl/controlled-record-change-evidence.md) | Cutover of `app.teamX.test` to Mac3 verified from pre-migration backups. | **VERIFIED** |
| **Extension F** | Faculty Fault Isolation | [`evidence/dns/troubleshooting/`](dns/troubleshooting/) | Practice fault verified; cleanup not completed; faculty exam pending. | **IN PROGRESS** |

---

## 4. Missing and Incomplete Evidence

1. **Binary Packet Capture Files (`.pcap` / `.pcapng`):**  
   Only PNG screenshot images (`mac1-tls13-https-capture.png`, etc.) exist in `evidence/07-wireshark/mac1/`. The underlying raw `.pcap` capture files were not committed to version control.
2. **Missing `evidence/resilience-security/` Directory:**  
   The project specification suggested an evidence directory for resilience and security. Currently, PF firewall rules and backend process kill loops are documented in Section 04 and Security README, but raw terminal text captures are absent from the evidence tree.
3. **Automated Client Failover Transition Capture:**  
   While Mac3 is proven capable of resolving queries independently, a synchronized packet trace capturing client stub resolver fallback during a forced Mac1 shutdown is absent.
4. **Client-Side OS Cache Retention Evidence:**  
   Wire TTL of 30 seconds is proven, but non-network OS cache retention via `dscacheutil` was not captured.

---

## 5. Duplicate, Misleading or Outdated Files

1. **Phase 1 Historical Configurations in `configs/`:**  
   [`configs/dns/dnsmasq.conf`](../configs/dns/dnsmasq.conf) and [`configs/nginx/nginx.conf`](../configs/nginx/nginx.conf) contain Phase 1 IP addresses (`10.7.17.222`, `10.7.9.11`, `10.7.13.5`, `10.7.14.32`) and do not reflect Phase 2 runtime settings (`local-ttl=30`, consolidated backends on Mac3 at `10.7.24.216`). Evaluators should be directed to the runtime documentation in `docs/configuration/` and active dumps in `evidence/dns/primary-dns-config/`.
2. **Empty Directory `evidence/08-failures/`:**  
   Contains only `.gitkeep`. Failure scenario evidence was documented in analytical markdown files rather than stored as raw text logs in this folder.
3. **Hardcoded User Download Paths in Documentation:**  
   References to `file:///Users/kaustubhhiwanj/...` in `evidence/nginx-http-tls/` were corrected to clean relative links during this audit pass. References to `file:///Users/pratyushchouksey/Downloads/...` in `docs/configuration/mac3-backends/` remain as documented historical defects.

---

## 6. Technical Inconsistencies Disclosed

1. **Uncleaned Practice Fault (`fault-test.teamX.test`):**  
   Mac1 `/opt/homebrew/etc/dnsmasq.conf` continues to serve `address=/fault-test.teamX.test/10.7.9.219` (status `NOERROR`), whereas Mac3 returns `NXDOMAIN`. Cleanup was not completed after Phase 2 troubleshooting tests.
2. **Dynamic DHCP IP Shifts Across Phases:**  
   - Mac1: `10.7.17.222` (Phase 1) $\rightarrow$ `10.7.26.214` (Intermediate) $\rightarrow$ `10.7.19.129` (Phase 2).
   - Mac2: `10.7.9.11` (Phase 1) $\rightarrow$ `10.7.26.200` (Intermediate) $\rightarrow$ `10.7.9.219` (Phase 2).
   - Mac3: `10.7.13.5` (Phase 1) $\rightarrow$ `10.7.24.216` (Phase 2).
   - Mac4: `10.7.11.88` $\rightarrow$ `10.7.29.244` $\rightarrow$ Decommissioned / Offline.
3. **Edge Proxy Listener Port Asymmetry:**  
   Primary Edge (Mac2) listens on ports **8080/TCP** and **8443/TCP**. Standby Edge (Mac3) listens on ports **80/TCP** and **443/TCP**. Client target URLs must account for this difference during failover testing.

---

## 7. Unsupported Claims Refuted by Audit

1. ❌ **Claim:** *"Backend failover provides full hardware redundancy."*  
   **Refutation:** Both Backend A and Backend B run on Mac3. Failover is process-level only. A physical failure of Mac3 brings down both backends.
2. ❌ **Claim:** *"macOS clients strictly query Primary DNS and only switch to Backup DNS after a timeout."*  
   **Refutation:** macOS `mDNSResponder` uses dynamic latency tracking and may dispatch parallel queries or prefer whichever resolver has lower latency.
3. ❌ **Claim:** *"A DNS response with TTL 30 proves client applications cache the record for 30 seconds."*  
   **Refutation:** `dig` directly opens UDP sockets and bypasses the OS cache. Wire TTL does not guarantee OS cache retention.
4. ❌ **Claim:** *"Identical HTTP responses prove caching is functional."*  
   **Refutation:** Only the `X-Cache-Status: HIT` header emitted by Nginx proves a cache hit.
5. ❌ **Claim:** *"Extension F is 100% completed."*  
   **Refutation:** Only the practice fault has been executed; the faculty evaluation fault has not yet been administered.

---

## 8. Security and Privacy Audit

1. **Private Key Protection (`rootCA-key.pem` and `*-key.pem`):**  
   Audit confirms `.gitignore` properly blocks `*.key`, `*-key.pem`, and `rootCA-key.pem`. No private cryptographic keys were committed to git.
2. **Direct Backend Access Exposure Risk:**  
   Node.js backends bind to `0.0.0.0:3001` and `0.0.0.0:3002`. If Packet Filter (`pf`) firewall rules are flushed (`pfctl -d`), unauthenticated, unencrypted HTTP traffic can reach backends directly, bypassing edge TLS and caching.
3. **Practice Fault Exposure:**  
   The active `fault-test.teamX.test` record points to Mac2. While harmless on a private network, leaving uncleaned test records in production DNS is poor administrative practice.

---

## 9. Required Corrections Executed During Audit

- **Fixed Broken Links in `evidence/nginx-http-tls/configuration/nginx-configuration.md`:** Corrected hardcoded link `file:///Users/kaustubhhiwanj/...` to relative link `../../../configs/nginx/nginx.conf`.
- **Fixed Broken Links in `evidence/nginx-http-tls/wireshark/wireshark-protocol-analysis.md`:** Corrected 5 hardcoded links pointing to `file:///Users/kaustubhhiwanj/...` to relative paths `../../07-wireshark/mac1/...`.
- **Fixed Broken Link in `evidence/06-caching/nginx-cache-verification.md`:** Corrected hardcoded link `file:///Users/kaustubhhiwanj/...` to `../../configs/nginx/nginx.conf`.

---

## 10. Final Readiness Assessment

### Overall Status: **READY WITH ISSUES**

#### Assessment Justification:
- **Core Functionality is Fully Proven:** All Phase 1 deliverables (LAN, DNS, Backends, Nginx, Load Balancing, TLS 1.3, Caching, Protocol traces) and Phase 2 core extensions (Backup DNS, Wire TTL, Edge Migration) have genuine, verifiable evidence.
- **Why NOT Marked "READY":**
  1. Extension F is pending live faculty evaluation.
  2. The practice fault record `fault-test.teamX.test` remains uncleaned in Mac1's configuration.
  3. Raw terminal evidence files for Extension C (PF firewall `pfctl -sr`) and binary `.pcap` files were not stored in version control.
  4. Both backends are co-located on Mac3 (must be presented as application-level resilience, not hardware redundancy).

---

## 11. Top Five Priority Actions Before Evaluation

1. **Clean Up Practice Fault on Mac1:** Remove `address=/fault-test.teamX.test/10.7.9.219` from `/opt/homebrew/etc/dnsmasq.conf`, reload dnsmasq (`sudo brew services restart dnsmasq`), and verify `NXDOMAIN` is returned.
2. **Re-verify Live DHCP IP Addresses:** Execute `ifconfig en0` across all machines prior to the evaluation presentation to ensure IP leases have not expired or shifted.
3. **Capture PF Firewall Terminal Log:** On Mac3, execute `sudo pfctl -a teamX-backends -sr` and commit the output to satisfy raw evidence completeness for Extension C.
4. **Prepare Port Distinction Talking Points:** Rehearse the port distinction between Mac2 (`8080/8443`) and Mac3 (`80/443`) so team members explain migration port transitions clearly.
5. **Frame Co-Location Accurately:** Ensure all presenters explain that Backend A and Backend B run on Mac3 due to Mac4's unavailability, emphasizing process-level isolation rather than claiming hardware fault tolerance.
