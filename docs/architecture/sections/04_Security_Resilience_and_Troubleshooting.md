# Section 04: Security, Resilience & Troubleshooting Architecture

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** Security Posture, Firewall Controls, Failover Resilience, and Troubleshooting Protocols  
**Target Path:** `docs/architecture/sections/04_Security_Resilience_and_Troubleshooting.md`  
**Classification:** Core System Architecture  
**Author:** Senior Network Security & Reliability Engineer  

---

## 1. Executive Summary & Machine Roles

This document defines the security architecture, resilience characteristics, failure domain boundaries, and systematic troubleshooting methodologies for the Private Network Service Platform across Phase 1 and Phase 2.

### 1.1 Infrastructure Inventory (Phase 2 Reality)

The operational cluster comprises three active infrastructure nodes operating on the `10.7.0.0/19` private subnet:

| Host Identifier | Current IPv4 Address | Infrastructure Roles & Active Daemons | Exposed / Listening Ports | Role in Redundancy |
|---|---|---|---|---|
| **Mac1** | `10.7.19.129` | Primary DNS Resolver (`dnsmasq` v2.93) | `53/udp`, `53/tcp` | Primary Authoritative Resolver |
| **Mac2** | `10.7.9.219` | Primary Edge Reverse Proxy & Load Balancer (`nginx`) | `8080/tcp` (HTTP), `8443/tcp` (HTTPS) | Primary Cluster Ingress |
| **Mac3** | `10.7.24.216` | Backend A (`node` / port 3001)<br/>Backend B (`node` / port 3002)<br/>Backup DNS Resolver (`dnsmasq`)<br/>Standby Edge Proxy (`nginx`) | `3001/tcp`<br/>`3002/tcp`<br/>`53/udp`, `53/tcp`<br/>`80/tcp`, `443/tcp` | Consolidated Workload & Standby Edge Node |
| **Mac4** | *N/A (Host Station)* | **UNAVAILABLE AS PROJECT SERVER**<br/>Workstation reserved strictly for documentation | *None* | *None (Non-infrastructure)* |

> [!IMPORTANT]
> **Operational Status of Mac4:**  
> In Phase 1 initial designs, Mac4 was designated to host Backend Server B. In Phase 2, **Mac4 is completely unavailable as an active project server**. The physical machine is used exclusively as an administrative workstation for repository management and documentation. Backend B was colocated onto Mac3 (`10.7.24.216:3002`). At no point should Mac4 be represented as an active infrastructure machine or operational server.

---

## 2. Extension C: Packet Filter (PF) Firewall & Service Isolation

To enforce defense-in-depth and network microsegmentation on the private LAN, macOS Packet Filter (`pf`) is utilized on Mac3 to restrict direct access to backend application services.

### 2.1 Threat Model & Boundary Objectives

1. **Bypass Prevention**: Without firewall rules, raw Node.js backend processes listening on `0.0.0.0:3001` and `0.0.0.0:3002` are exposed to every host on the `10.7.0.0/19` subnet. Any LAN participant could send unencrypted, unauthenticated HTTP requests directly to backend services, completely bypassing:
   - Edge TLS termination (port 8443).
   - Nginx caching policies (`proxy_cache`).
   - Round-robin load balancing distribution.
   - Centralized access logging and security headers.
2. **Access Isolation**: Backend services on Mac3 must only process TCP traffic originating from the authorized primary Nginx edge reverse proxy on Mac2 (`10.7.9.219`).
3. **Default Deny for Application Ports**: All unauthorized packets directed to ports 3001 and 3002 from other hosts (including Mac1, unauthorized clients, or external LAN nodes) must be intercepted and dropped at Layer 4.

```
                     Unrestricted LAN (10.7.0.0/19)
                                   │
         ┌─────────────────────────┴────────────────────────┐
         │                                                  │
         ▼                                                  ▼
┌──────────────────┐                              ┌──────────────────┐
│  Mac1 (Client)   │                              │  Mac2 (Edge)     │
│   10.7.19.129    │                              │   10.7.9.219     │
└────────┬─────────┘                              └────────┬─────────┘
         │                                                 │
         │ Direct TCP:3001/3002                            │ Proxied TCP:3001/3002
         │ (UNAUTHORIZED)                                  │ (AUTHORIZED)
         ▼                                                 ▼
   xxxxxxxxxxxxx                                    ═════════════════
   x PF: BLOCK x                                    ║ PF: PASS IN   ║
   xxxxxxxxxxxxx                                    ═════════════════
         │                                                 │
         └─────────────────┬───────────────────────────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │  Mac3 (PF Active)│
                  │   10.7.24.216    │
                  │  Ports 3001/3002 │
                  └──────────────────┘
```

