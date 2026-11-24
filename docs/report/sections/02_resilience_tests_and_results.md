# Section 02: Phase 2 Resilience Tests and Technical Results

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** Technical Report on Phase 2 Resilience Extensions (Extensions A–E)  
**Target Path:** `docs/report/sections/02_resilience_tests_and_results.md`  
**Author:** Kaustubh Hiwanj (Senior Computer Networks Engineer & Technical Report Writer)  
**Classification:** Formal Technical Evaluation Report  

---

## 1. Executive Summary & Experimental Infrastructure

Phase 2 of the **Private Network Service Platform** extends the foundational Phase 1 architecture by evaluating network resilience, bounded name-resolution caching, Layer 4 microsegmentation, application process failover, and DNS-driven service migration.

### 1.1 Active Phase 2 Infrastructure Topology

All Phase 2 resilience experiments were conducted across three active macOS workstations on the `10.7.0.0/19` private Wi-Fi subnet (`255.255.224.0`, gateway `10.7.0.1`):

| Node | Phase 2 IPv4 | Active Infrastructure Roles | Listening Sockets |
|---|---|---|---|
| **Mac 1** | `10.7.19.129` | Primary DNS Resolver (`dnsmasq`) & Test Client | `53/udp`, `53/tcp` |
| **Mac 2** | `10.7.9.219` | Primary Nginx Edge Reverse Proxy, Load Balancer, TLS Terminator & Cache | `8080/tcp` (HTTP), `8443/tcp` (HTTPS) |
| **Mac 3** | `10.7.24.216` | Backend A (`node`), Backend B (`node`), Backup DNS (`dnsmasq`), Standby Nginx, PF Firewall | `3001/tcp`, `3002/tcp`, `53/udp`, `53/tcp`, `80/tcp`, `443/tcp` |
| **Mac 4** | *N/A* | **Unavailable as a project server** — Documentation workstation only | *None* |

> [!IMPORTANT]
> **Consolidated Backend Architecture:**  
> Because Mac 4 is unavailable as a project server, both Backend A (`3001`) and Backend B (`3002`) are co-located on **Mac 3 (`10.7.24.216`)**. Throughout this report, all resilience evaluations strictly distinguish between *process-level redundancy* and *independent hardware-level high availability*.

---

## 2. Extension A — Backup DNS Resolver & Failover Analysis

### 2.1 Configuration & Architecture

To eliminate the single point of failure present in Phase 1's single-resolver DNS design, a secondary `dnsmasq` instance was deployed on **Mac 3 (`10.7.24.216`)** alongside the primary resolver on **Mac 1 (`10.7.19.129`)**:

- **Primary DNS (Mac 1)**: Configured in `/opt/homebrew/etc/dnsmasq.conf` (documented in [`docs/configuration/mac1-primary-dns/README.md`](../../configuration/mac1-primary-dns/README.md)), binding to `127.0.0.1,10.7.19.129` on port `53`.
- **Backup DNS (Mac 3)**: Configured in `/opt/homebrew/etc/dnsmasq.conf` (archived in [`docs/configuration/mac3-backup-dns/dnsmasq.conf`](../../configuration/mac3-backup-dns/dnsmasq.conf)), binding to `127.0.0.1,10.7.24.216` on port `53`.
- **Zone Parity**: Both resolvers serve identical authoritative `address=` mappings for `app.teamX.test`, `api.teamX.test`, and `ttl-test.teamX.test`, with `local-ttl=30` and external forwarding to `8.8.8.8` / `1.1.1.1`.

### 2.2 Primary DNS Outage Test Procedure & Observations

1. **Outage Simulation**: The primary `dnsmasq` daemon on Mac 1 (`10.7.19.129`) was stopped (`sudo brew services stop dnsmasq`).
2. **Client Resolution Verification**: Clients configured with dual resolvers (`10.7.19.129` and `10.7.24.216`) or querying the backup resolver directly (`dig @10.7.24.216 app.teamX.test`) were tested.
3. **Observed Behavior**: While Mac 1's port `53` was unresponsive, direct queries to Mac 3 (`10.7.24.216#53`) returned `status: NOERROR` with the configured A records (`app.teamX.test` $\rightarrow$ `10.7.24.216`, `api.teamX.test` $\rightarrow$ `10.7.9.219`), preserving name resolution for the `*.teamX.test` zone.

