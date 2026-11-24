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