### 2.2 PF Configuration & Ruleset Specification

macOS manages packet filtering via `/dev/pf` and `/sbin/pfctl`. The intended ruleset isolates backend ports using stateful packet inspection:

```pf
# /etc/pf.anchors/teamX-backends
# Service Isolation Rules for Private Network Platform (Mac3)

# Macro definitions
edge_proxy    = "10.7.9.219"
backend_ports = "{ 3001, 3002 }"
int_if        = "en0"

# Rule 1: Allow authorized reverse proxy traffic with state tracking
pass in quick on $int_if proto tcp from $edge_proxy to any port $backend_ports keep state

# Rule 2: Block and drop all unauthorized traffic to backend application ports
block in drop quick on $int_if proto tcp from any to any port $backend_ports
```

#### Integration with `/etc/pf.conf`
The anchor is invoked within the primary macOS PF configuration:
```pf
# Anchor declaration in /etc/pf.conf
anchor "teamX-backends"
load anchor "teamX-backends" from "/etc/pf.anchors/teamX-backends"
```

Activation and verification commands on Mac3:
```bash
# Validate rule syntax without applying
sudo pfctl -vnf /etc/pf.anchors/teamX-backends

# Load and enable the anchor
sudo pfctl -a teamX-backends -f /etc/pf.anchors/teamX-backends
sudo pfctl -e

# Inspect currently active rules in the anchor
sudo pfctl -a teamX-backends -sr
```

### 2.3 Verification & Boundary Behavior

| Test Case | Source Node | Destination IP:Port | Expected Layer 4 Result | Observed Outcome | Security Interpretation |
|---|---|---|---|---|---|
| **Authorized Edge Proxy** | Mac2 (`10.7.9.219`) | `10.7.24.216:3001` | TCP SYN $\rightarrow$ SYN-ACK (`HTTP 200`) | **PASS** | Edge proxy establishes connection; state table entry created. |
| **Authorized Edge Proxy** | Mac2 (`10.7.9.219`) | `10.7.24.216:3002` | TCP SYN $\rightarrow$ SYN-ACK (`HTTP 200`) | **PASS** | Edge proxy communicates seamlessly with Backend B. |
| **Unauthorized Direct Access** | Mac1 (`10.7.19.129`) | `10.7.24.216:3001` | Packet dropped; Connection timeout | **PASS** (Blocked) | PF drops SYN packet silently; direct backend access denied. |
| **Unauthorized Direct Access** | Mac4 / Documentation | `10.7.24.216:3002` | Packet dropped; Connection timeout | **PASS** (Blocked) | Non-edge node cannot probe backend application port. |

> [!NOTE]
> On the local documentation workstation (Mac4), inspection of `/etc/pf.conf` reveals only the default Apple operating system anchors (`com.apple`). Mac3 hosts the dedicated PF isolation anchor for ports 3001 and 3002.

---

## 3. Extension D: Backend Failover Mechanics & Resilience Limitations

Extension D evaluates cluster resilience against individual backend application process failure and documents the precise scope of fault isolation.

### 3.1 Nginx Upstream Health Management

The edge proxy on Mac2 (`10.7.9.219`) load balances incoming HTTP/HTTPS traffic across Backend A and Backend B:

```nginx
upstream backend_pool {
    server 10.7.24.216:3001 max_fails=1 fail_timeout=10s;
    server 10.7.24.216:3002 max_fails=1 fail_timeout=10s;
}
```

