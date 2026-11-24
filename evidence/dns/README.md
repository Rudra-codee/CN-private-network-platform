# DNS Technical Evidence Catalog & Audit Index

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** Authoritative Evidence Index for Primary & Backup DNS Infrastructure  
**Target Path:** `evidence/dns/README.md`  
**Classification:** Evidence Audit Index  
**Auditor:** Rudraksh (Senior Computer Networks Engineer & Technical Evidence Auditor)  
**Date of Audit:** 2026-11-25  

---

## 1. Executive Summary & Quick Navigation (30-Second Lookup)

This directory serves as the centralized repository of empirical test outputs, configuration dumps, resolution verifications, and fault audits for the **Private Network Service Platform (Phase 1 & Phase 2)**.

All evidence items have been captured directly from live macOS cluster nodes and verified against the physical network topology:
- **Mac1 (10.7.19.129):** Primary Private Authoritative DNS Server (`dnsmasq`) & Test Client
- **Mac2 (10.7.9.219):** Primary Edge Reverse Proxy & Load Balancer (`nginx`)
- **Mac3 (10.7.24.216):** Backup DNS Server (`dnsmasq`), Backend A (`:3001`), Backend B (`:3002`), Standby Edge (`:80`, `:443`)
- **Mac4:** Documentation Workstation Only (Unavailable as an active project server)

### 30-Second Evaluator Quick-Reference Table

