# Backend B Service Specification & Implementation Documentation

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Component:** Backend Service B (`backend-b`)  
**Canonical Source Directory:** [`backend-b/`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b)  
**Author:** Kaustubh Hiwanj (Senior Backend Developer & Project Documentation Engineer)  
**Document Path:** `docs/backend/Backend_B/README.md`  
**Classification:** Core Application Tier Specification  

---

## 1. Backend B Overview & System Role

Backend B is an internal microservice instance designed to operate within the upstream backend pool of the Private Network Service Platform. It processes decoupled Layer 7 HTTP requests forwarded from the primary Nginx edge reverse proxy on Mac 2 (`10.7.9.219:8080/8443`) or the standby edge on Mac 3 (`10.7.24.216:80/443`).

### 1.1 Physical & Logical Infrastructure Allocation (Phase 2 Reality)

```
+──────────────────────────────────────────────────────────────────────────+
|                    Private LAN Subnet (10.7.0.0/19)                      |
|                                                                          |
|  [ Mac 2: Edge Proxy (10.7.9.219) ]                                      |
|    - Port 8080 (HTTP) / 8443 (HTTPS)                                     |
|    - Load balances traffic across upstream backend pool                  |
|                 │                                                        |
|                 ├──────────────────────┬───────────────────────┐         |
|                 ▼ (TCP: 3001)          ▼ (TCP: 3002)           ▼         |
|  ┌────────────────────────────────────────────────────────────┐          |
|  │ Mac 3: Application Server Node (10.7.24.216)               │          |
|  │                                                            │          |
|  │   +────────────────────────+    +────────────────────────+ │          |
|  │   |  Backend A (Node.js)   |    |  Backend B (Node.js)   | │          |
|  │   |  Port: 3001 (0.0.0.0)  |    |  Port: 3002 (0.0.0.0)  | │          |
|  │   |  Header: X-Backend: A  |    |  Header: X-Backend: B  | │          |
|  │   +────────────────────────+    +────────────────────────+ │          |
|  │                                                            │          |
|  │   - Backup dnsmasq (53/udp)                                │          |
|  │   - Standby Nginx (80/443)                                 │          |
|  │   - PF Firewall (enforces access from 10.7.9.219 only)     │          |
|  └────────────────────────────────────────────────────────────┘          |
|                                                                          |
|  [ Mac 4: Administrative Workstation ]                                   |
|    - Status: UNAVAILABLE AS PROJECT SERVER                               |
|    - Role: Documentation & Git operations only                           |
|    - Hosts NO active backend or infrastructure processes                 |
+──────────────────────────────────────────────────────────────────────────+
```

> [!IMPORTANT]
> **Host Relocation from Mac 4 to Mac 3:**  
> In initial Phase 1 planning, Backend B was intended to run on Mac 4. However, due to hardware availability constraints in Phase 2, **Mac 4 was decommissioned as an active project server**. Backend B was consolidated onto **Mac 3 (`10.7.24.216`)**, where it executes concurrently with Backend A (`port 3001`) on dedicated port **`3002`**. Mac 4 functions strictly as an administrative documentation workstation.

---

## 2. Source File Inventory & Architecture

The canonical source directory for Backend B is [`backend-b/`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b).

```
backend-b/
├── package.json         # npm package manifest, scripts, and dependency definitions
├── package-lock.json    # Exact dependency tree lockfile (npm lockfileVersion 3)
├── README.md            # Initial Phase 1 role summary
└── server.js            # Main application entry point and HTTP route handlers
```

### 2.1 File Catalog

| File Name | Absolute Repository Link | Purpose / Description | Lines of Code |
|---|---|---|---|
| `server.js` | [`backend-b/server.js`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/server.js) | Main application entry point; initializes Express app, defines route handlers for `/` and `/api/status`, sets `X-Backend: B` headers, and binds to `0.0.0.0:3002`. | 29 |
| `package.json` | [`backend-b/package.json`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/package.json) | Package metadata, entry definition, dependency declaration (`express`), and npm scripts (`start`, `test`). | 16 |
| `package-lock.json` | [`backend-b/package-lock.json`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/package-lock.json) | Deterministic dependency tree locking Express v5.2.1 and its 43 transitive dependencies. | 890 |
| `README.md` | [`backend-b/README.md`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/README.md) | Historical Phase 1 specification summary noting intended port and headers. | 20 |

