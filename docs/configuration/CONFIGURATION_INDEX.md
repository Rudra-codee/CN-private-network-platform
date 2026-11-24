# Configuration File Index & Asset Governance

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** Master Index of Configuration Files, Target Hosts, Purposes, and Verification Status  
**Target Path:** `docs/configuration/CONFIGURATION_INDEX.md`  
**Classification:** Operational Governance & Configuration Management  
**Author:** Senior Network Security & TLS Documentation Engineer  

---

## 1. Master Configuration Index

This index enumerates every configuration file, deployment manifest, daemon configuration, and cryptographic asset across the Private Network Service Platform. It details the host machine, functional purpose, repository path, and verified runtime status, distinguishing live-tested configurations from templates, examples, and missing repository assets.

| Asset Identifier / File Path | Target Host Node | Active Network IP | Functional Purpose & Scope | Governance / Verification Status | Cross-Reference Link |
|---|---|---|---|---|---|
| [`configs/dns/dnsmasq.conf`](file:///Users/kaustubhhiwanj/CN-private-network-platform/configs/dns/dnsmasq.conf) | **Mac 1** (Primary DNS) | `10.7.19.129` (Phase 2)<br/>*`10.7.17.222` (Phase 1)* | Primary authoritative DNS configuration for `.teamX.test` domains; upstream forwarding to `10.7.0.1`; RFC 1918 PTR filtering (`bogus-priv`); unqualified query filtering (`domain-needed`). | **Verified Phase 1 Baseline**<br/>*(Outdated in repository for Phase 2: retains Phase 1 IP `10.7.17.222`, resolves to `10.7.9.11`, lacks `local-ttl=30` and `ttl-test.teamX.test`)* | [02_DNS_Architecture.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/docs/architecture/sections/02_DNS_Architecture.md) |
| [`configs/nginx/nginx.conf`](file:///Users/kaustubhhiwanj/CN-private-network-platform/configs/nginx/nginx.conf) | **Mac 2** (Primary Edge) | `10.7.9.219` (Phase 2)<br/>*`10.7.9.11` (Phase 1)* | Primary edge reverse proxy and TLS terminator; listens on `8080/tcp` (HTTP) and `8443/tcp` (HTTPS); round-robin upstream pool; proxy caching (`/tmp/nginx_cache`). | **Verified Phase 1 Baseline**<br/>*(Outdated in repository for Phase 2: upstream pool lists `10.7.13.5:3001` and `10.7.14.32:3002` instead of Phase 2 consolidated backends on Mac 3 at `10.7.24.216`)* | [03_HTTP_TLS_Nginx_and_Backends.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/docs/architecture/sections/03_HTTP_TLS_Nginx_and_Backends.md) |
| [`configs/tls/README.md`](file:///Users/kaustubhhiwanj/CN-private-network-platform/configs/tls/README.md) | **Mac 2** & All Clients | Cluster-wide | Instructions for `mkcert` root CA export, certificate pathing (`/opt/homebrew/etc/nginx/certs/`), and `.gitignore` private key exclusion policy. | **Verified Documentation** | [tls-certificate.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/evidence/05-tls/tls-certificate.md) |
| [`backend-a/server.js`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-a/server.js) | **Mac 3** (Backend A) | `10.7.24.216` | Express.js microservice listening on `0.0.0.0:3001`; returns JSON `{"backend":"A","status":"ok"}` and response header `X-Backend: A`. | **Verified Active Runtime Code** | [backend-a-verification.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/evidence/03-backends/backend-a-verification.md) |
| [`backend-b/server.js`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/server.js) | **Mac 3** (Backend B)<br/>*(Consolidated)* | `10.7.24.216` | Express.js microservice listening on `0.0.0.0:3002`; returns JSON `{"backend":"B","status":"ok"}` and response header `X-Backend: B`. | **Verified Active Runtime Code** | [backend-b-verification.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/evidence/03-backends/backend-b-verification.md) |
| `configs/dns/dnsmasq-backup.conf` *(Virtual / Runtime)* | **Mac 3** (Backup DNS) | `10.7.24.216` | Secondary authoritative resolver configuration for Extension A failover and Extension B `local-ttl=30`. | **Runtime-Only / Missing from Repo**<br/>*(Configured interactively on Mac 3; verified during primary DNS shutdown)* | [02_DNS_Architecture.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/docs/architecture/sections/02_DNS_Architecture.md#4-phase-2-extension-a-backup-resolver--resolver-selection-dynamics) |
| `configs/nginx/nginx-standby.conf` *(Virtual / Runtime)* | **Mac 3** (Standby Edge) | `10.7.24.216` | Standby edge reverse proxy listening on standard privileged ports `80/tcp` (HTTP) and `443/tcp` (HTTPS/TLS) for Extension E migration. | **Runtime-Only / Missing from Repo**<br/>*(Configured interactively on Mac 3; verified during edge cutover test)* | [03_HTTP_TLS_Nginx_and_Backends.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/docs/architecture/sections/03_HTTP_TLS_Nginx_and_Backends.md#9-standby-nginx-edge-architecture-mac-3) |
| `/etc/pf.anchors/teamX-backends` *(Virtual / Runtime)* | **Mac 3** (Firewall Host) | `10.7.24.216` | macOS Packet Filter isolation rules: permits `10.7.9.219 -> {3001, 3002}`; blocks/drops unauthorized incoming LAN packets. | **Runtime-Only / Missing from Repo**<br/>*(Ruleset documented in Section 04 & Security README; enforced on Mac 3)* | [04_Security_Resilience_and_Troubleshooting.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/docs/architecture/sections/04_Security_Resilience_and_Troubleshooting.md#2-extension-c-packet-filter-pf-firewall--service-isolation) |
| `/opt/homebrew/etc/dnsmasq.conf` | **Mac 4** (Workstation) | Local Host | Homebrew default package template for `dnsmasq`. | **Example / Unconfigured Template**<br/>*(All lines commented out; non-operational)* | [README.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/docs/configuration/security-and-validation/README.md) |
| `/opt/homebrew/etc/nginx/certs/app.teamX.test.pem` | **Mac 2** (Primary) & **Mac 3** (Standby) | `10.7.9.219`<br/>`10.7.24.216` | X.509 Leaf Certificate for `app.teamX.test`; SAN: `DNS:app.teamX.test`; valid through Dec 30, 2028. | **Verified Local Cryptographic Asset**<br/>*(Public certificate deployed on edge nodes; excluded from repo)* | [tls-certificate.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/evidence/05-tls/tls-certificate.md) |
| `/opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem` | **Mac 2** (Primary) & **Mac 3** (Standby) | `10.7.9.219`<br/>`10.7.24.216` | RSA/ECDSA Private Key matching the leaf certificate. | **Verified Secret (Strictly Excluded)**<br/>*(Permissions `0600`; blocked by `.gitignore`; never committed)* | [README.md](file:///Users/kaustubhhiwanj/CN-private-network-platform/configs/tls/README.md#security-rules--key-protection) |

---

## 2. Infrastructure Node Status & Allocation

```
+──────────────────────────────────────────────────────────────────────────+
|                    Private LAN Subnet (10.7.0.0/19)                      |
|                                                                          |
|  [ Mac 1: 10.7.19.129 ]               [ Mac 2: 10.7.9.219 ]              |
|  - Primary dnsmasq (53/udp)           - Primary Nginx Edge Proxy         |
|  - Client test node                   - Ports: 8080 (HTTP), 8443 (HTTPS) |
|                                       - TLS Termination & Caching        |
|                                                                          |
|  [ Mac 3: 10.7.24.216 ]               [ Mac 4: Workstation ]             |
|  - Backend Server A (Port 3001)       - UNAVAILABLE AS SERVER            |
|  - Backend Server B (Port 3002)       - Documentation & Git Admin Only   |
|  - Backup dnsmasq (53/udp)            - No active infrastructure roles   |
|  - Standby Nginx (Ports 80 & 443)                                        |
|  - PF Firewall Microsegmentation                                         |
+──────────────────────────────────────────────────────────────────────────+
```

---

## 3. Discrepancy Analysis: Repository vs. Runtime

### 3.1 Primary DNS (`dnsmasq.conf`)
- **Repository Snapshot**: `configs/dns/dnsmasq.conf` was committed during Phase 1 Task B. It contains `listen-address=10.7.17.222` and directs `app.teamX.test` and `api.teamX.test` to `10.7.9.11`.
- **Phase 2 Runtime**: Due to dynamic DHCP renewals across laboratory sessions, Mac 1 operates at `10.7.19.129`. In addition, Phase 2 Extension B configured `local-ttl=30` and added `ttl-test.teamX.test` pointing to `10.7.9.219`.
- **Remediation**: The repository file must be understood as an archival baseline of Phase 1 Task B. A Phase 2 versioned variant should be generated when updating configurations.

### 3.2 Primary Nginx (`nginx.conf`)
- **Repository Snapshot**: `configs/nginx/nginx.conf` upstream block reads:
  ```nginx
  upstream backend_pool {
      server 10.7.13.5:3001;
      server 10.7.14.32:3002;
  }
  ```
- **Phase 2 Runtime**: In Phase 2, Backend A and Backend B are both hosted on Mac 3 (`10.7.24.216`). The active Nginx configuration on Mac 2 routes traffic to:
  ```nginx
  upstream backend_pool {
      server 10.7.24.216:3001 max_fails=1 fail_timeout=10s;
      server 10.7.24.216:3002 max_fails=1 fail_timeout=10s;
  }
  ```
- **Remediation**: The discrepancy is explicitly cataloged in this index. Operators running tests against Phase 2 infrastructure must verify that Mac 2's live `/opt/homebrew/etc/nginx/nginx.conf` contains the consolidated `10.7.24.216` socket targets.

### 3.3 Missing Auxiliary Configurations
- **Backup DNS & Standby Edge**: Mac 3's `dnsmasq` backup configuration and standby `nginx` configuration (listening on standard ports `80` and `443`) were deployed on Mac 3 without creating matching tracking files in `configs/`.
- **PF Anchor**: The PF firewall rules were applied directly on Mac 3 via `/etc/pf.anchors/teamX-backends` and are documented in Section 04 and the Security README.

---

## 4. Cryptographic Asset & Secret Governance

| Asset Name | Target Directory | Storage Mode | Git Inclusion Policy | Cryptographic Purpose |
|---|---|---|---|---|
| `rootCA.pem` | `/Users/kaustubhhiwanj/Library/Application Support/mkcert/` | Local Filesystem | Permitted (Public CA) | Root CA certificate distributed to client trust stores. |
| `rootCA-key.pem` | `/Users/kaustubhhiwanj/Library/Application Support/mkcert/` | Local Filesystem | **FORBIDDEN (`.gitignore`)** | Root CA private key; never distributed or committed. |
| `app.teamX.test.pem` | `/opt/homebrew/etc/nginx/certs/` | Edge Nodes | Permitted (Public Leaf) | Server leaf certificate presented during TLS handshake. |
| `app.teamX.test-key.pem` | `/opt/homebrew/etc/nginx/certs/` | Edge Nodes | **FORBIDDEN (`.gitignore`)** | Server private key; permissions `0600`; strictly local. |
