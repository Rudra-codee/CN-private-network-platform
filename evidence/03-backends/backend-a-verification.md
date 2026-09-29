# Backend A Verification Report

## 1. System Metadata
- **Machine**: Mac 3
- **IP Address**: `10.7.13.5`
- **Role**: Backend Server A
- **Port**: `TCP 3001`
- **Host Binding**: `0.0.0.0`
- **Required Endpoints**: `GET /`, `GET /api/status`
- **Identity Header**: `X-Backend: A`

## 2. Host Binding Explanation
Backend A is configured to bind to `HOST = "0.0.0.0"`.

**Why `0.0.0.0` is required:**
Binding to `0.0.0.0` instructs Node.js to accept incoming connections on all network interfaces of Mac 3 (including the LAN interface `10.7.13.5` and loopback `127.0.0.1`). If the service were bound to `127.0.0.1` (localhost), it would only accept connections originating locally from Mac 3 itself. Because Mac 2 (`10.7.9.11`) acts as the reverse proxy / load balancer in subsequent tasks, Backend A must listen on `0.0.0.0` to be reachable across the LAN.

---

## 3. Verification Results

### 3.1 Socket Listener Verification
Command executed:
```bash
lsof -nP -iTCP:3001 -sTCP:LISTEN
```

Output:
```text
COMMAND   PID             USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    26289 pratyushchouksey   19u  IPv4 0xb63d6330243dd353      0t0  TCP *:3001 (LISTEN)
```
*Result*: Service is actively listening on TCP port 3001 bound to `*` (`0.0.0.0`).

---

### 3.2 Local Test 1: `GET /`
Command executed:
```bash
curl -i http://127.0.0.1:3001/
```

Response:
```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: A
Content-Type: application/json; charset=utf-8
Content-Length: 62
ETag: W/"3e-QF9vFacPifwgRXeqh9wcQA56VjA"
Date: Tue, 29 Sep 2026 11:17:14 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"backend":"A","status":"ok","message":"Backend A is running"}
```
*Result*: `HTTP 200 OK` received with header `X-Backend: A` and expected body payload.

---

### 3.3 Local Test 2: `GET /api/status`
Command executed:
```bash
curl -i http://127.0.0.1:3001/api/status
```

Response:
```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: A
Content-Type: application/json; charset=utf-8
Content-Length: 29
ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
Date: Tue, 29 Sep 2026 11:17:32 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"backend":"A","status":"ok"}
```
*Result*: `HTTP 200 OK` received with header `X-Backend: A` and status body `{"backend":"A","status":"ok"}`.

---

### 3.4 LAN IP Test: `GET /api/status`
Command executed:
```bash
curl -i http://10.7.13.5:3001/api/status
```

Response:
```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: A
Content-Type: application/json; charset=utf-8
Content-Length: 29
ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
Date: Tue, 29 Sep 2026 11:17:59 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"backend":"A","status":"ok"}
```
*Result*: `HTTP 200 OK` received when connecting via Mac 3's LAN IP `10.7.13.5`.

---

### 3.5 Cross-Machine Verification (Documented)
- **Source Machine**: Mac 2 (`10.7.9.11`)
- **Target Endpoint**: `http://10.7.13.5:3001/api/status`
- **Result**:
  - `HTTP 200 OK`
  - `X-Backend: A`

*Note: Reverse proxying/load balancing via Nginx will be configured and verified in Task D.*