---

## 3. Technology Stack, Runtime & Dependencies

### 3.1 Programming Language & Runtime
- **Language**: JavaScript (ECMAScript 2020+)
- **Runtime**: Node.js (Engine requirement `>= 18.0.0` enforced by Express 5 core dependencies such as `finalhandler` and `router`)
- **Execution Mode**: Asynchronous single-threaded event loop

### 3.2 Framework & Dependencies
- **Web Application Framework**: **Express.js v5.2.1**
  - Specified in [`backend-b/package.json`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/package.json#L13-L15): `"express": "^5.2.1"`
  - Locked in [`backend-b/package-lock.json`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/package-lock.json#L243-L285): `version: "5.2.1"`
- **Production Dependencies**:
  - `express`: Minimalist web framework handling routing, request/response abstractions, and HTTP utility headers.
- **Development Dependencies**: None.
- **External Framework Modules**:
  - No database drivers (MongoDB, PostgreSQL, MySQL).
  - No template engines (EJS, Pug).
  - No external logging libraries (Morgan, Winston, Bunyan).
  - No environment loading packages (`dotenv`).

---

## 4. Application Source Code Walkthrough (`server.js`)

The entire application logic is contained in [`backend-b/server.js`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/server.js):

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

### 4.1 Detailed Logic Analysis

1. **Module Initialization (Lines 1–3)**:  
   Instantiates Express by importing the `express` module and calling `express()`.
2. **Socket Configuration Constants (Lines 5–6)**:  
   Defines `HOST = "0.0.0.0"` and `PORT = 3002`.
3. **Root Route Handler (`GET /`, Lines 8–16)**:  
   Explicitly sets the HTTP response header `X-Backend: B` via `res.set("X-Backend", "B")`, then serializes and transmits a JSON payload indicating backend identity and descriptive status.
4. **Health Check Route Handler (`GET /api/status`, Lines 18–25)**:  
   Sets the HTTP response header `X-Backend: B`, returning a concise health check JSON object (`{"backend":"B","status":"ok"}`). This endpoint is actively targeted by the Nginx edge reverse proxy for load balancing and cache validation.
5. **Server Listener Initiation (Lines 27–29)**:  
   Calls `app.listen(PORT, HOST, callback)` to bind the Node.js process to TCP port 3002 across all available network interfaces and logs confirmation to standard output.

---

## 5. Network Socket Binding & Port Configuration

### 5.1 Host Binding: `0.0.0.0` (Inaddr-Any)
In `server.js`, line 5 assigns:
```javascript
const HOST = "0.0.0.0";
```

#### Networking Significance
- If bound to `127.0.0.1` (loopback), the Linux/macOS kernel restricts incoming TCP SYN packets exclusively to packets originating from the local machine. Remote hosts attempting to connect receive an immediate TCP RST (`Connection refused`).
- Binding to `0.0.0.0` instructs the operating system kernel to accept incoming TCP connections on **all active network interfaces**, including:
  - Loopback (`127.0.0.1`)
  - Private Wi-Fi LAN interface (`en0` at `10.7.24.216`)
- **Reverse Proxy Requirement**: Because the edge proxy resides on Mac 2 (`10.7.9.219`), Backend B must listen on `0.0.0.0` so that Mac 2 can establish Layer 4 TCP connections across the private LAN.

### 5.2 Listening Port: `3002/TCP`
In `server.js`, line 6 assigns:
```javascript
const PORT = 3002;
```
- Operates above privileged ports (`1`–`1023`), allowing standard non-root execution.
- Disambiguates Backend B from Backend A (which listens on `3001`), enabling both microservices to execute concurrently on Mac 3 without socket collisions (`EADDRINUSE`).

---

## 6. API Endpoint Specification

Backend B implements exactly two HTTP `GET` endpoints. No other HTTP methods (`POST`, `PUT`, `DELETE`, `PATCH`, `OPTIONS`) or routes are defined.

### 6.1 Endpoint 1: Root Information Endpoint (`GET /`)

- **Path**: `/`
- **HTTP Method**: `GET`
- **Request Parameters / Query Strings**: None accepted.
- **Request Body / Payload**: None (ignored).
- **Response Headers**:
  - `HTTP/1.1 200 OK`
  - `X-Backend: B`
  - `Content-Type: application/json; charset=utf-8`
  - `Content-Length: 62`
  - `ETag: W/"3e-..."` (Auto-generated by Express)
- **Response Body**:
  ```json
  {
    "backend": "B",
    "status": "ok",
    "message": "Backend B is running"
  }
  ```

### 6.2 Endpoint 2: Cluster Status & Health Check Endpoint (`GET /api/status`)

- **Path**: `/api/status`
- **HTTP Method**: `GET`
- **Request Parameters / Query Strings**: None accepted.
- **Request Body / Payload**: None (ignored).
- **Response Headers**:
  - `HTTP/1.1 200 OK`
  - `X-Backend: B`
  - `Content-Type: application/json; charset=utf-8`
  - `Content-Length: 29`
  - `ETag: W/"1d-..."` (Auto-generated by Express)
- **Response Body**:
  ```json
  {
    "backend": "B",
    "status": "ok"
  }
  ```

### 6.3 HTTP Status Codes & Error Behavior
- **`200 OK`**: Returned for valid `GET /` and `GET /api/status` requests.
- **`404 Not Found`**: Returned automatically by Express's internal router for any unmapped route (e.g. `GET /unknown`), serving an HTML error: `Cannot GET /unknown`.
- **`405 Method Not Allowed` / `404 Not Found`**: Non-GET methods (e.g. `POST /api/status`) return `404 Cannot POST /api/status` because explicit 405 middleware is not implemented.

---

## 7. Backend Identification Mechanism

In round-robin load balanced architectures, client requests hit a single edge endpoint (`https://app.teamX.test:8443/api/status`). To verify and audit load distribution across the cluster, Backend B implements a **two-tier identification mechanism**:

1. **Layer 7 HTTP Response Header**:
   ```http
   X-Backend: B
   ```
   Injected via `res.set("X-Backend", "B")`. Nginx preserves upstream headers and relays `X-Backend: B` back to the client. This allows automated verification scripts (such as `curl -sD - ... | grep X-Backend`) to measure round-robin alternation without parsing the JSON body.
2. **Layer 7 JSON Payload Attribute**:
   ```json
   "backend": "B"
   ```
   Enclosed in the response body for application-level consumption.

---

## 8. Operational Runbook: Lifecycle, Startup & Shutdown

### 8.1 Prerequisites
- Node.js installed (`node -v` $\ge$ 18.0.0).
- Dependencies installed in `backend-b/node_modules/`:
  ```bash
  cd backend-b
  npm install
  ```

### 8.2 Startup Command
From the canonical `backend-b` directory:

```bash
# Standard npm script execution
npm start

# Direct node invocation
node server.js
```

**Expected Standard Output:**
```text
Backend B listening on 0.0.0.0:3002
```

### 8.3 Background Daemon Execution
To run Backend B as a persistent background daemon on Mac 3:

```bash
# Run in background redirecting output to log file
nohup node server.js > backend-b.log 2>&1 &

# Identify active Process ID (PID)
pgrep -fl "node server.js"
```

### 8.4 Shutdown Procedure

1. **Foreground Process**: Send interrupt signal via keyboard:
   ```text
   Ctrl + C  (SIGINT)
   ```
2. **Background Process**: Send termination signal using process management:
   ```bash
   # Graceful termination request
   kill $(pgrep -f "node server.js")

   # If multiple instances exist, target port 3002 specifically
   kill $(lsof -t -iTCP:3002 -sTCP:LISTEN)

   # Forceful kill if process is hung
   kill -9 $(lsof -t -iTCP:3002 -sTCP:LISTEN)
   ```

---

## 9. Service Verification Procedure

Because Backend B has no automated test runner configured, verification is performed manually via standard network inspection utilities.

### 9.1 Verification Checklist

#### Step 1: Verify Socket Listener on Mac 3
Confirm that Node.js is actively listening on TCP port 3002 on `0.0.0.0`:
```bash
sudo lsof -nP -iTCP:3002 -sTCP:LISTEN
```
**Expected Output:**
```text
COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    44048 user   15u  IPv4 0x703f1b7fde5cc8cf      0t0  TCP *:3002 (LISTEN)
```

#### Step 2: Direct Local Host Probe (Loopback)
From Mac 3, query the root endpoint:
```bash
curl -i http://127.0.0.1:3002/
```
**Expected Response:**
```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: B
Content-Type: application/json; charset=utf-8
Content-Length: 62

{"backend":"B","status":"ok","message":"Backend B is running"}
```

#### Step 3: Direct Status Endpoint Probe
From Mac 3, query the API status endpoint:
```bash
curl -i http://127.0.0.1:3002/api/status
```
**Expected Response:**
```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: B
Content-Type: application/json; charset=utf-8
Content-Length: 29

{"backend":"B","status":"ok"}
```

#### Step 4: Cross-Node LAN Probe (from Mac 2 Edge)
From the primary edge proxy on Mac 2 (`10.7.9.219`), test direct network reachability to Mac 3's LAN interface:
```bash
curl -i http://10.7.24.216:3002/api/status
```
**Expected Outcome:**
- If PF firewall allows Mac 2: Returns `HTTP/1.1 200 OK` with `X-Backend: B`.
- Confirms end-to-end Layer 3 routing and Layer 4 TCP handshakes across the LAN.

#### Step 5: Negative Security Probe (Firewall Verification)
From any unauthorized node (e.g. Mac 1 `10.7.19.129` or Mac 4):
```bash
curl -i --connect-timeout 3 http://10.7.24.216:3002/api/status
```
**Expected Outcome:**
- `curl: (28) Connection timed out after 3000 milliseconds`
- Proves that the PF firewall on Mac 3 successfully drops packets from unauthorized hosts.

---

## 10. Code Quality, Portability & Architectural Limitations

A rigorous static analysis of [`backend-b/server.js`](file:///Users/kaustubhhiwanj/CN-private-network-platform/backend-b/server.js) and its package metadata reveals several code quality, portability, and resilience findings:

### 10.1 Code Quality Findings & Issues

| Issue / Finding | Location | Severity | Description & Architectural Impact |
|---|---|---|---|
| **Hardcoded Port Constant** | `server.js:6` | Medium | `const PORT = 3002;` is hardcoded. It cannot be overridden dynamically via environment variables (e.g. `process.env.PORT || 3002`), hindering dynamic port binding in containerized or CI/CD pipelines. |
| **Hardcoded Host Binding** | `server.js:5` | Low | `const HOST = "0.0.0.0";` is hardcoded. While appropriate for multi-interface LAN listening, best practice is `process.env.HOST || "0.0.0.0"`. |
| **`package.json` Main Mismatch** | `package.json:5` | Low | Specifies `"main": "index.js"`, but no `index.js` exists in `backend-b/`. Running `node .` fails with `Cannot find module ... index.js`. Execution relies entirely on `npm start` invoking `node server.js`. |
| **Dummy Test Script** | `package.json:7` | Low | `"test": "echo \"Error: no test specified\" && exit 1"`. Running `npm test` fails immediately with exit code 1. No automated test harness exists. |
| **Missing Graceful Shutdown** | `server.js:27-29` | Medium | No signal handlers (`SIGTERM`, `SIGINT`) are registered. Terminating the process forcibly drops in-flight TCP connections rather than draining active sockets via `server.close()`. |
| **Absence of 404 / Error Handlers** | `server.js` | Low | No custom 404 or global error handling middleware is defined. Unhandled route requests leak default Express HTML stack/response structures rather than standardized JSON. |
| **Outdated Host Documentation** | `backend-b/README.md:7` | Low | Documents `Host: Mac 4`. In Phase 2 reality, Backend B runs exclusively on Mac 3. |

### 10.2 Architectural Limitations

1. **Process Redundancy Only (Colocation SPOF)**:
   Backend B executes alongside Backend A on Mac 3 (`10.7.24.216`). While an application crash of Backend A will successfully failover to Backend B via Nginx, **any physical failure, power outage, or OS crash of Mac 3 terminates both backends simultaneously**.
2. **Unauthenticated HTTP**:
   Backend B serves plain HTTP without authentication or transport encryption. It relies entirely on the upstream Nginx edge for TLS termination and Mac 3's PF firewall for network access restriction.
