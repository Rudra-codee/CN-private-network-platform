# Backend Launch Scripts, Dependencies, and Execution Guide

**Project**: Private Network Service Platform — Phase 1 & Phase 2  
**Author / Maintainer**: Pratyush (Senior Backend Engineer & Deployment Specialist)  
**Host Target**: Mac3 (`10.7.24.216`)  
**Document Location**: `docs/backend/DEPLOYMENT_AND_EXECUTION.md`

---

## 1. Executive Summary & Architecture Context

In Phase 1 of the Private Network Service Platform, Backend A was hosted on Mac3 and Backend B was hosted on Mac4. In **Phase 2**, due to hardware reassignment and Mac4's unavailability as a platform server, **both application backends (Backend A and Backend B) are consolidated and co-located on Mac3 (`10.7.24.216`)**.

### Cluster Role & Traffic Matrix

| Node | Physical IP | Active Services & Listening Sockets | Upstream Target Relationship |
|---|---|---|---|
| **Mac3** | `10.7.24.216` | • **Backend A**: `0.0.0.0:3001` (Node/Express)<br>• **Backend B**: `0.0.0.0:3002` (Node/Express)<br>• **Backup DNS**: `53/UDP` (`dnsmasq`)<br>• **Standby Nginx**: `80/TCP` (HTTP) & `443/TCP` (HTTPS) | Host machine for both application backends. Proxied locally by Mac3 Standby Nginx over `127.0.0.1`. |
| **Mac2** | `10.7.9.219` | • **Primary Nginx Reverse Proxy & Load Balancer**: `8080/TCP` & `8443/TCP` | Edge gateway. Proxies external client requests cross-machine across the private LAN to `10.7.24.216:3001` and `10.7.24.216:3002`. |
| **Mac4** | `10.7.14.32` | • Test Client Node only | Unavailable as a project server in Phase 2. Generates test traffic only. |

```
                              PRIVATE LAN (10.7.0.0/19)
   [ Client Machine ]
          │
          ▼
   ┌───────────────────────────────────────────────┐
   │ Mac2: Primary Edge Reverse Proxy (10.7.9.219) │
   │   - HTTP Listener: 8080                       │
   │   - HTTPS Listener: 8443 (TLS 1.3 Termination)│
   └──────────────────────┬────────────────────────┘
                          │ (Round-Robin Cross-Machine HTTP)
                          ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ Mac3: Dedicated Application Host (10.7.24.216)                │
   │                                                               │
   │   ┌────────────────────────┐     ┌────────────────────────┐   │
   │   │  Backend A (Node.js)   │     │  Backend B (Node.js)   │   │
   │   │  Socket: 0.0.0.0:3001  │     │  Socket: 0.0.0.0:3002  │   │
   │   │  Header: X-Backend: A  │     │  Header: X-Backend: B  │   │
   │   └────────────────────────┘     └────────────────────────┘   │
   │               ▲                              ▲                │
   │               │ (Loopback 127.0.0.1)         │                │
   │   ┌───────────┴──────────────────────────────┴────────────┐   │
   │   │ Mac3: Standby Nginx Edge Gateway (Ports 80 & 443)     │   │
   │   └───────────────────────────────────────────────────────┘   │
   └───────────────────────────────────────────────────────────────┘
```

---

## 2. Prerequisites & Environment Specifications

The following software versions and runtime environments have been verified on Mac3:

| Requirement | Verified Specification | Verification Command | Notes |
|---|---|---|---|
| **Operating System** | macOS (Darwin ARM64 / Apple Silicon) | `uname -sm` | Darwin arm64 |
| **Runtime Environment** | Node.js **v22.14.0** (v18+ supported) | `node -v` | Installed via NVM (`~/.nvm`) |
| **Package Manager** | npm **10.9.2** | `npm -v` | Bundled with Node |
| **Process Sockets** | TCP Ports `3001` and `3002` | `lsof -nP -iTCP:3001,3002` | Must be free before fresh launch |
| **Network Interfaces** | `lo0` (`127.0.0.1`) and `en0` (`10.7.24.216`) | `ifconfig en0` | Wi-Fi LAN interface |

