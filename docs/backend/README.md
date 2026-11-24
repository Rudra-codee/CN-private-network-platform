# Backend Services Package & Integration Architecture

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** Master Backend Architecture, Service Coordination, Deployment, and Verification Guide  
**Target Path:** `docs/backend/README.md`  
**Classification:** Core Application Tier Master Document  
**Evaluator & Integration Engineer:** Bhargav Patil (Senior Software Integration Engineer)  

---

## 1. Executive Summary & Architecture Overview

The backend package of the **Private Network Service Platform** consists of two independent HTTP REST microservices: **Backend A** and **Backend B**. These services act as the origin application layer, receiving Layer 7 requests forwarded across the private network (`10.7.0.0/19`) from the central Nginx reverse proxy and load balancer.

The microservices are decoupled from client-facing transport encryption, caching, and domain resolution. They execute in a lightweight Node.js/Express environment, exposing standardized JSON status endpoints and custom HTTP response identification headers (`X-Backend: A` and `X-Backend: B`).

```
+──────────────────────────────────────────────────────────────────────────+
|                    Private LAN Subnet (10.7.0.0/19)                      |
|                                                                          |
|   +────────────────────────────+        +────────────────────────────+   |
|   | Mac 1: Primary DNS/Client  |        | Mac 2: Nginx Edge Proxy    |   |
|   |      10.7.19.129           |        |      10.7.9.219            |   |
|   |   - dnsmasq (53/udp)       |        |   - Reverse Proxy & Cache  |   |
|   |   - Test Client            |        |   - Ports 8080 & 8443      |   |
|   +─────────────┬──────────────+        +─────────────┬──────────────+   |
|                 │                                     │                  |
|                 │ Resolves app.teamX.test             │ Round-Robin Pool |
|                 ▼                                     ▼                  |
|   +──────────────────────────────────────────────────────────────────+   |
|   | Mac 3: Backend Application & Standby Edge Host (10.7.24.216)     |   |
|   |                                                                  |   |
|   |   [ Backend A ]                   [ Backend B ]                  |   |
|   |   - Directory: backend-a/         - Directory: backend-b/        |   |
|   |   - Socket: 0.0.0.0:3001          - Socket: 0.0.0.0:3002         |   |
|   |   - Header: X-Backend: A          - Header: X-Backend: B         |   |
|   |   - Health: GET /api/status       - Health: GET /api/status      |   |
|   |                                                                  |   |
|   |   - Backup dnsmasq (53/udp)                                      |   |
|   |   - Standby Nginx (80/443)                                       |   |
|   |   - macOS PF Firewall (Permits 10.7.9.219 -> {3001, 3002} only)  |   |
|   +──────────────────────────────────────────────────────────────────+   |
|                                                                          |
|   [ Mac 4: Administrative Documentation Workstation ]                    |
|     - Status: UNAVAILABLE AS PROJECT SERVER                              |
|     - Role: Documentation, Git management, and Integration Auditing      |
|     - NOT an active host in network topology                             |
+──────────────────────────────────────────────────────────────────────────+
```

### 1.1 Machine Roles & Hardware Colocation Demarcation

1. **Mac 1 (`10.7.19.129`)**: Hosts the primary authoritative `dnsmasq` resolver and functions as an end-to-end client node.
2. **Mac 2 (`10.7.9.219`)**: Hosts the primary Nginx reverse proxy, TLS termination point (`8443`), and caching engine (`8080`), balancing requests across the backend pool.
3. **Mac 3 (`10.7.24.216`)**: **Hosts BOTH Backend A and Backend B**. In addition, Mac 3 hosts the secondary backup `dnsmasq` resolver, standby Nginx reverse proxy (`80/443`), and macOS Packet Filter (`pf`) firewall.
4. **Mac 4 (Administrative Station)**: **Completely unavailable as a server**. In Phase 1 planning, Backend B was intended for Mac 4. Due to physical hardware constraints, Mac 4 was retired from active service. Backend B was migrated to Mac 3. Mac 4 functions solely as an administrative workstation for documentation and evaluation.

---

## 2. Service Documentation Index & Canonical Directories

Each backend service is maintained in its own canonical top-level directory and documented in dedicated specification files:

