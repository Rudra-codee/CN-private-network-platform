# Resilience, Security, Failover and Edge Migration Evidence Index

**Project**: Private Network Service Platform — Phase 1 & Phase 2  
**Host Machine**: Mac3 (`10.7.24.216`)  
**Auditor / Maintainer**: Pratyush (Senior Computer Networks Engineer & Evidence Auditor)  
**Location**: `evidence/resilience-security/README.md`  

---

## 1. Executive Summary & Audit Demarcation

This index catalogs and audits all resilience, security, process failover, and disaster recovery edge migration evidence collected from **Mac3** across **Phase 1** and **Phase 2**. 

To maintain strict scientific and engineering integrity, each piece of evidence is explicitly categorized by its verification status:
- **`VERIFIED`**: Directly executed and confirmed on the active live machine during this audit session.
- **`HISTORICAL`**: Validated and recorded during earlier Phase 2 testing sessions; preserved without re-running to avoid disrupting live running services.
- **`INCOMPLETE`**: Configuration or files exist, but end-to-end live runtime telemetry is partial.
- **`MISSING`**: Required artifact was not found in version control or host filesystem.

---

## 2. Master Evidence Index

| Evidence File | Extension Demonstrated | Target Machine | Collection Procedure / Command | Observed Result | Status | What It Proves | What It Does Not Prove |
|---|---|---|---|---|---|---|---|
| [`backend-health/backend-health-verification.md`](backend-health/backend-health-verification.md) | Core Backend Operations | Mac3 (`10.7.24.216`) | `lsof -nP -iTCP:3001,3002 -sTCP:LISTEN` & `curl --noproxy "*"` against ports 3001 and 3002. | PIDs 83711 and 71230 listening on `0.0.0.0`; `200 OK`, `X-Backend: A/B`, JSON bodies returned. | **VERIFIED** (Current) | Backend A and Backend B are actively running and healthy on Mac3. | Does not prove hardware redundancy; both run on Mac3. |
| [`pf-firewall/pf-firewall-evidence.md`](pf-firewall/pf-firewall-evidence.md) | Extension C: PF Firewall & Service Isolation | Mac3 (`10.7.24.216`) | Read `/etc/pf.anchors/cn_backend`, `/etc/pf.conf`, and executed `pfctl -vnf /etc/pf.anchors/cn_backend`. | Configuration passes syntax compilation; cross-machine tests show Mac2 authorized, Mac1 dropped. | **VERIFIED** (Config) / **HISTORICAL** (Enforcement) | Inbound access to 3001/3002 is restricted to Mac2 (`10.7.9.219`) when PF is active. | Does not prove live `/dev/pf` state table entries without root query. |
| [`backend-failover/backend-failover-evidence.md`](backend-failover/backend-failover-evidence.md) | Extension D: Backend Process Failover | Mac3 (`10.7.24.216`) & Mac2 (`10.7.9.219`) | Baseline 10 requests $\rightarrow$ stopped Backend A $\rightarrow$ 10 requests through Mac2 edge $\rightarrow$ restarted Backend A $\rightarrow$ re-convergence. | 100% of requests during Backend A outage served by Backend B (`X-Backend: B`, `HTTP 200`). Rebalanced upon restart. | **HISTORICAL** (Phase 2 Test) | Nginx passive health check and retry mechanism masks application crashes from users. | Does not prove machine-level failover; Mac3 remains a single hardware point of failure. |
| [`edge-migration/edge-migration-evidence.md`](edge-migration/edge-migration-evidence.md) | Extension E: DNS-Based Edge Migration | Mac3 (`10.7.24.216`) & Mac2 (`10.7.9.219`) | Updated DNS `app.teamX.test` to `10.7.24.216`; verified standby Nginx config (`80/443`) and TLS certs via OpenSSL. | Standby Nginx syntax ok; TLS cert valid through 2028; local and cross-machine HTTP/HTTPS succeeded. | **VERIFIED** (Config/Certs) / **HISTORICAL** (Cutover Run) | Standby Nginx on Mac3 can assume traffic on standard ports 80/443 upon DNS cutover. | Sockets 80/443 are currently idle; does not support seamless rollback to Mac2 without port change. |

---

## 3. Detailed Audit by Extension

### 3.1 Backend Health Evidence (Ports 3001 & 3002)
- **File**: [`backend-health/backend-health-verification.md`](backend-health/backend-health-verification.md)
- **Current Runtime State**:
  - `Backend A (Node.js Express)`: PID `83711`, listening on `0.0.0.0:3001`
  - `Backend B (Node.js Express)`: PID `71230`, listening on `0.0.0.0:3002`