### Environment Variables
Neither Backend A nor Backend B consumes external environment variables. Inspection of `backend-a/server.js` and `backend-b/server.js` confirms that:
- `HOST` is hardcoded to `"0.0.0.0"`
- `PORT` is hardcoded to `3001` (Backend A) and `3002` (Backend B)
- No `dotenv`, `process.env.PORT`, or configuration files are referenced.

---

## 3. Dependency Management & Source Inventory

### 3.1 Project Directories & Manifests

Both applications maintain independent, decoupled source directories:

- **Backend A Source Directory**: [`backend-a/`](file:///Users/pratyushchouksey/Downloads/CN-private-network-platform-main%202/backend-a)
  - Entry point: `server.js`
  - Package manifest: `package.json` (`"express": "^5.3.0"`)
  - Lockfile: `package-lock.json`
- **Backend B Source Directory**: [`backend-b/`](file:///Users/pratyushchouksey/Downloads/CN-private-network-platform-main%202/backend-b)
  - Entry point: `server.js`
  - Package manifest: `package.json` (`"express": "^5.2.1"`)
  - Lockfile: `package-lock.json`

### 3.2 Dependency Sharing Analysis
The applications **do not share a common `node_modules` directory**. Each directory contains its own isolated runtime dependencies. Both services rely exclusively on the **Express** web framework.

### 3.3 Dependency Installation Commands

If setting up on a clean environment or if dependencies are missing, install them individually within each application directory:

```bash
# 1. Install Backend A dependencies
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-a
npm install

# 2. Install Backend B dependencies
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-b
npm install
```

> [!NOTE]
> For production reproduction, `npm ci` may be used if the `package-lock.json` matches the `package.json` exactly. Do not regenerate lockfiles or upgrade dependencies unnecessarily.

---

## 4. Backend Service Specifications

### 4.1 Backend Service A

- **Working Directory**: `/Users/pratyushchouksey/Downloads/CN-private-network-platform-main 2/backend-a`
- **Entry Point**: `server.js`
- **Port**: `3001` (TCP)
- **Host Binding**: `0.0.0.0`
- **Identity Header**: `X-Backend: A`
- **Endpoints**:
  - `GET /`: Returns `{"backend":"A","status":"ok","message":"Backend A is running"}`
  - `GET /api/status`: Returns `{"backend":"A","status":"ok"}`

#### Source Code (`backend-a/server.js`):
```javascript
const express = require("express");

const app = express();

const HOST = "0.0.0.0";
const PORT = 3001;

app.get("/", (req, res) => {
  res.set("X-Backend", "A");

  res.json({
    backend: "A",
    status: "ok",
    message: "Backend A is running"
  });
});

app.get("/api/status", (req, res) => {
  res.set("X-Backend", "A");

  res.json({
    backend: "A",
    status: "ok"
  });
});

app.listen(PORT, HOST, () => {
  console.log(`Backend A listening on ${HOST}:${PORT}`);
});
```

### 4.2 Backend Service B

- **Working Directory**: `/Users/pratyushchouksey/Downloads/CN-private-network-platform-main 2/backend-b`
- **Entry Point**: `server.js`
- **Port**: `3002` (TCP)
- **Host Binding**: `0.0.0.0`
- **Identity Header**: `X-Backend: B`
- **Endpoints**:
  - `GET /`: Returns `{"backend":"B","status":"ok","message":"Backend B is running"}`
  - `GET /api/status`: Returns `{"backend":"B","status":"ok"}`

#### Source Code (`backend-b/server.js`):
```javascript
const express = require("express");

const app = express();

const HOST = "0.0.0.0";
const PORT = 3002;

app.get("/", (req, res) => {
  res.set("X-Backend", "B");

  res.json({
    backend: "B",
    status: "ok",
    message: "Backend B is running"
  });
});

app.get("/api/status", (req, res) => {
  res.set("X-Backend", "B");

  res.json({
    backend: "B",
    status: "ok"
  });
});

app.listen(PORT, HOST, () => {
  console.log(`Backend B listening on ${HOST}:${PORT}`);
});
```

---

## 5. Execution & Lifecycle Management

### 5.1 Host Binding Rationale (`0.0.0.0`)

Both applications bind to `HOST = "0.0.0.0"` rather than `127.0.0.1`:
- **Why `127.0.0.1` is insufficient**: If bound only to loopback, the operating system kernel rejects any TCP connections originating across the physical LAN interface (`en0`). Mac2's primary reverse proxy would receive immediate TCP `RST` (connection refused) packets.
- **Why `0.0.0.0` is required**: Binding to `0.0.0.0` binds the socket to all network interfaces. This enables **Mac2** to route traffic across the physical network to `10.7.24.216:3001` and `10.7.24.216:3002`, while simultaneously allowing **Mac3 Standby Nginx** to communicate over loopback `127.0.0.1`.

### 5.2 Manual Startup Commands

#### Option A: Interactive Foreground Execution (For Development & Debugging)
Run each backend in its own terminal window:

```bash
# Terminal 1 — Launch Backend A
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-a
npm start
# Output: Backend A listening on 0.0.0.0:3001

# Terminal 2 — Launch Backend B
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-b
npm start
# Output: Backend B listening on 0.0.0.0:3002
```

#### Option B: Background Daemon Execution (Persistent Execution)
Launch both services in the background with standard output and error redirected to isolated log files:

```bash
# Launch Backend A
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-a
nohup node server.js >> backend-a.log 2>&1 &

# Launch Backend B
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-b
nohup node server.js >> backend-b.log 2>&1 &
```

### 5.3 Manual Safe Shutdown Commands

To terminate individual backend processes without using broad commands like `killall node` (which could terminate unrelated developer tools or editor processes):

```bash
# Stop Backend A (Port 3001) safely
lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -TERM

# Stop Backend B (Port 3002) safely
lsof -tiTCP:3002 -sTCP:LISTEN | xargs kill -TERM
```

If a process hangs or does not exit gracefully after 5 seconds, issue a forced kill:
```bash
lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -9
lsof -tiTCP:3002 -sTCP:LISTEN | xargs kill -9
```

---

## 6. Automated Helper Scripts

To simplify operations and eliminate manual command duplication, three production-grade helper scripts are provided in the [`scripts/`](file:///Users/pratyushchouksey/Downloads/CN-private-network-platform-main%202/scripts) directory.

### 6.1 `scripts/start-backends.sh`
- **Purpose**: Idempotently launches both Backend A and Backend B in the background.
- **Safety**: Checks whether ports 3001 and 3002 are already occupied. If a service is already running, it reports the active PID and skips starting it. Verifies socket listener creation after launch.
- **Usage**:
  ```bash
  ./scripts/start-backends.sh
  ```

### 6.2 `scripts/stop-backends.sh`
- **Purpose**: Gracefully stops both Backend A and Backend B.
- **Safety**: Extracts exact PIDs listening on ports 3001 and 3002 using `lsof`. Sends `SIGTERM`, waits up to 5 seconds for clean exit, and escalates to `SIGKILL` only if the socket remains bound. Never terminates unrelated Node.js processes.
- **Usage**:
  ```bash
  ./scripts/stop-backends.sh
  ```

### 6.3 `scripts/check-backends.sh`
- **Purpose**: Performs runtime socket inspection and live HTTP curl verification for both backends.
- **Verification Criteria**:
  1. Validates socket listening status on `0.0.0.0:3001` and `0.0.0.0:3002`.
  2. Queries `http://127.0.0.1:3001/api/status` and `http://127.0.0.1:3002/api/status`.
  3. Verifies `HTTP 200 OK` status.
  4. Verifies header `X-Backend: A` and `X-Backend: B`.
  5. Verifies valid JSON payload `{"backend":"A|B","status":"ok"}`.
  6. Uses `--noproxy "*"` to prevent shell proxy environment variable interference.
- **Usage**:
  ```bash
  ./scripts/check-backends.sh
  ```

---

## 7. Verification Evidence & Observed Test Outputs

The following commands were directly executed and verified on Mac3:

### 7.1 Socket Listener Verification
Command executed:
```bash
lsof -nP -iTCP:3001,3002 -sTCP:LISTEN
```
Observed terminal output:
```text
COMMAND   PID             USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    83711 pratyushchouksey   19u  IPv4 0x6f35768ea25309be      0t0  TCP *:3001 (LISTEN)
node    71230 pratyushchouksey   19u  IPv4 0x9610378d0ffd23b5      0t0  TCP *:3002 (LISTEN)
```
*Result: Both Node.js runtimes are actively bound to `*` (`0.0.0.0`) in LISTEN state.*

### 7.2 Local HTTP Endpoint Verification (`127.0.0.1`)

#### Backend A (`GET /api/status`):
```bash
curl --noproxy "*" -i http://127.0.0.1:3001/api/status
```
Observed terminal output:
```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: A
Content-Type: application/json; charset=utf-8
Content-Length: 29
ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
Date: Tue, 24 Nov 2026 20:51:02 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"backend":"A","status":"ok"}
```

#### Backend B (`GET /api/status`):
```bash
curl --noproxy "*" -i http://127.0.0.1:3002/api/status
```
Observed terminal output:
```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: B
Content-Type: application/json; charset=utf-8
Content-Length: 29
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"
Date: Tue, 24 Nov 2026 20:51:02 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"backend":"B","status":"ok"}
```

### 7.3 LAN Interface HTTP Verification (`10.7.24.216`)

Command executed:
```bash
curl --noproxy "*" -i http://10.7.24.216:3001/api/status
curl --noproxy "*" -i http://10.7.24.216:3002/api/status
```
Observed terminal output:
- Backend A: Returned `HTTP 200 OK`, `X-Backend: A`, and JSON body `{"backend":"A","status":"ok"}`.
- Backend B: Returned `HTTP 200 OK`, `X-Backend: B`, and JSON body `{"backend":"B","status":"ok"}`.

### 7.4 Root Endpoint Verification (`GET /`)
Command executed:
```bash
curl --noproxy "*" -i http://127.0.0.1:3001/
curl --noproxy "*" -i http://127.0.0.1:3002/
```
Observed terminal output:
- Backend A: Returned `HTTP 200 OK`, `X-Backend: A`, and body:
  `{"backend":"A","status":"ok","message":"Backend A is running"}`
- Backend B: Returned `HTTP 200 OK`, `X-Backend: B`, and body:
  `{"backend":"B","status":"ok","message":"Backend B is running"}`

---

## 8. Failover Verification Procedure (Established Protocol)

The platform architecture incorporates backend failover resilience managed by the Nginx edge proxy on Mac2. 

> [!CAUTION]
> **Operational Safety Notice**: Do NOT execute this failover injection procedure during routine documentation or while live production traffic is active. The following steps document the verified procedure and results established during Phase 2 testing.

### Verified Failover Protocol Steps

```
Step 1: Normal State               Step 2: Failure Injection            Step 3: Self-Healing Recovery
┌─────────────────────────┐        ┌─────────────────────────┐          ┌─────────────────────────┐
│ Both Backends Active    │        │ Backend A Stopped       │          │ Backend A Restarted     │
│ - Backend A (:3001): OK │  ───►  │ - Backend A (:3001): OFF│   ───►   │ - Backend A (:3001): OK │
│ - Backend B (:3002): OK │        │ - Backend B (:3002): OK │          │ - Backend B (:3002): OK │
│ Result: 50/50 Balance   │        │ Result: 100% Traffic->B │          │ Result: 50/50 Balance   │
└─────────────────────────┘        └─────────────────────────┘          └─────────────────────────┘
```

1. **Confirm Initial State**:
   Execute `./scripts/check-backends.sh` to confirm both Backend A (PID 83711) and Backend B (PID 71230) are running and responsive. Verify edge load balancing via Mac2 returns alternating `X-Backend: A` and `X-Backend: B` headers.
2. **Inject Fault (Stop Backend A Only)**:
   Terminate Backend A exclusively:
   ```bash
   lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -TERM
   ```
   Confirm port 3001 is closed while Backend B remains active on port 3002.
3. **Execute Edge Verification Traffic**:
   From a test client (Mac1 or Mac4), issue 10 sequential requests to the primary edge:
   ```bash
   for i in {1..10}; do
       curl -s -D - https://app.teamX.test:8443/api/status -o /dev/null | grep -i "X-Backend:"
   done
   ```
4. **Observe Failover Behavior**:
   - When Nginx attempts to proxy to `10.7.24.216:3001`, the operating system kernel returns an immediate TCP `RST` (`ECONNREFUSED`).
   - Nginx's `proxy_next_upstream` mechanism catches the transport error, temporarily marks Backend A unavailable, and retries the request against Backend B (`10.7.24.216:3002`).
   - **Observed Result**: 10 out of 10 requests succeed with `HTTP 200 OK` returning `X-Backend: B`. Zero client errors or timeouts occur.
5. **Restore Backend A**:
   Restart Backend A on Mac3:
   ```bash
   cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-a
   nohup node server.js >> backend-a.log 2>&1 &
   ```
6. **Confirm Re-Integration**:
   Issue sequential requests to the edge. Once `fail_timeout` expires, Nginx probes Backend A, confirms `200 OK`, and automatically restores 50/50 round-robin alternation.

---

## 9. Troubleshooting Common Startup & Execution Issues

| Symptom / Error | Root Cause | Diagnosis & Resolution |
|---|---|---|
| `Error: listen EADDRINUSE: address already in use 0.0.0.0:3001` | A previous Node instance or orphaned process is already bound to port 3001. | Run `lsof -nP -iTCP:3001 -sTCP:LISTEN` to identify the conflicting PID. Terminate it using `kill -TERM <PID>` before restarting. |
| `Error: Cannot find module 'express'` | Dependencies are missing from `node_modules`. | Run `npm install` inside the affected backend directory (`backend-a` or `backend-b`). |
| `HTTP 400 Direct IP access is not allowed` | Local shell environment variable `http_proxy` intercepted the curl request and routed it through a sandbox proxy. | Use `curl --noproxy "*"` or unset the proxy variables: `unset http_proxy https_proxy`. |
| Connection Refused from Mac2 (`ECONNREFUSED`) | Backend process is stopped, or bound to `127.0.0.1` instead of `0.0.0.0`. | Verify `HOST = "0.0.0.0"` in `server.js` and verify listener via `lsof -nP -iTCP:3001 -sTCP:LISTEN`. |
| Cross-Machine Ping / Request Timeout | macOS Application Firewall or PF packet filter is dropping incoming SYN packets on port 3001/3002. | Check PF rules via `sudo pfctl -sr` and verify port 3001/3002 pass rules are active. |

---

## 10. Known Architectural Limitations

1. **Lack of Independent Machine-Level Hardware Redundancy**:
   Because both Backend A and Backend B are co-located on **Mac3 (`10.7.24.216`)**, there is **no hardware fault tolerance**. While process-level redundancy protects against a single Node.js crash, a physical failure of Mac3 (power interruption, OS kernel panic, or Wi-Fi disconnection) takes both backend application servers and the standby edge offline simultaneously.
2. **Unsupervised Process Lifecycles**:
   The backends currently run as background shell processes (`nohup node server.js &`). They are not configured as system services (`launchd` on macOS or `systemd` on Linux). If Mac3 is rebooted, the backends do not start automatically unless triggered via `./scripts/start-backends.sh`.
3. **Hardcoded Port & Host Assignments**:
   Ports (`3001`, `3002`) and host (`0.0.0.0`) are hardcoded in `server.js`. Modifying port assignments requires updating the JavaScript source files rather than passing dynamic runtime environment variables.