| Microservice | Canonical Source Directory | Comprehensive Documentation Link | Historical Phase 1 Reference | Active Listening Socket |
|---|---|---|---|---|
| **Backend A** | [`backend-a/`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-a) | [`docs/backend/Backend_A/README.md`](file:///Users/kaustubhhiwanj/CN-private-network-platform/docs/backend/Backend_A/README.md) | [`backend-a/README.md`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-a/README.md) | `0.0.0.0:3001` (TCP) |
| **Backend B** | [`backend-b/`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b) | [`docs/backend/Backend_B/README.md`](file:///Users/kaustubhhiwanj/CN-private-network-platform/docs/backend/Backend_B/README.md) | [`backend-b/README.md`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/README.md) | `0.0.0.0:3002` (TCP) |
| **Integration Review** | Root Repository | [`docs/backend/INTEGRATION_REVIEW.md`](file:///Users/kaustubhhiwanj/CN-private-network-platform/docs/backend/INTEGRATION_REVIEW.md) | N/A | Cross-Service Audit |

> [!NOTE]
> **Deployment Guide Notice**:  
> A standalone file `docs/backend/DEPLOYMENT_AND_EXECUTION.md` was referenced in early task briefs but was not authored as an independent document. All deployment, startup, process management, port allocation, and execution procedures are consolidated directly within this document (Sections 4, 5, and 6) and detailed in the respective service READMEs.

---

## 3. Technology Stack & Dependency Architecture

Both microservices share an identical runtime framework and dependency topology:

| Attribute | Backend A | Backend B | Architectural Consistency |
|---|---|---|---|
| **Programming Language** | JavaScript (ECMAScript 2020+) | JavaScript (ECMAScript 2020+) | **Consistent** |
| **Runtime Engine** | Node.js (Requires $\ge 18.0.0$) | Node.js (Requires $\ge 18.0.0$) | **Consistent** |
| **Application Framework** | Express.js `5.2.1` | Express.js `5.2.1` | **Consistent** |
| **Package Manifest** | [`backend-a/package.json`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-a/package.json) | [`backend-b/package.json`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/package.json) | **Consistent** |
| **Dependency Lockfile** | [`backend-a/package-lock.json`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-a/package-lock.json) | [`backend-b/package-lock.json`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/package-lock.json) | **Consistent** (`lockfileVersion: 3`) |
| **Direct Dependencies** | `express@^5.2.1` (1 direct) | `express@^5.2.1` (1 direct) | **Consistent** |
| **Transitive Dependencies**| 43 packages pinned | 43 packages pinned | **Consistent** |
| **Development Dependencies**| None | None | **Consistent** |

### 3.1 Dependency Installation Procedure

Because both applications run on Mac 3, dependencies must be installed independently in each application directory:

```bash
# 1. Install Backend A dependencies
cd /path/to/CN-private-network-platform/backend-a
npm ci

# 2. Install Backend B dependencies
cd /path/to/CN-private-network-platform/backend-b
npm ci
```

> [!TIP]
> `npm ci` is strictly recommended over `npm install` because it validates and installs strictly against `package-lock.json`, preventing accidental dependency drift.

---

## 4. API Endpoints & Request/Response Contracts

Both backends implement a minimal, non-blocking REST interface with identical path contracts and deterministic JSON payloads:

### 4.1 Endpoint Contract Comparison

| Endpoint | Method | Backend A Response Body | Backend B Response Body | Common Response Headers |
|---|---|---|---|---|
| `/` | `GET` | `{"backend":"A","status":"ok","message":"Backend A is running"}` | `{"backend":"B","status":"ok","message":"Backend B is running"}` | `HTTP/1.1 200 OK`<br/>`Content-Type: application/json; charset=utf-8`<br/>`ETag: W/"..."`<br/>`X-Backend: <ID>` |
| `/api/status` | `GET` | `{"backend":"A","status":"ok"}` | `{"backend":"B","status":"ok"}` | `HTTP/1.1 200 OK`<br/>`Content-Type: application/json; charset=utf-8`<br/>`ETag: W/"..."`<br/>`X-Backend: <ID>` |
| *Unmapped* | *Any* | `404 Cannot <METHOD> <PATH>` | `404 Cannot <METHOD> <PATH>` | `HTTP/1.1 404 Not Found`<br/>`Content-Type: text/html` |

### 4.2 Backend Identification Semantics

To enable automated verification of Nginx round-robin load distribution:
- **Backend A** explicitly executes `res.set("X-Backend", "A")` in [`backend-a/server.js`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-a/server.js#L9).
- **Backend B** explicitly executes `res.set("X-Backend", "B")` in [`backend-b/server.js`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/server.js#L9).

The Nginx edge proxy preserves upstream response headers and relays them back to the client. This allows verification scripts to monitor traffic distribution via `curl -sD - https://app.teamX.test:8443/api/status | grep -i X-Backend`.

---

## 5. Shared Deployment & Process Management on Mac 3

Because Backend A and Backend B execute concurrently on Mac 3 (`10.7.24.216`), strict port isolation and non-destructive process lifecycle controls are required.

### 5.1 Port Disambiguation & Interface Binding

- **Backend A**: Binds to `0.0.0.0:3001`
- **Backend B**: Binds to `0.0.0.0:3002`

Binding to `0.0.0.0` (Inaddr-any) ensures that both microservices accept incoming TCP handshakes arriving across physical interface `en0` from the Nginx proxy on Mac 2 (`10.7.9.219`). Distinct port assignments (`3001` vs `3002`) eliminate port collision risks (`EADDRINUSE`).

### 5.2 Independent Startup Instructions

On Mac 3, start both services in separate terminal sessions or as background daemons:

```bash
# --- Terminal 1: Launch Backend A (Port 3001) ---
cd /path/to/CN-private-network-platform/backend-a
npm start
# Output: Backend A listening on 0.0.0.0:3001

# --- Terminal 2: Launch Backend B (Port 3002) ---
cd /path/to/CN-private-network-platform/backend-b
npm start
# Output: Backend B listening on 0.0.0.0:3002
```

Alternatively, to execute in background with output redirection:
```bash
# Start Backend A background daemon
nohup node backend-a/server.js > /tmp/backend-a.log 2>&1 &

# Start Backend B background daemon
nohup node backend-b/server.js > /tmp/backend-b.log 2>&1 &
```

### 5.3 Safe Port-Specific Shutdown Instructions

> [!CAUTION]
> **Process Termination Safety:**  
> Never use broad process commands like `killall node` or `pkill -f node` on Mac 3. Doing so will terminate **both** Backend A and Backend B simultaneously, breaking failover testing and invalidating operational isolation. Always target specific port listeners:

```bash
# Safely terminate Backend A ONLY (Port 3001)
kill $(lsof -t -iTCP:3001 -sTCP:LISTEN)

# Safely terminate Backend B ONLY (Port 3002)
kill $(lsof -t -iTCP:3002 -sTCP:LISTEN)
```

---

## 6. Service Verification Runbook

### 6.1 Local Socket & Health Verification (on Mac 3)

Execute from Mac 3 to verify local service health:

```bash
# 1. Audit active socket listeners
sudo lsof -nP -iTCP:3001,3002 -sTCP:LISTEN

# 2. Verify Backend A locally
curl -i http://127.0.0.1:3001/api/status
# Expected: HTTP/1.1 200 OK | X-Backend: A | {"backend":"A","status":"ok"}

# 3. Verify Backend B locally
curl -i http://127.0.0.1:3002/api/status
# Expected: HTTP/1.1 200 OK | X-Backend: B | {"backend":"B","status":"ok"}
```

### 6.2 Cross-Node Reverse Proxy Verification (from Client Mac 1)

Execute from Mac 1 to verify that the Nginx edge on Mac 2 correctly distributes requests:

```bash
for i in {1..10}; do
    curl -sD - https://app.teamX.test:8443/api/status | grep -i "X-Backend:"
done
```

**Expected Telemetry:**
```text
X-Backend: A
X-Backend: B
X-Backend: A
X-Backend: B
... (Strict 50/50 alternation)
```

---

## 7. Extension D: Backend Failover Procedure & Mechanics

Extension D demonstrates application resilience against process failure.

### 7.1 Failover Sequence

```
[Step 1: Baseline State]
   Client sends requests -> Nginx distributes 50% to A (3001) and 50% to B (3002).

[Step 2: Fault Injection]
   Operator stops Backend A:
   kill $(lsof -t -iTCP:3001 -sTCP:LISTEN)

[Step 3: Upstream Failure Detection & Failover]
   Client queries https://app.teamX.test:8443/api/status.
   Nginx attempts TCP connection to 10.7.24.216:3001 -> Receives ECONNREFUSED (TCP RST).
   Nginx proxy_next_upstream intercepts error and reroutes request to 10.7.24.216:3002.
   Client receives HTTP 200 OK with X-Backend: B. (Zero client errors).
   100% of subsequent traffic routes to Backend B for the fail_timeout window (10s).

[Step 4: Service Restoration]
   Operator restarts Backend A:
   cd backend-a && npm start

[Step 5: Cluster Re-convergence]
   After fail_timeout expires, Nginx re-probes port 3001.
   Round-robin 50/50 distribution automatically resumes.
```

---

## 8. Critical Architectural Limitations

1. **Process-Level Redundancy Only (No Hardware Fault Tolerance)**:
   Because Backend A (`3001`) and Backend B (`3002`) both run on Mac 3 (`10.7.24.216`), this topology provides **process isolation only**. Any hardware failure, power cut, kernel panic, or network disconnection of Mac 3 results in the **simultaneous total loss of both backends**. It must **never** be documented as hardware-level high availability.
2. **Unauthenticated Backend Ports**:
   Neither backend enforces authentication, rate limiting, or TLS. Security relies exclusively on the macOS Packet Filter (`pf`) firewall on Mac 3 blocking non-edge IP traffic.
3. **Hardcoded Port Constants**:
   Both `backend-a/server.js` and `backend-b/server.js` hardcode ports (`3001` and `3002`) without `process.env.PORT` fallbacks.
4. **Lack of Graceful Shutdown**:
   Neither backend implements `process.on('SIGTERM', ...)` to drain active HTTP connections before exit.