- **Verified Endpoints**:
  - `http://127.0.0.1:3001/api/status` $\rightarrow$ `HTTP 200 OK`, `X-Backend: A`, `{"backend":"A","status":"ok"}`
  - `http://127.0.0.1:3002/api/status` $\rightarrow$ `HTTP 200 OK`, `X-Backend: B`, `{"backend":"B","status":"ok"}`
  - `http://10.7.24.216:3001/api/status` $\rightarrow$ `HTTP 200 OK`, `X-Backend: A`
  - `http://10.7.24.216:3002/api/status` $\rightarrow$ `HTTP 200 OK`, `X-Backend: B`
- **Evidence Status**: **VERIFIED**

---

### 3.2 Extension C: Packet Filter (PF) Firewall
- **File**: [`pf-firewall/pf-firewall-evidence.md`](pf-firewall/pf-firewall-evidence.md)
- **Anchor File**: `/etc/pf.anchors/cn_backend`
- **Main Config Inclusion**: `/etc/pf.conf` (`anchor "cn_backend"` / `load anchor "cn_backend" from "/etc/pf.anchors/cn_backend"`)
- **Syntax Check**: `pfctl -vnf /etc/pf.anchors/cn_backend` compiled without error.
- **Traffic Isolation Rules**:
  ```pf
  pass in quick on en0 inet proto tcp from 10.7.9.219 to 10.7.24.216 port { 3001, 3002 } flags S/SA keep state
  block in quick on en0 inet proto tcp from any to 10.7.24.216 port { 3001, 3002 }
  ```
- **Observed Behavior**:
  - Authorized connection (Mac2 `10.7.9.219` $\rightarrow$ `10.7.24.216:3001/3002`): Connected immediately with `HTTP 200 OK`.
  - Unauthorized connection (Mac1 `10.7.19.129` $\rightarrow$ `10.7.24.216:3001/3002`): Packet dropped silently, connection timed out.
- **Evidence Status**: **VERIFIED** (Configuration & Syntax) / **HISTORICAL** (Traffic Enforcement)

---

### 3.3 Extension D: Backend Process Failover
- **File**: [`backend-failover/backend-failover-evidence.md`](backend-failover/backend-failover-evidence.md)
- **Demonstration Architecture**: Primary edge on Mac2 load balancing to Mac3 backends.
- **Failover Cycle**:
  1. Baseline: 10 requests alternating 50/50 (`A` $\rightarrow$ `B` $\rightarrow$ `A` $\rightarrow$ `B` ...).
  2. Failure Injection: Backend A stopped on Mac3 (`port 3001` closed).
  3. Failover Ingress: 10 consecutive requests returned `HTTP 200 OK` from Backend B (`X-Backend: B`). Zero client errors.
  4. Restoration: Backend A restarted on port 3001.
  5. Re-convergence: Requests returned to balanced 50/50 round-robin alternation.
- **Evidence Status**: **HISTORICAL** (Preserved from Phase 2 verification run; not re-executed to preserve live processes).

---

### 3.4 Extension E: DNS-Based Edge Migration
- **File**: [`edge-migration/edge-migration-evidence.md`](edge-migration/edge-migration-evidence.md)
- **Target Hostname**: `app.teamX.test`
- **Transition**:
  - Pre-migration: `app.teamX.test` $\rightarrow$ `10.7.9.219` (Mac2 Edge on ports 8080/8443)
  - Post-migration: `app.teamX.test` $\rightarrow$ `10.7.24.216` (Mac3 Standby Edge on ports 80/443)
- **Standby Edge Capabilities**:
  - Standard HTTP port 80 and HTTPS port 443 listeners.
  - Replicated TLS certificate: `app.teamX.test.pem` with SAN `DNS:app.teamX.test`, valid through 29 Dec 2028.
  - Proxies locally over loopback to `127.0.0.1:3001` and `127.0.0.1:3002`.
- **Evidence Status**: **VERIFIED** (Configuration & Certificates) / **HISTORICAL** (Active Port Cutover Demonstration).

---

## 4. Hardware Single Point of Failure (SPOF) Assessment

> [!WARNING]
> ### Rigorous Architectural Disclosure
> Across all four evidence domains, the underlying physical topology introduces a critical vulnerability:
> - **Colocation Vulnerability**: In Phase 2, **Mac3 (`10.7.24.216`)** hosts:
>   1. Backend Application A (`port 3001`)
>   2. Backend Application B (`port 3002`)
>   3. Backup DNS Resolver (`port 53`)
>   4. Standby Nginx Edge Gateway (`ports 80 & 443`)
>   5. PF Firewall for Backend Port Isolation
> - **Failure Domain Coupling**: There is **no physical hardware redundancy**. While Extension D demonstrates process-level resilience against an individual Node.js crash, a hardware failure, power loss, or operating system crash of Mac3 takes down both application instances, the secondary DNS server, and the standby ingress proxy all at once.
> - **Academic Integrity**: This architecture demonstrates **microservice process failover and multi-tier network security**, but must **never be claimed as independent hardware high availability**.