When a client sends a request to `https://app.teamX.test:8443/api/status`:
1. Nginx selects an upstream server via round-robin.
2. If the selected backend instance is down, the connection attempt immediately encounters an error (e.g. `ECONNREFUSED` / TCP RST if the process terminated, or TCP timeout if ungracefully hung).
3. Under default `proxy_next_upstream error timeout invalid_header http_502 http_503;`, Nginx intercepts the failure before returning a response to the client, immediately forwarding the client's request to the alternate upstream server in the pool.
4. The client receives an uninterrupted `HTTP 200 OK` response with header `X-Backend: B`.

### 3.2 The Failover Lifecycle

```
[Phase 1: Balanced State]
   Client Requests ────────► Nginx (Mac2) ──┬── 50% ──► Backend A (Mac3:3001) [UP]
                                          └── 50% ──► Backend B (Mac3:3002) [UP]

[Phase 2: Process Fault Injected]
   Backend A process killed (kill -9 <PID> on Mac3). Port 3001 closed.

[Phase 3: Automatic Failover]
   Client Requests ────────► Nginx (Mac2) ───── 100% ─► Backend B (Mac3:3002) [UP]
   (Nginx marks Backend A unavailable for 10s fail_timeout window)

[Phase 4: Service Restoration & Re-convergence]
   Backend A restarted on Mac3:3001.
   After fail_timeout elapses, Nginx probes port 3001 and restores 50/50 round-robin.
```

### 3.3 Critical Architectural Limitation: Co-located Single Point of Failure (SPOF)

> [!WARNING]
> **Crucial Engineering Limitation — Hardware Colocation:**  
> In Phase 2, **both Backend A (port 3001) and Backend B (port 3002) execute on the exact same physical machine: Mac3 (`10.7.24.216`)**. Furthermore, Mac3 also runs the **Backup DNS resolver (`dnsmasq`)** and the **Standby Edge Proxy**.

This topology yields a severe architectural constraint:
- **Process-Level Redundancy Only**: The platform can survive the failure of an individual Node.js runtime process (e.g., an uncaught exception, memory leak, or deliberate crash of Backend A).
- **Zero Hardware / Node Fault Tolerance**: If Mac3 suffers a hardware crash, kernel panic, power outage, or Wi-Fi disconnection, **both Backend A and Backend B immediately fail simultaneously**.
- **Concurrent Backup DNS Loss**: The same failure takes down the secondary DNS resolver.
- **Academic & Engineering Integrity**: This architecture must **never be described as independent hardware high availability**. True high availability requires hosting Backend A and Backend B on physically separate machines with independent power and network interfaces.

---

## 4. Extension E: DNS-Based Edge Migration Architecture

Extension E implements an emergency edge migration mechanism to reroute cluster entry points from the primary edge proxy on Mac2 to the standby edge proxy on Mac3.

### 4.1 Migration Overview

| Attribute | Primary Edge (Mac2) | Standby Migrated Edge (Mac3) |
|---|---|---|
| **Host IP** | `10.7.9.219` | `10.7.24.216` |
| **HTTP Listening Port** | `8080/tcp` | `80/tcp` (Standard HTTP) |
| **HTTPS Listening Port** | `8443/tcp` | `443/tcp` (Standard HTTPS) |
| **TLS Certificates** | Local `mkcert` certificate | Replicated `mkcert` certificate & private key |
| **Target DNS Record** | `app.teamX.test` $\rightarrow$ `10.7.9.219` | `app.teamX.test` $\rightarrow$ `10.7.24.216` |

```
                                [DNS Cutover Trigger]
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │                                               │
                 ▼                                               ▼
      [T < 0: Pre-Migration]                          [T > 30s: Post-Migration]
     Primary DNS: 10.7.19.129                        Primary DNS: 10.7.19.129
   app.teamX.test -> 10.7.9.219                    app.teamX.test -> 10.7.24.216
                 │                                               │
                 ▼                                               ▼
         ┌───────────────┐                               ┌───────────────┐
         │  Mac2 Edge    │                               │  Mac3 Edge    │
         │  (10.7.9.219) │                               │ (10.7.24.216) │
         │  Ports:       │                               │ Ports:        │
         │  8080 / 8443  │                               │ 80 / 443      │
         └───────────────┘                               └───────────────┘
```

### 4.2 DNS Cutover Workflow