| Topic / Feature | Primary Evidence File | Supporting Report | Observed Result Summary | Audit Status |
|---|---|---|---|---|
| **A1. Active Config File** | [`primary-dns-config/mac1-dnsmasq-active-config.txt`](primary-dns-config/mac1-dnsmasq-active-config.txt) | [Section 2.1](#item-a1-primary-dnsmasq-active-configuration) | Confirms `/opt/homebrew/etc/dnsmasq.conf` contains active directives & `local-ttl=30` | **VERIFIED** |
| **A2. Syntax Check** | [`primary-dns-config/mac1-dnsmasq-syntax-test.txt`](primary-dns-config/mac1-dnsmasq-syntax-test.txt) | [Section 2.2](#item-a2-dnsmasq-syntax-validation-output) | `dnsmasq: syntax check OK.` | **VERIFIED** |
| **A3. Service & Listeners** | [`primary-dns-config/mac1-port53-listeners.txt`](primary-dns-config/mac1-port53-listeners.txt) | [Section 2.3](#item-a3-port-53-socket-listeners--service-status) | TCP/UDP 53 bound specifically to `127.0.0.1` and `10.7.19.129` | **VERIFIED** |
| **B1. `app.teamX.test`** | [`resolution-tests/dig-mac1-app.txt`](resolution-tests/dig-mac1-app.txt) | [Section 3.1](#item-b1-primary-resolution-appteamxtest) | Resolves to `10.7.24.216` (Mac3 Standby Edge), `NOERROR`, `TTL: 30`, `AA=1` | **VERIFIED** |
| **B2. `api.teamX.test`** | [`resolution-tests/dig-mac1-api.txt`](resolution-tests/dig-mac1-api.txt) | [Section 3.2](#item-b2-primary-resolution-apiteamxtest) | Resolves to `10.7.9.219` (Mac2 Primary Edge), `NOERROR`, `TTL: 30`, `AA=1` | **VERIFIED** |
| **B3. `ttl-test.teamX.test`** | [`resolution-tests/dig-mac1-ttl-test.txt`](resolution-tests/dig-mac1-ttl-test.txt) | [Section 3.3](#item-b3-primary-resolution-ttl-testteamxtest) | Resolves to `10.7.9.219`, `NOERROR`, `TTL: 30`, `AA=1` | **VERIFIED** |
| **C. Backup Comparison** | [`backup-dns-comparison/dig-mac3-app.txt`](backup-dns-comparison/dig-mac3-app.txt) | [`backup-dns-comparison/dns-primary-backup-comparison.md`](backup-dns-comparison/dns-primary-backup-comparison.md) | Mac3 returns matching records for all 3 core domains with `TTL: 30` | **VERIFIED** |
| **D. DNS Failover** | [`failover/failover-procedure-and-status.md`](failover/failover-procedure-and-status.md) | [Section 5](#category-d-dns-failover-evidence) | Mac3 independently resolves all names; client failover documented | **HISTORICAL** |
| **E1. Wire TTL (30s)** | [`ttl/mac1-ttl-response-evidence.txt`](ttl/mac1-ttl-response-evidence.txt) | [`ttl/controlled-record-change-evidence.md`](ttl/controlled-record-change-evidence.md) | Wire packets carry `TTL: 30` on both Mac1 and Mac3 | **VERIFIED** |
| **E2. Record Change** | [`ttl/controlled-record-change-evidence.md`](ttl/controlled-record-change-evidence.md) | [Section 6.2](#item-e2-controlled-record-change-history) | Migration of `app.teamX.test` from Mac2 (`.9.219`) to Mac3 (`.24.216`) | **VERIFIED** |
| **F1. Practice Fault** | [`troubleshooting/fault-test-record-audit.txt`](troubleshooting/fault-test-record-audit.txt) | [`troubleshooting/troubleshooting-log-analysis.md`](troubleshooting/troubleshooting-log-analysis.md) | `fault-test.teamX.test` remains active on Mac1 (`10.7.9.219`); Mac3 returns `NXDOMAIN` | **VERIFIED** |
| **F2. Negative Lookup** | [`troubleshooting/nxdomain-test.txt`](troubleshooting/nxdomain-test.txt) | [Section 7.2](#item-f2-negative-resolution-nxdomain) | Query for `nonexistent.teamX.test` returns `RCODE 3 (NXDOMAIN)` | **VERIFIED** |

---

## 2. Category A: Primary DNS Configuration Evidence

### Item A1: Primary dnsmasq Active Configuration
- **Evidence File:** [`primary-dns-config/mac1-dnsmasq-active-config.txt`](primary-dns-config/mac1-dnsmasq-active-config.txt)
- **Feature Demonstrated:** Active primary resolver configuration directives on Mac1.
- **Machine Where Collected:** Mac1 (`10.7.19.129`).
- **Command Used:** `cat /opt/homebrew/etc/dnsmasq.conf`
- **Observed Result:** Confirms listener addresses (`127.0.0.1,10.7.19.129`), `bind-interfaces`, authoritative domain mappings (`app.teamX.test -> 10.7.24.216`, `api.teamX.test -> 10.7.9.219`, `ttl-test.teamX.test -> 10.7.9.219`), `local-ttl=30`, upstream resolvers (`8.8.8.8`, `1.1.1.1`), `no-resolv`, `domain-needed`, `bogus-priv`, and uncleaned practice fault record `fault-test.teamX.test`.
- **What it Proves:** Proves the exact directives loaded by the running dnsmasq daemon on Mac1.
- **What it Does Not Prove:** Does not prove the process is running or listening on ports (see Item A3).
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

### Item A2: dnsmasq Syntax Validation Output
- **Evidence File:** [`primary-dns-config/mac1-dnsmasq-syntax-test.txt`](primary-dns-config/mac1-dnsmasq-syntax-test.txt)
- **Feature Demonstrated:** Built-in syntax integrity verification of configuration file.
- **Machine Where Collected:** Mac1 (`10.7.19.129`).
- **Command Used:** `/opt/homebrew/sbin/dnsmasq --test -C /opt/homebrew/etc/dnsmasq.conf`
- **Observed Result:** `dnsmasq: syntax check OK.`
- **What it Proves:** The active configuration contains no syntax errors or malformed directives.
- **What it Does Not Prove:** Does not prove that target IP addresses are reachable.
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

### Item A3: Port 53 Socket Listeners & Service Status
- **Evidence Files:**
  - Socket Listeners: [`primary-dns-config/mac1-port53-listeners.txt`](primary-dns-config/mac1-port53-listeners.txt)
  - Service Status: [`primary-dns-config/mac1-dns-service-status.txt`](primary-dns-config/mac1-dns-service-status.txt)
- **Feature Demonstrated:** Operating system socket binding and daemon process execution state.
- **Machine Where Collected:** Mac1 (`10.7.19.129`).
- **Commands Used:** `netstat -an -f inet | grep '\.53 '`, `brew services list | grep dnsmasq`, `ps aux | grep '[d]nsmasq'`
- **Observed Result:**
  - TCP sockets listening on `127.0.0.1.53` and `10.7.19.129.53`.
  - UDP sockets open on `127.0.0.1.53` and `10.7.19.129.53`.
  - Process PID `74977` executing binary `/opt/homebrew/opt/dnsmasq/sbin/dnsmasq` under user `nobody`.
- **What it Proves:** The daemon is actively listening for incoming DNS requests specifically on the private LAN interface.
- **What it Does Not Prove:** Does not test query resolution semantics (covered in Category B).
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

---

## 3. Category B: Primary DNS Resolution Tests

### Item B1: Primary Resolution `app.teamX.test`
- **Evidence File:** [`resolution-tests/dig-mac1-app.txt`](resolution-tests/dig-mac1-app.txt)
- **Feature Demonstrated:** Application domain resolution on Primary DNS.
- **Machine Where Collected:** Mac1 (`10.7.19.129`).
- **Command Used:** `dig @10.7.19.129 app.teamX.test`
- **Observed Result:**
  ```text
  status: NOERROR, flags: qr aa rd ra
  app.teamX.test.   30   IN   A   10.7.24.216
  ```
- **What it Proves:** Mac1 authoritatively resolves `app.teamX.test` to the migrated standby edge on Mac3 with a 30s TTL.
- **What it Does Not Prove:** Does not prove HTTP/TLS services on Mac3 are reachable or functioning.
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

### Item B2: Primary Resolution `api.teamX.test`
- **Evidence File:** [`resolution-tests/dig-mac1-api.txt`](resolution-tests/dig-mac1-api.txt)
- **Feature Demonstrated:** API gateway domain resolution on Primary DNS.
- **Machine Where Collected:** Mac1 (`10.7.19.129`).
- **Command Used:** `dig @10.7.19.129 api.teamX.test`
- **Observed Result:**
  ```text
  status: NOERROR, flags: qr aa rd ra
  api.teamX.test.   30   IN   A   10.7.9.219
  ```
- **What it Proves:** Mac1 authoritatively resolves `api.teamX.test` to Mac2 primary edge.
- **What it Does Not Prove:** Does not test Nginx proxy pass or backend load balancing.
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

### Item B3: Primary Resolution `ttl-test.teamX.test`
- **Evidence File:** [`resolution-tests/dig-mac1-ttl-test.txt`](resolution-tests/dig-mac1-ttl-test.txt)
- **Feature Demonstrated:** Dedicated TTL experimentation record resolution.
- **Machine Where Collected:** Mac1 (`10.7.19.129`).
- **Command Used:** `dig @10.7.19.129 ttl-test.teamX.test`
- **Observed Result:**
  ```text
  status: NOERROR, flags: qr aa rd ra
  ttl-test.teamX.test.   30   IN   A   10.7.9.219
  ```
- **What it Proves:** Dedicated TTL test hostname is authoritatively registered and served with a 30s TTL.
- **What it Does Not Prove:** Does not measure client OS cache retention.
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

---

## 4. Category C: Backup DNS Comparison Evidence

### Item C1: Backup Resolver Query Outputs & Analysis
- **Evidence Files:**
  - `app.teamX.test` on Mac3: [`backup-dns-comparison/dig-mac3-app.txt`](backup-dns-comparison/dig-mac3-app.txt)
  - `api.teamX.test` on Mac3: [`backup-dns-comparison/dig-mac3-api.txt`](backup-dns-comparison/dig-mac3-api.txt)
  - `ttl-test.teamX.test` on Mac3: [`backup-dns-comparison/dig-mac3-ttl-test.txt`](backup-dns-comparison/dig-mac3-ttl-test.txt)
  - Detailed Comparison Report: [`backup-dns-comparison/dns-primary-backup-comparison.md`](backup-dns-comparison/dns-primary-backup-comparison.md)
- **Feature Demonstrated:** Multi-resolver parity and synchronization across primary (Mac1) and backup (Mac3).
- **Machine Where Collected:** Queried from Mac1 targeting Mac3 (`10.7.24.216`).
- **Commands Used:** `dig @10.7.24.216 <domain>`
- **Observed Result:**
  - `app.teamX.test` -> `10.7.24.216` (`NOERROR`, `TTL: 30`, `AA=1`) -> **100% Match**
  - `api.teamX.test` -> `10.7.9.219` (`NOERROR`, `TTL: 30`, `AA=1`) -> **100% Match**
  - `ttl-test.teamX.test` -> `10.7.9.219` (`NOERROR`, `TTL: 30`, `AA=1`) -> **100% Match**
  - `fault-test.teamX.test` -> `NXDOMAIN` on Mac3 vs `10.7.9.219` on Mac1 -> **Discrepancy (Documented)**
- **What it Proves:** Proves Mac3 backup DNS is operational, reachable across the LAN, and serves identical production records.
- **What it Does Not Prove:** Does not test client automated switching during network partition.
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

---

## 5. Category D: DNS Failover Evidence

### Item D1: Failover Architecture & Procedure Documentation
- **Evidence File:** [`failover/failover-procedure-and-status.md`](failover/failover-procedure-and-status.md)
- **Feature Demonstrated:** High-availability resolver failover procedure, empirical status, and OS resolver behavior.
- **Machine Where Collected:** Mac1 audit analysis.
- **Procedure Evaluated:** Stop Mac1 primary DNS, dispatch client query, verify Mac3 backup answer.
- **Observed Result:**
  - Mac3 capacity to independently resolve all project records is live and verified.
  - Failover sequence and dual-resolver architecture (`nameserver 10.7.19.129`, `nameserver 10.7.24.216`) are documented in `docs/architecture/sections/02_DNS_Architecture.md`.
  - Live service deactivation was not executed during this audit turn to preserve ongoing cluster operations.
- **What it Proves:** Proves architectural capability and readiness of secondary resolver to handle client traffic.
- **What it Does Not Prove:** A live end-to-end packet trace showing client stub resolver failover timing is not present in repo logs.
- **Status:** **HISTORICALLY DOCUMENTED / PARTIALLY VERIFIED**.

---

## 6. Category E: DNS TTL Extension Evidence

### Item E1: 30-Second Response Wire TTL
- **Evidence Files:**
  - Mac1 TTL Query: [`ttl/mac1-ttl-response-evidence.txt`](ttl/mac1-ttl-response-evidence.txt)
  - Mac3 TTL Query: [`ttl/mac3-ttl-response-evidence.txt`](ttl/mac3-ttl-response-evidence.txt)
  - Controlled Change Report: [`ttl/controlled-record-change-evidence.md`](ttl/controlled-record-change-evidence.md)
- **Feature Demonstrated:** Propagation of `local-ttl=30` directive into DNS Answer Section wire packets.
- **Machine Where Collected:** Mac1 querying both `10.7.19.129` and `10.7.24.216`.
- **Commands Used:** `dig @<server> ttl-test.teamX.test`
- **Observed Result:** Both resolvers emit answers with `TTL = 30` seconds in the resource record header.
- **What it Proves:** Proves `local-ttl=30` is active and applied to UDP response packets on both servers.
- **What it Does Not Prove:** Does not prove client OS cache holds the record for 30s (dig bypasses OS cache).
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

### Item E2: Controlled Record Change History
- **Evidence File:** [`ttl/controlled-record-change-evidence.md`](ttl/controlled-record-change-evidence.md)
- **Feature Demonstrated:** Verification of controlled DNS migration from pre-migration backups on disk.
- **Artifacts Inspected:** `/opt/homebrew/etc/dnsmasq.conf.pre-edge-migration` vs `/opt/homebrew/etc/dnsmasq.conf`.
- **Observed Result:** `app.teamX.test` transitioned from Mac2 (`10.7.9.219`) to Mac3 (`10.7.24.216`), verifying controlled cutover.
- **What it Proves:** Proves record updates were successfully deployed and verified during Phase 2 Extension E.
- **What it Does Not Prove:** Does not prove traffic drain rate on Mac2 during the 30-second TTL propagation window.
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

---

## 7. Category F: DNS Troubleshooting Evidence

### Item F1: Practice Fault Audit (`fault-test.teamX.test`)
- **Evidence Files:**
  - Raw Multi-Server Query: [`troubleshooting/fault-test-record-audit.txt`](troubleshooting/fault-test-record-audit.txt)
  - Troubleshooting Report: [`troubleshooting/troubleshooting-log-analysis.md`](troubleshooting/troubleshooting-log-analysis.md)
- **Feature Demonstrated:** Intentional fault injection audit and cleanup tracking.
- **Machine Where Collected:** Mac1 querying both `10.7.19.129` and `10.7.24.216`.
- **Commands Used:** `dig @10.7.19.129 fault-test.teamX.test`, `dig @10.7.24.216 fault-test.teamX.test`
- **Observed Result:**
  - Mac1 returns `10.7.9.219` (`NOERROR`, `AA=1`).
  - Mac3 returns `NXDOMAIN` (`RCODE 3`, `Answer: 0`).
- **What it Proves:** Proves that cleanup was **NOT completed** on Mac1 following troubleshooting tests; the record remains in `/opt/homebrew/etc/dnsmasq.conf`.
- **What it Does Not Prove:** Does not indicate any failure on core production records (`app`, `api`, `ttl-test`).
- **Status:** **CURRENT / VERIFIED DISCREPANCY** (Collected 2026-11-25).

### Item F2: Negative Resolution (`NXDOMAIN`)
- **Evidence File:** [`troubleshooting/nxdomain-test.txt`](troubleshooting/nxdomain-test.txt)
- **Feature Demonstrated:** Synthesis of authoritative negative responses for non-existent names.
- **Machine Where Collected:** Mac1 (`10.7.19.129`).
- **Command Used:** `dig @10.7.19.129 nonexistent.teamX.test`
- **Observed Result:** `status: NXDOMAIN`, `flags: qr rd ra`, `ANSWER: 0`.
- **What it Proves:** dnsmasq correctly identifies unmapped names within private zone and refrains from leaking them upstream.
- **What it Does Not Prove:** Does not test negative caching (`SOA` minimum TTL).
- **Status:** **CURRENT / VERIFIED** (Collected 2026-11-25).

---

## 8. Master Evidence Audit Classification Table

| Evidence Artifact Path | Scope / Feature | Classification | Audit Verification Notes |
|---|---|---|---|
| `primary-dns-config/mac1-dnsmasq-active-config.txt` | Configuration Directives | **VERIFIED** | Read directly from active `/opt/homebrew/etc/dnsmasq.conf`. |
| `primary-dns-config/mac1-dnsmasq-syntax-test.txt` | Configuration Syntax Check | **VERIFIED** | Output: `dnsmasq: syntax check OK.` |
| `primary-dns-config/mac1-port53-listeners.txt` | Port 53 Netstat Listener | **VERIFIED** | Verified TCP/UDP listeners on `127.0.0.1` and `10.7.19.129`. |
| `primary-dns-config/mac1-dns-service-status.txt` | Process & Service Execution | **VERIFIED** | Process PID `74977` running under user `nobody`. |
| `resolution-tests/dig-mac1-app.txt` | `app.teamX.test` on Mac1 | **VERIFIED** | Returns `10.7.24.216`, `NOERROR`, `TTL: 30`, `AA=1`. |
| `resolution-tests/dig-mac1-api.txt` | `api.teamX.test` on Mac1 | **VERIFIED** | Returns `10.7.9.219`, `NOERROR`, `TTL: 30`, `AA=1`. |
| `resolution-tests/dig-mac1-ttl-test.txt` | `ttl-test.teamX.test` on Mac1 | **VERIFIED** | Returns `10.7.9.219`, `NOERROR`, `TTL: 30`, `AA=1`. |
| `backup-dns-comparison/dig-mac3-app.txt` | `app.teamX.test` on Mac3 | **VERIFIED** | Returns `10.7.24.216`, `NOERROR`, `TTL: 30`, `AA=1`. |
| `backup-dns-comparison/dig-mac3-api.txt` | `api.teamX.test` on Mac3 | **VERIFIED** | Returns `10.7.9.219`, `NOERROR`, `TTL: 30`, `AA=1`. |
| `backup-dns-comparison/dig-mac3-ttl-test.txt` | `ttl-test.teamX.test` on Mac3 | **VERIFIED** | Returns `10.7.9.219`, `NOERROR`, `TTL: 30`, `AA=1`. |
| `backup-dns-comparison/dns-primary-backup-comparison.md` | Primary vs. Backup Analysis | **VERIFIED** | 100% record parity on production domains; discrepancy on fault-test. |
| `failover/failover-procedure-and-status.md` | Resolver Failover Report | **HISTORICAL** | Secondary resolver capability verified; live transition trace uncommitted. |
| `ttl/mac1-ttl-response-evidence.txt` | Wire TTL 30s on Mac1 | **VERIFIED** | Second column in Answer Section is `30`. |
| `ttl/mac3-ttl-response-evidence.txt` | Wire TTL 30s on Mac3 | **VERIFIED** | Second column in Answer Section is `30`. |
| `ttl/controlled-record-change-evidence.md` | Record Change & TTL Analysis | **VERIFIED** | Verified migration cutover; clarifies client cache retention boundary. |
| `troubleshooting/fault-test-record-audit.txt` | Practice Fault Audit Log | **VERIFIED** | Proves Mac1 returns `10.7.9.219`, Mac3 returns `NXDOMAIN`. |
| `troubleshooting/nxdomain-test.txt` | Negative Resolution Log | **VERIFIED** | Proves `nonexistent.teamX.test` returns `NXDOMAIN`. |
| `troubleshooting/troubleshooting-log-analysis.md` | Troubleshooting Technical Report | **VERIFIED** | Full analysis of uncleaned practice fault, listeners, and negative caching. |
| `evidence/02-dns/dns-server-verification.md` | Phase 1 DNS Server Baseline | **HISTORICAL** | Historical Phase 1 baseline (`10.7.17.222` -> `10.7.9.11`). |
| `evidence/02-dns/client-verification.md` | Phase 1 DNS Client Baseline | **HISTORICAL** | Historical Phase 1 client verification from Mac2 & Mac4. |
| Client-side 30s cache retention trace | Non-network Cache Hit Log | **MISSING** | `dig` bypasses OS stub cache; OS cache retention not isolated. |
| Synchronized client failover packet capture | Wireshark Failover Pcap | **INCOMPLETE** | Procedure documented, but packet capture trace of cutover not committed. |
