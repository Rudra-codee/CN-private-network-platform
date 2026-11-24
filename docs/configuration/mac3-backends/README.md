# Mac3 Application Backends Architecture & Configuration

This document specifies the architecture, source code implementation, network binding semantics, service lifecycles, and verification commands for **Backend Service A** and **Backend Service B** deployed on **Mac3** for the **Private Network Service Platform**.

---

## 1. Node Profile & Backend Role Distribution

In Phase 1, Backend A was hosted on Mac3 (`port 3001`), while Backend B was hosted on Mac4 (`port 3002`). 
In **Phase 2**, both backend services are consolidated and run concurrently on **Mac3** (`10.7.24.216`).

| Component | Backend Service A | Backend Service B |
|---|---|---|
| **Host Node** | Mac3 | Mac3 |
| **Physical IP Address** | `10.7.24.216` | `10.7.24.216` |
| **Assigned TCP Port** | **`3001`** | **`3002`** |
| **Socket Binding Address** | `0.0.0.0` (`INADDR_ANY`) | `0.0.0.0` (`INADDR_ANY`) |
| **Application Runtime** | Node.js (v18+) + Express | Node.js (v18+) + Express |
| **Source Code File** | [`backend-a/server.js`](file:///Users/pratyushchouksey/Downloads/CN-private-network-platform-main%202/backend-a/server.js) | [`backend-b/server.js`](file:///Users/pratyushchouksey/Downloads/CN-private-network-platform-main%202/backend-b/server.js) |
| **Package Definition** | [`backend-a/package.json`](file:///Users/pratyushchouksey/Downloads/CN-private-network-platform-main%202/backend-a/package.json) | [`backend-b/package.json`](file:///Users/pratyushchouksey/Downloads/CN-private-network-platform-main%202/backend-b/package.json) |
| **Identity Header** | `X-Backend: A` | `X-Backend: B` |
| **Nginx Standby Upstream**| `127.0.0.1:3001` | `127.0.0.1:3002` |

---

## 2. Source Code Implementation

Both backend microservices are implemented using Express, providing deterministic endpoints for health checks, application routing, and reverse-proxy caching validation.

### 2.1 Backend A Implementation (`backend-a/server.js`)

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

### 2.2 Backend B Implementation (`backend-b/server.js`)

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

## 3. Network Architecture & Host Binding Rationale

### 3.1 Wildcard Interface Binding (`0.0.0.0`)
Both backends explicitly declare `const HOST = "0.0.0.0"`.

**Engineering Rationale:**
- **Loopback (`127.0.0.1`) Limitation**: Binding strictly to `127.0.0.1` restricts socket listeners exclusively to the local virtual loopback interface (`lo0`). External TCP SYN segments arriving over the physical LAN (`en0`) from Mac2's primary reverse proxy would be rejected by the kernel with a TCP `RST`.
- **Wildcard (`0.0.0.0`) Flexibility**: Binding to `0.0.0.0` instructs the macOS BSD socket layer to accept incoming connections across **all active network interfaces**:
  1. **Physical LAN (`10.7.24.216`)**: Enables Mac2 (`10.7.9.219`) to proxy traffic cross-machine to Backend A and Backend B.
  2. **Local Loopback (`127.0.0.1`)**: Enables Mac3's standby Nginx to proxy traffic locally via high-speed inter-process communication without packet transmission over the Wi-Fi card.

---

## 4. Backend Service Management Lifecycle

Both services run as unprivileged user-space Node.js processes under user `pratyushchouksey`.

### 4.1 Dependency Installation

Before running the services, ensure dependencies (`express`) are installed:

```bash
# Install dependencies for Backend A
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-a
npm install

# Install dependencies for Backend B
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-b
npm install
```

### 4.2 Starting Backend Services

#### Method A: Foreground Execution (Terminal Dev Mode)
```bash
# Terminal 1: Start Backend A
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-a
npm start
# Output: Backend A listening on 0.0.0.0:3001

# Terminal 2: Start Backend B
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-b
npm start
# Output: Backend B listening on 0.0.0.0:3002
```

#### Method B: Background Daemon Execution (Persistent Mode)
```bash
# Start Backend A in background with log redirection
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-a
nohup node server.js > backend-a.log 2>&1 &

# Start Backend B in background with log redirection
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-b
nohup node server.js > backend-b.log 2>&1 &
```

#### Method C: Process Manager Execution (`pm2` if installed)
```bash
pm2 start backend-a/server.js --name "backend-a"
pm2 start backend-b/server.js --name "backend-b"
```

### 4.3 Stopping Backend Services

To stop or terminate individual backend processes:

```bash
# Graceful termination by port lookup
lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -TERM
lsof -tiTCP:3002 -sTCP:LISTEN | xargs kill -TERM

# Force termination (if hanging)
lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -9
lsof -tiTCP:3002 -sTCP:LISTEN | xargs kill -9
```

### 4.4 Restarting Backend Services

```bash
# Restart Backend A
lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -TERM
sleep 1
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-a && nohup node server.js > backend-a.log 2>&1 &

# Restart Backend B
lsof -tiTCP:3002 -sTCP:LISTEN | xargs kill -TERM
sleep 1
cd /Users/pratyushchouksey/Downloads/CN-private-network-platform-main\ 2/backend-b && nohup node server.js > backend-b.log 2>&1 &
```

### 4.5 Runtime Socket Listener Inspection

Verify that both Node.js runtimes are actively bound to their assigned ports:

```bash
lsof -nP -iTCP:3001,3002 -sTCP:LISTEN
```

**Verified Runtime Output:**
```text
COMMAND   PID             USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    83711 pratyushchouksey   19u  IPv4 0x6f35768ea25309be      0t0  TCP *:3001 (LISTEN)
node    71230 pratyushchouksey   19u  IPv4 0x9610378d0ffd23b5      0t0  TCP *:3002 (LISTEN)
```

---

## 5. Direct Functional Verification Tests

Execute the following test queries to verify endpoint response integrity, HTTP status codes, and identification headers directly against the origins:

### 5.1 Local Loopback Verification (`127.0.0.1`)

```bash
# Verify Backend A Root
curl -i http://127.0.0.1:3001/

# Verify Backend A Status
curl -i http://127.0.0.1:3001/api/status

# Verify Backend B Root
curl -i http://127.0.0.1:3002/

# Verify Backend B Status
curl -i http://127.0.0.1:3002/api/status
```

### 5.2 LAN Interface Verification (`10.7.24.216`)

```bash
# Cross-machine or LAN test targeting Backend A
curl -i http://10.7.24.216:3001/api/status

# Cross-machine or LAN test targeting Backend B
curl -i http://10.7.24.216:3002/api/status
```

**Expected HTTP Response Verification Checklist:**
- [x] **HTTP Status**: `200 OK`
- [x] **Content-Type**: `application/json; charset=utf-8`
- [x] **ETag Header**: Automatically generated (e.g. `ETag: W/"1d-..."`) for RFC 7232 caching support
- [x] **Custom Header**: `X-Backend: A` on port 3001; `X-Backend: B` on port 3002
- [x] **Response Payload**: `{"backend":"A","status":"ok"}` / `{"backend":"B","status":"ok"}`