1. **Standby Proxy Provisioning**: Nginx on Mac3 is configured with identical upstream definitions (`127.0.0.1:3001` and `127.0.0.1:3002` locally, or over LAN) and loaded with the trusted TLS certificate for `app.teamX.test`.
2. **DNS Zone Update**: On Mac1 (`10.7.19.129`) and Mac3 (`10.7.24.216`), the authoritative record is updated in `dnsmasq`:
   ```ini
   address=/app.teamX.test/10.7.24.216
   ```
3. **Daemon Reload**: `killall -HUP dnsmasq` is executed on both resolvers to flush internal records and load the new address without dropping DNS queries.
4. **TTL Drain Window**: With `local-ttl=30`, client resolver caches drain within 30 seconds.

### 4.3 Inherent Limitations of DNS-Based Migration

While DNS-based migration avoids introducing complex Layer 3 routing protocols (such as BGP or CARP/VRRP), it introduces distinct engineering trade-offs:

1. **Port Disparity Impedance**:
   - The primary edge on Mac2 operates on unprivileged ports (`8080` and `8443`).
   - The standby edge on Mac3 was deployed on standard privileged ports (`80` and `443`).
   - **Failure Mode**: Clients, automated curl scripts, or browser bookmarks hardcoded to `https://app.teamX.test:8443` will fail to connect after DNS cutover because Mac3 is listening on port `443`, not `8443`. DNS can only rewrite hostname-to-IP mappings; **DNS cannot perform port remapping**.
2. **Propagation Latency & Stale Caches**:
   - Clients respecting the 30-second TTL will transition within 30 seconds. However, stub resolvers that ignore TTLs, browser socket pools that maintain open HTTP/2 keep-alive connections, or Java runtimes caching DNS indefinitely will continue directing traffic to the old edge IP (`10.7.9.219`).
3. **Dual-Edge Coexistence Requirement**:
   - Mac2 cannot be immediately decommissioned at cutover. It must remain operational for a minimum drain window ($2 \times \text{TTL} = 60\text{s}$) to avoid dropped in-flight requests.
4. **Colocation Contention**:
   - Migrating the edge proxy onto Mac3 means Mac3 now runs: Standby Nginx, Backend A, Backend B, and Backup DNS on a single physical host. This dramatically increases CPU, network interface, and memory resource contention.

---

## 5. Extension F: Faculty-Injected Fault Troubleshooting Methodology

Under academic evaluation guidelines, faculty will inject an unannounced configuration fault into one layer of the platform stack. The engineering team must rapidly detect, isolate, and remediate the issue using a structured, deterministic diagnostic sequence.

### 5.1 Systematic 4-Layer Diagnostic Protocol

To prevent unstructured guessing, diagnostics proceed strictly bottom-up across the functional dependency stack:

```
[Layer 1: DNS Resolution] ──► [Layer 2: TCP Transport] ──► [Layer 3: TLS Cryptography] ──► [Layer 4: Application Layer]
```

```
+────────────────────────────────────────────────────────────────────────────+
| DIAGNOSTIC FLOWCHART                                                       |
|                                                                            |
| 1. Run: dig app.teamX.test                                                 |
|    ├─ Failure (NXDOMAIN / Timeout / Bad IP) ──► [FAULT IN LAYER 1: DNS]    |
|    └─ Success (NOERROR -> 10.7.9.219 or 10.7.24.216) ──┐                   |
|                                                        │                   |
| 2. Run: nc -zv -w 3 <IP> <PORT>                        ▼                   |
|    ├─ Failure (Connection Refused / Timed Out) ─► [FAULT IN LAYER 2: TCP]  |
|    └─ Success (Connection open / SYN-ACK) ─────────────┐                   |
|                                                        │                   |
| 3. Run: openssl s_client -connect <IP>:<PORT> -sni ... ▼                   |
|    ├─ Failure (Cert expired / Self-signed / SNI) ─► [FAULT IN LAYER 3: TLS]|
|    └─ Success (Verify return code: 0 OK) ──────────────┐                   |
|                                                        │                   |
| 4. Run: curl -i https://app.teamX.test:<PORT>/status   ▼                   |
|    ├─ Failure (502 Bad Gateway / 504 Timeout) ──► [FAULT IN LAYER 4: APP]  |
|    └─ Success (HTTP 200 OK + X-Backend Header) ──► SYSTEM FULLY HEALTHY    |
+────────────────────────────────────────────────────────────────────────────+
```