> [!NOTE]
> **Evidence Audit Finding**:  
> The backup `dnsmasq` configuration is verified in [`docs/configuration/mac3-backup-dns/dnsmasq.conf`](../../configuration/mac3-backup-dns/dnsmasq.conf) and [`docs/configuration/mac3-backup-dns/README.md`](../../configuration/mac3-backup-dns/README.md). However, raw Phase 2 `dig` output logs from the primary-outage test are not archived as standalone files under `evidence/02-dns/` (which currently holds only Phase 1 logs for `10.7.17.222`). Accordingly, the outage test log is classified as **INCOMPLETE** in the evidence archive.

### 2.3 Technical Analysis: Resolver Ordering & Failover Limits

- **Availability Benefit**: Deploying a second authoritative `dnsmasq` instance on Mac 3 prevents total name-resolution failure if Mac 1's `dnsmasq` daemon crashes or Mac 1 leaves the network.
- **Non-Deterministic macOS Resolver Behavior**: Operating system stub resolvers—particularly macOS `mDNSResponder`—do **not** guarantee strict sequential primary-then-secondary query ordering. Instead, `mDNSResponder` tracks per-resolver Round-Trip Time (RTT) metrics, may issue parallel queries, or dynamically deprioritize slower resolvers.
- **Claim Boundary**: Universal automatic failover with fixed deterministic timeout cannot be claimed without synchronized client-side packet captures (`tcpdump`) proving query sequence and failover latency across all client OSes.

---

## 3. Extension B — DNS TTL Configuration & Controlled Record Changes

### 3.1 Configuration & Observations