---

### 5.2 Layer-by-Layer Diagnostic Matrix & Useful Commands

#### Layer 1: DNS Resolution Layer
- **Objective**: Verify that the domain resolves to the correct IP address via authorized resolvers.
- **Commands**:
  ```bash
  # Query default system stub resolver
  dig app.teamX.test

  # Explicitly query Primary DNS (Mac1)
  dig @10.7.19.129 app.teamX.test

  # Explicitly query Backup DNS (Mac3)
  dig @10.7.24.216 app.teamX.test

  # Inspect active macOS resolver configuration
  scutil --dns
  ```
- **Diagnostic Interpretation**:
  - `status: NOERROR` with expected IP: DNS resolution is functional.
  - `status: NXDOMAIN`: The record is missing or misspelled in `dnsmasq.conf`.
  - `connection timed out`: `dnsmasq` process is stopped on target DNS server, port 53 is blocked, or the IP is misconfigured.
  - Returned IP differs from expected edge: Incomplete record migration or stale host cache (`sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`).

#### Layer 2: TCP Transport Layer
- **Objective**: Verify network reachability, routing, and that the target port is actively bound and listening.
- **Commands**:
  ```bash
  # Check edge proxy HTTP/HTTPS ports (Mac2)
  nc -z -v -w 3 10.7.9.219 8080
  nc -z -v -w 3 10.7.9.219 8443

  # Check backend ports on Mac3 (from authorized host Mac2)
  nc -z -v -w 3 10.7.24.216 3001
  nc -z -v -w 3 10.7.24.216 3002

  # On target host: verify process listening state
  sudo lsof -nP -iTCP:8443 -sTCP:LISTEN
  sudo lsof -nP -iTCP:3001 -sTCP:LISTEN
  ```
- **Diagnostic Interpretation**:
  - `Connection to <IP> <PORT> port [tcp/*] succeeded!`: TCP socket is listening, ARP resolved, routing operational, firewall permits traffic.
  - `Connection refused` (TCP RST packet received): Host is reachable and firewall permits packet, but **no service is listening on that port** (e.g., Nginx or Node.js process crashed or stopped).
  - `Connection timed out` (no response): Packet dropped silently. Primary causes: **PF firewall blocking rule (`block drop`)**, host offline, or incorrect routing table entry.

#### Layer 3: TLS / Cryptographic Layer
- **Objective**: Verify that the TLS handshake completes, SNI negotiation succeeds, and the certificate chain validates against local trust anchors.
- **Commands**:
  ```bash
  # Test TLS handshake and certificate validation
  openssl s_client -connect 10.7.9.219:8443 -servername app.teamX.test -showcerts </dev/null

  # Inspect certificate details directly from file
  openssl x509 -in configs/tls/app.teamX.test.pem -text -noout | grep -E "Subject:|DNS:"
  ```
- **Diagnostic Interpretation**:
  - `Verify return code: 0 (ok)`: Certificate is valid, issued by trusted root CA, host name matches SAN, and handshake succeeded.
  - `Verify return code: 19 (self-signed certificate in certificate chain)` or `21 (unable to verify the first certificate)`: Client machine missing local root CA in Keychain (`mkcert -install`).
  - `handshake failure`: TLS protocol version mismatch (e.g., client requests TLS 1.2 but server enforces strict TLS 1.3), or cipher suite negotiation mismatch.
  - `hostname mismatch`: Client requested hostname not included in Certificate Subject Alternative Name (`SAN`).

#### Layer 4: Application Layer (HTTP / Nginx Upstream / Caching)
- **Objective**: Verify HTTP transaction semantics, reverse proxy forwarding, backend headers, and caching policies.
- **Commands**:
  ```bash
  # Verbose HTTP query to edge proxy
  curl -i -v --resolve app.teamX.test:8443:10.7.9.219 https://app.teamX.test:8443/api/status

  # Bypass cache to test fresh upstream delivery
  curl -i https://app.teamX.test:8443/api/status -H "Cache-Control: no-cache"

  # Inspect Nginx error log on edge host (Mac2)
  tail -n 50 /opt/homebrew/var/log/nginx/error.log
  ```
- **Diagnostic Interpretation**:
  - `HTTP/1.1 200 OK` with `X-Backend: A` or `X-Backend: B`: Healthy end-to-end request lifecycle.
  - `HTTP/1.1 502 Bad Gateway`: Nginx received TCP RST or immediate close when connecting to upstream backends (`10.7.24.216:3001` or `3002`). Indicates both backend processes are dead or PF firewall on Mac3 is blocking Nginx.
  - `HTTP/1.1 504 Gateway Timeout`: Nginx established connection to backend, but backend process failed to return HTTP response within `proxy_read_timeout` (60s).
  - Missing `X-Cache-Status` header: Cache configuration directive missing from `nginx.conf` or request method not cached.

---

### 5.3 Extension F Readiness & Status Audit

To maintain rigorous engineering honesty, the operational status of Extension F is categorized as follows:

| Evaluation Milestone | Current Status | Supporting Evidence / Notes | Action Required |
|---|---|---|---|
| **Diagnostic Scripting & Command Runbook** | **COMPLETE** | Documented above with full 4-layer command syntax and status code interpretations. | Ready for operator execution during evaluation. |
| **Practice Test Runs** | **COMPLETE** | Internal manual injection testing completed: simulated process termination (`killall node`), port blocks, and DNS re-pointing. | Practice logs reviewed. |
| **Pending Cleanup** | **PENDING** | Ensure temporary debug logging, loose firewall rules, or diagnostic test scripts on all Macs are reverted to clean production baselines. | Pre-evaluation checklist review. |
| **Faculty Evaluation** | **NOT COMPLETED** | The live, unannounced faculty-injected configuration fault occurs during formal project defense. | Awaiting live evaluation slot. |
| **Extension F Final Sign-off** | **IN PROGRESS** | **Cannot be claimed as completed until the faculty evaluation test is executed and documented.** | Post-evaluation evidence capture. |

---

## 6. Comprehensive Security Considerations

### 6.1 Private DNS Security Architecture
- **Protocol**: Standard unencrypted DNS over UDP/TCP port 53.
- **Vulnerabilities**: The system does not implement DNSSEC, DNS-over-HTTPS (DoH), or DNS-over-TLS (DoT). On an untrusted local Wi-Fi segment, DNS queries are vulnerable to sniffing, ARP poisoning, and spoofed response injection.
- **Mitigating Controls**: Operational integrity relies entirely on the physical perimeter security and WPA2/WPA3 encryption of the private Wi-Fi network.

### 6.2 Firewall Restrictions & Microsegmentation
- **PF Enforcement**: Enforcing stateful packet filtering on Mac3 ensures that raw application endpoints (`3001`, `3002`) cannot be accessed directly by unauthorized LAN nodes.
- **Vulnerability if Disabled**: If PF is flushed (`pfctl -d`), Node.js processes become exposed to the entire LAN without rate limiting, authentication, or TLS protection.

### 6.3 TLS Certificate Architecture & Development Limitations
- **Local PKI**: Utilizes `mkcert` with custom Root CA and intermediate certificate generation for `app.teamX.test`.
- **Cryptographic Strength**: Employs RSA 2048-bit or ECDSA P-256 keys with modern TLS 1.3 / TLS 1.2 cipher suites.
- **Limitations**:
  - Certificates are trusted **only** on workstations where the root CA was explicitly installed into the system trust store (`/Library/Keychains/System.keychain`).
  - No Certificate Revocation List (CRL) or Online Certificate Status Protocol (OCSP) stapling is implemented; compromised keys cannot be revoked dynamically.
  - Subject Alternative Name (`SAN`) is constrained strictly to `app.teamX.test`. Requests referencing IP addresses directly fail TLS validation.

### 6.4 Backend Port Exposure & Process Privilege
- **Socket Binding**: Backend Node.js processes bind to `0.0.0.0` (all interfaces). While required for LAN ingress from Mac2, binding to `0.0.0.0` makes the service entirely reliant on the host PF firewall for access control.
- **Least Privilege Execution**: Nginx worker processes and Node.js backend processes execute as non-root user accounts (`kaustubhhiwanj` / standard users). No backend daemon requires `root` privileges.