In Phase 1, `dnsmasq` served local `address=` records with a default TTL of `0` seconds (observed in [`evidence/05-tls/mac1-client-verification.md`](../../../evidence/05-tls/mac1-client-verification.md#L53)). In Phase 2, both DNS servers were configured with:

```ini
local-ttl=30
```

- **Verified Configuration**: Confirmed in both [`docs/configuration/mac1-primary-dns/README.md`](../../configuration/mac1-primary-dns/README.md#L100) and [`docs/configuration/mac3-backup-dns/dnsmasq.conf`](../../configuration/mac3-backup-dns/dnsmasq.conf#L21).
- **Dedicated Test Record**: `address=/ttl-test.teamX.test/10.7.9.219` was introduced to demonstrate controlled record updates without disrupting `app.teamX.test` or `api.teamX.test`.
- **Direct DNS Observations**: Direct `dig` queries against the authoritative resolvers returned `30` in the Answer Section TTL field (`ttl-test.teamX.test. 30 IN A 10.7.9.219`). Following a controlled edit to `dnsmasq.conf` and daemon reload (`SIGHUP` / `brew services restart dnsmasq`), subsequent `dig` queries returned the updated IP address with `TTL=30`.

### 3.2 Technical Analysis: Wire TTL vs. Client-Side Caching

| Concept | Definition & Scope | Verified in Phase 2? |
|---|---|---|
| **Authoritative Response TTL (Wire TTL)** | The 32-bit unsigned integer (RFC 1035 / RFC 2181) in the DNS Answer Section (`30` seconds) advising downstream caches how long the Resource Record (RR) remains valid. | **Configured & Documented** (`local-ttl=30` in both configs) |
| **Client-Side Resolver Cache** | Internal caching maintained by the OS stub resolver (`mDNSResponder`), browser DNS caches, or application runtime socket pools. | **Not Conclusively Demonstrated** |

- **Why `TTL=30` Does Not Guarantee Exact 30-Second Refresh**:
  1. `dig` opens raw UDP sockets directly to port `53`, completely bypassing macOS's `mDNSResponder` cache. Therefore, `dig` outputs verify the **server's wire TTL**, not **client-side cache retention**.
  2. Client operating systems, browsers, and HTTP libraries (e.g., connection pooling / keep-alive) may enforce minimum cache floors, ignore low TTLs, or hold resolved IPs in open sockets beyond 30 seconds.
  3. Because no `dscacheutil` or `mDNSResponder` zero-egress cache-hit logs were archived in `evidence/`, client-side cache retention cannot be claimed as conclusively demonstrated.

---

## 4. Extension C — PF Firewall Isolation on Mac 3

### 4.1 Intended Firewall Ruleset

Because Backend A (`3001`) and Backend B (`3002`) bind to `0.0.0.0` (required for cross-machine proxy access from Mac 2), they expose unauthenticated HTTP endpoints on the LAN. To enforce Layer 4 microsegmentation on **Mac 3 (`10.7.24.216`)**, macOS Packet Filter (`pf`) rules were designed:

```pf
pass in quick on en0 inet proto tcp from 10.7.9.219 to 10.7.24.216 port { 3001, 3002 } flags S/SA keep state
block in quick on en0 inet proto tcp from any to 10.7.24.216 port { 3001, 3002 }
```

### 4.2 Rule Mechanics & Semantic Breakdown

1. **Authorized Source (`from 10.7.9.219`)**: Only Mac 2—the primary Nginx reverse proxy—is permitted to initiate TCP connections to the backend ports.
2. **Protected Destination & Ports (`to 10.7.24.216 port { 3001, 3002 }`)**: Protects Mac 3's LAN interface (`en0`) sockets for Backend A and Backend B.
3. **Allow Rule (`pass in quick ... flags S/SA keep state`)**:
   - `flags S/SA`: Matches only initial TCP `SYN` packets (`SYN` set, `ACK` unset) to prevent mid-stream packet injection.
   - `keep state`: Inserts an active session entry into PF's state table, allowing subsequent `ACK`, data, and `FIN` packets in the established flow to pass without re-evaluating the ruleset.
4. **Block Rule (`block in quick ... from any`)**: Intercepts and drops all incoming TCP `SYN` segments to ports `3001` and `3002` originating from any source IP other than `10.7.9.219`.
5. **Rule Ordering & `quick` Keyword**: PF normally evaluates rules top-to-bottom using "last match wins" semantics. The `quick` keyword short-circuits evaluation: **the first matching rule immediately terminates processing and executes its action**. Consequently, the `pass ... quick` rule for `10.7.9.219` must precede the `block ... quick` catch-all rule; reversing their order would block Mac 2 as well.

### 4.3 Verification & Enforcement Audit

- **Previously Demonstrated Behavior**:
  - Syntax validation (`sudo pfctl -vnf ...`) verified rule parsing.
  - Authorized requests from **Mac 2 (`10.7.9.219`)** to `10.7.24.216:3001` and `3002` succeeded.
  - Unauthorized connection attempts from **Mac 1 (`10.7.19.129`)** timed out at the TCP handshake layer.
  - PF packet/byte counters (`pfctl -sr -v` / anchor inspection) were checked to confirm rule matching.
- **Repository Evidence Gap**:
  - Neither an exported PF anchor file under `configs/` nor raw `pfctl` counter outputs under `evidence/08-failures/` are committed in the repository (`evidence/08-failures/` contains only `.gitkeep`).
  - **Distinction**: Having documented rules confirms *intended configuration*, whereas active enforcement is proven only by runtime `pfctl` output on Mac 3. Because raw `pfctl` logs are absent from the repository, repository-backed PF evidence is marked **INCOMPLETE / MISSING**.

---

## 5. Extension D — Backend Process Failover & Recovery

### 5.1 Demonstrated Test Sequence & Results

Extension D evaluated Nginx's upstream fault tolerance when one of the two co-located backend processes on Mac 3 fails:

1. **Baseline (Healthy Pool)**:
   - 10 sequential requests issued through Nginx on Mac 2.
   - **Observed Result**: 10/10 returned `HTTP 200 OK`, alternating between Backend A (`X-Backend: A`) and Backend B (`X-Backend: B`). *(Consistent with Phase 1 round-robin logs in [`evidence/04-nginx/load-balancing.md`](../../../evidence/04-nginx/load-balancing.md) and [`evidence/05-tls/nginx-tls-verification.md`](../../../evidence/05-tls/nginx-tls-verification.md)).*
2. **Failure Injection (Backend A Stopped)**:
   - Backend A (`port 3001`) was stopped cleanly (`lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -TERM`), documented in [`docs/backend/DEPLOYMENT_AND_EXECUTION.md`](../../backend/DEPLOYMENT_AND_EXECUTION.md#L398-L414).
   - 10 sequential requests were issued through Nginx.
   - **Observed Result**: 10/10 returned `HTTP 200 OK`, served exclusively by **Backend B (`X-Backend: B`)** with zero client-facing errors.
3. **Recovery (Backend A Restarted)**:
   - Backend A was restarted on Mac 3 (`port 3001`).
   - Both `3001` and `3002` were confirmed in `LISTEN` state via `lsof -nP -iTCP:3001,3002 -sTCP:LISTEN` ([`DEPLOYMENT_AND_EXECUTION.md`](../../backend/DEPLOYMENT_AND_EXECUTION.md#L302-L310)).
   - Subsequent requests through Nginx returned responses from **both Backend A and Backend B**.

### 5.2 Technical Mechanism & Critical Limitation

- **Failover Mechanism**: When Backend A stops, Mac 3's kernel immediately responds to Nginx's TCP `SYN` on port `3001` with a TCP `RST` (`ECONNREFUSED`). Nginx's `proxy_next_upstream` directive intercepts this connection error before sending headers to the client, retries the request against the next pool member (`10.7.24.216:3002`), and marks `3001` temporarily unavailable for `fail_timeout` (10s default). Once `3001` restarts and `fail_timeout` expires, Nginx probes `3001` and restores round-robin distribution.
- **What This Proves**: Nginx correctly isolates single-process failures at Layer 7 without dropping client HTTP requests.

> [!CAUTION]
> **Critical Architectural Limitation — No Hardware-Level High Availability:**  
> Both Backend A (`3001`) and Backend B (`3002`) run on the **same physical machine (Mac 3 — `10.7.24.216`)**. Mac 3 is a **Single Point of Failure (SPOF)** for both backend instances, Backup DNS, and Standby Nginx. A hardware crash, power loss, or Wi-Fi disconnect on Mac 3 will take down **both** backends simultaneously. This must **never** be described as independent hardware-level high availability.

---

## 6. Extension E — DNS-Based Edge Migration

### 6.1 Migration Architecture & Certificate Deployment

Extension E tested shifting the primary application entry point (`app.teamX.test`) from **Mac 2 (`10.7.9.219`)** to **Mac 3 (`10.7.24.216`)**:

- **DNS Cutover**: `address=/app.teamX.test/10.7.9.219` was updated to `address=/app.teamX.test/10.7.24.216` on Mac 1 and Mac 3 (`local-ttl=30`).
- **Mac 3 Standby Nginx**: Configured in [`docs/configuration/mac3-standby-nginx/standby.conf`](../../configuration/mac3-standby-nginx/standby.conf) to listen on standard privileged ports **`80/tcp` (HTTP)** and **`443/tcp` (HTTPS)**, proxying locally over loopback (`127.0.0.1:3001`, `127.0.0.1:3002`) with caching enabled (`/opt/homebrew/var/cache/nginx-standby`).
- **Certificate Transfer**: The `mkcert` leaf certificate (`app.teamX.test.pem`, SAN `DNS:app.teamX.test`) and private key (`app.teamX.test-key.pem`) were transferred from Mac 2 to Mac 3 under `/opt/homebrew/etc/nginx/standby-certs/` (`0644` for `.pem`, `0600` for `-key.pem`). Private key material is strictly excluded from all documentation and evidence.

### 6.2 Observed Validation Results

As documented in [`docs/configuration/mac3-standby-nginx/README.md`](../../configuration/mac3-standby-nginx/README.md) and Phase 2 verification records:
1. **Configuration Validation**: `sudo nginx -t -c /opt/homebrew/etc/nginx/standby.conf` passed (`syntax is ok` / `test is successful`).
2. **Socket Binding**: Mac 3 confirmed listening on ports `80` and `443`.
3. **Local Loopback & Cross-Node HTTP/HTTPS**: Local requests on Mac 3 and Mac 2-to-Mac 3 HTTP/HTTPS requests returned `HTTP 200 OK`.
4. **Hostname-Based Access**: Hostname-based HTTP (`http://app.teamX.test/api/status`) returned `200 OK`, and hostname-based HTTPS without `-k` (`https://app.teamX.test/api/status`) returned `200 OK` on Mac 2 (proving SAN `DNS:app.teamX.test` remains valid after IP migration because TLS binds to the hostname, not the IP).

### 6.3 Technical Analysis & Critical Port Limitation

- **Why Standby Nginx & Certs Are Needed**: Changing DNS only alters the Layer 3 destination IP. Without Standby Nginx listening on Mac 3 with the matching `app.teamX.test` TLS certificate and private key, clients redirected by DNS would receive `ECONNREFUSED` or TLS errors.
- **Critical Port Limitation (80/443 vs. 8080/8443)**:
  - Mac 2's original Nginx listens exclusively on **non-standard ports `8080` and `8443`**.
  - Mac 3's standby Nginx listens exclusively on **standard ports `80` and `443`**.
  - **Operational Consequence**: DNS operates strictly on hostname-to-IP translation and **cannot remap TCP ports**. Clients hardcoded to `:8443` fail against Mac 3 (`:443`), and conversely, **changing DNS back to Mac 2 (`10.7.9.219`) does not by itself restore standard-port (`80`/`443`) service**, because Mac 2 does not listen on ports `80` or `443`.
- **Zero-Downtime Claim Boundary**: Seamless zero-downtime migration is **not** claimed, because port disparity (`8443` vs `443`) and staggered client DNS cache expiration require explicit dual-edge coexistence and port-aware client URLs.

---

## 7. Phase 2 Resilience Results Summary Table

| Extension | Test | Observed Result | Evidence Status | Limitation |
|---|---|---|---|---|
| **Ext A: Backup DNS** | Primary `dnsmasq` stopped on Mac 1 (`10.7.19.129`); queries directed to Mac 3 (`10.7.24.216`) | Backup `dnsmasq` config verified; Mac 3 resolved `*.teamX.test` (`NOERROR`) | **INCOMPLETE** *(Config verified; raw Phase 2 outage `dig` log missing from `evidence/02-dns/`)* | macOS `mDNSResponder` does not guarantee strict primary-then-secondary query ordering |
| **Ext B: DNS TTL** | `local-ttl=30` configured; controlled change tested on `ttl-test.teamX.test` | Both DNS configs define `local-ttl=30`; authoritative `dig` responses reflect TTL `30` and updated IP | **INCOMPLETE** *(Configs verified; raw Phase 2 `dig` logs missing from `evidence/02-dns/`)* | `dig` bypasses OS stub caches; client-side cache retention was not conclusively demonstrated |
| **Ext C: PF Firewall** | Allow `10.7.9.219` $\rightarrow$ `3001,3002`; block `any` $\rightarrow$ `3001,3002` on Mac 3 | Syntax validated; Mac 2 connected to backends; Mac 1 timed out; PF counters checked | **INCOMPLETE** *(Intended rules documented; no exported anchor or raw `pfctl` counter log in `evidence/08-failures/`)* | Rules exist on Mac 3 runtime; repository lacks committed `.conf` and raw counter logs |
| **Ext D: Backend Failover** | Baseline 10 reqs $\rightarrow$ stop Backend A $\rightarrow$ 10 reqs $\rightarrow$ restart Backend A | Baseline 10/10 alternating; Failure 10/10 `200 OK` via `X-Backend: B`; Recovery restored A & B | **VERIFIED** *(Baseline in `evidence/04-nginx/`; protocol & recovery `lsof`/`curl` in `DEPLOYMENT_AND_EXECUTION.md`)* | Both backends run on Mac 3 (`10.7.24.216`); process redundancy only, **not** hardware HA |
| **Ext E: Edge Migration** | `app.teamX.test` migrated from Mac 2 (`10.7.9.219`) to Mac 3 (`10.7.24.216:80/443`) | `standby.conf` tested OK; Mac 3 bound `80/443`; HTTP & trusted HTTPS (no `-k`) returned `200 OK` | **INCOMPLETE** *(Config in `docs/configuration/mac3-standby-nginx/`; raw Phase 2 `curl` logs missing from `evidence/`)* | Port disparity (`80/443` on Mac 3 vs `8080/8443` on Mac 2); reverting DNS does not restore port `80/443` on Mac 2 |

---

## 8. Evidence & Configuration Reference Index

| Category | File Path (Relative) | Classification | Relevance |
|---|---|---|---|
| **Primary DNS Config** | [`docs/configuration/mac1-primary-dns/README.md`](../../configuration/mac1-primary-dns/README.md) | **VERIFIED** | Documents Mac 1 Phase 2 `dnsmasq.conf` (`10.7.19.129`, `local-ttl=30`, `app.teamX.test` $\rightarrow$ `10.7.24.216`) |
| **Backup DNS Config** | [`docs/configuration/mac3-backup-dns/dnsmasq.conf`](../../configuration/mac3-backup-dns/dnsmasq.conf) | **VERIFIED** | Active Phase 2 backup `dnsmasq` configuration on Mac 3 (`10.7.24.216`, `local-ttl=30`) |
| **Backup DNS Guide** | [`docs/configuration/mac3-backup-dns/README.md`](../../configuration/mac3-backup-dns/README.md) | **VERIFIED** | Operational procedures for Extension A backup resolver |
| **Standby Nginx Config** | [`docs/configuration/mac3-standby-nginx/standby.conf`](../../configuration/mac3-standby-nginx/standby.conf) | **VERIFIED** | Mac 3 standby Nginx (`80`/`443`, loopback upstreams, `/opt/homebrew/etc/nginx/standby-certs/`) |
| **Standby Nginx Guide** | [`docs/configuration/mac3-standby-nginx/README.md`](../../configuration/mac3-standby-nginx/README.md) | **VERIFIED** | Certificate transfer, `nginx -t`, and Extension E verification steps |
| **Backend Execution & Failover** | [`docs/backend/DEPLOYMENT_AND_EXECUTION.md`](../../backend/DEPLOYMENT_AND_EXECUTION.md) | **VERIFIED** | Mac 3 `lsof` (`3001`/`3002`), `curl` outputs, and Extension D failover sequence |
| **Configuration Index** | [`docs/configuration/CONFIGURATION_INDEX.md`](../../configuration/CONFIGURATION_INDEX.md) | **VERIFIED** | Master inventory of configuration files and Phase 1 vs. Phase 2 discrepancies |
| **Nginx Evidence Index** | [`evidence/nginx-http-tls/README.md`](../../../evidence/nginx-http-tls/README.md) | **VERIFIED** | Organized index for Nginx, HTTP, TLS, Load Balancing, and Caching evidence |
| **Load Balancing Log** | [`evidence/04-nginx/load-balancing.md`](../../../evidence/04-nginx/load-balancing.md) | **HISTORICAL** | Phase 1 10-request round-robin alternation baseline (Mac 3 + Mac 4 IPs) |
| **HTTPS Load Balancing Log** | [`evidence/05-tls/nginx-tls-verification.md`](../../../evidence/05-tls/nginx-tls-verification.md) | **HISTORICAL** | Phase 1 10-request HTTPS round-robin baseline on port `8443` |
| **Phase 1 DNS Logs** | [`evidence/02-dns/dns-server-verification.md`](../../../evidence/02-dns/dns-server-verification.md) | **HISTORICAL** | Phase 1 `dig` logs for Mac 1 (`10.7.17.222`) |
| **Phase 1 Client TLS/DNS Log** | [`evidence/05-tls/mac1-client-verification.md`](../../../evidence/05-tls/mac1-client-verification.md) | **HISTORICAL** | Shows Phase 1 `TTL=0` before `local-ttl=30` was introduced in Phase 2 |
| **Failures Evidence Folder** | [`evidence/08-failures/.gitkeep`](../../../evidence/08-failures/.gitkeep) | **MISSING** | Contains only `.gitkeep`; raw Phase 2 Extension A/B/C/E terminal logs not yet archived here |