### 6.5 Failure Domains & Single Points of Failure (SPOF) Analysis

| Failure Domain | Component Host | Impact of Complete Node Failure | Resilience Strategy | Architectural Classification |
|---|---|---|---|---|
| **DNS Resolution** | Mac1 (`10.7.19.129`) | Primary DNS resolver offline. | Automatic failover to Backup DNS on Mac3 (`10.7.24.216`). | **Resilient** (Dual-node) |
| **Edge Gateway** | Mac2 (`10.7.9.219`) | Total ingress failure on `8080/8443`. | Manual/Automated DNS cutover to Standby Nginx on Mac3. | **Partially Resilient** (Subject to DNS TTL & port disparity) |
| **Backend Compute & Data** | Mac3 (`10.7.24.216`) | **Total platform collapse**: Backend A, Backend B, Backup DNS, and Standby Edge all fail simultaneously. | None (Hardware colocation). | **CRITICAL SINGLE POINT OF FAILURE** |

---

## 7. Engineering Verification & Audit Report

### 7.1 Files Inspected
1. `docs/architecture/sections/02_DNS_Architecture.md`: Verified Phase 2 DNS topology, TTL dynamics, and Extension A/B/E documentation.
2. `configs/nginx/nginx.conf`: Verified edge proxy upstream pool configuration, cache paths, and listening ports (8080, 8443).
3. `evidence/04-nginx/load-balancing.md`: Verified round-robin distribution evidence.
4. `evidence/07-wireshark/mac1/README.md`: Verified packet capture analysis demonstrating TLS 1.3 handshake and SNI validation.
5. `/etc/pf.conf` (Local Workstation): Verified system PF base configuration.

### 7.2 Firewall Rules Verified
- Intended anchor rules verified against macOS Packet Filter specification:
  - `pass in quick on en0 proto tcp from 10.7.9.219 to any port {3001, 3002} keep state`
  - `block in drop quick on en0 proto tcp from any to any port {3001, 3002}`
- Remote verification confirmed: Mac3 enforces isolation; local workstation (Mac4) hosts no backend services and runs default OS anchors.

### 7.3 Tests Supported by Concrete Evidence
1. **Load Balancing & Process Failover (Extension D)**: Verified that stopping Backend A causes Nginx to proxy 100% of traffic to Backend B without client-facing errors, and resuming Backend A restores alternating round-robin.
2. **DNS Edge Cutover (Extension E)**: Demonstrated that updating `address=/app.teamX.test/10.7.24.216` redirects DNS query responses to Mac3 within 30 seconds.
3. **Wireshark TLS Verification**: Verified that HTTPS traffic to `app.teamX.test:8443` successfully executes TLS 1.3 ClientHello/ServerHello and encapsulates data in encrypted Application Data records.

### 7.4 Architectural Limitations
1. **Mac3 Single Point of Failure**: Both application backends and the backup DNS server reside on Mac3. Hardware high availability is not achieved.
2. **Edge Port Disparity**: Mac2 listens on 8080/8443; Mac3 listens on 80/443. DNS migration alone cannot remap port numbers for clients hardcoded to port 8443.
3. **No DNSSEC / Plaintext DNS**: Resolution is vulnerable to local network spoofing.

### 7.5 Pending Tasks
1. Complete pre-evaluation environment cleanup on all machines (revert temporary test rules, clear temporary log spam).
2. Undertake live Faculty-injected fault isolation evaluation (Extension F).
3. Capture Wireshark and terminal execution logs during the live evaluation to provide formal completion evidence.

### 7.6 Unsupported Claims that Must Be Removed / Avoided
- ❌ **Claim to Remove**: *"The platform achieves hardware-level high availability across backend instances."*  
  $\rightarrow$ **Correction**: Both backends run on Mac3. High availability is process-level only.
- ❌ **Claim to Remove**: *"Mac4 is active as Backend B."*  
  $\rightarrow$ **Correction**: Mac4 is unavailable as a project server and serves solely as a documentation workstation.
- ❌ **Claim to Remove**: *"Extension F is 100% finished."*  
  $\rightarrow$ **Correction**: Diagnostic procedures and practice tests are complete, but the formal faculty-injected evaluation test is pending live defense.
