# Task C — Backend Service B Verification

This document records the configuration, startup, and verification evidence for Backend Service B running on Mac 4 as required by Task C of the Computer Networks project.

## Machine and Network Parameters

| Parameter | Specification / Value |
|---|---|
| Machine | Mac 4 |
| Role | Backend Server B + Test Client |
| Current IPv4 Address | `10.7.29.244` |
| Previous IPv4 Address | `10.7.11.88` *(superseded by DHCP reassignment)* |
| Subnet Mask | `255.255.224.0` (/19) |
| Active Network Interface | `en0` (Wi-Fi) |
| Port | `3002` (TCP) |
| Host Binding | `0.0.0.0` |
| Runtime & Framework | Node.js + Express |
| Expected Backend Header | `X-Backend: B` |

> [!NOTE]
> **DHCP Address Update**: Mac 4 previously held IP `10.7.11.88` during initial Task A LAN inventory tests. Its current DHCP address is `10.7.29.244`. The former `10.7.11.88` address is no longer current and must not be used. All current configurations, LAN requests, cross-machine tests, and documentation reflect `10.7.29.244`.

---

## Host Binding Rationale (`0.0.0.0`)

In `server.js`, the service is explicitly bound to `0.0.0.0` rather than `127.0.0.1`:

```javascript
const HOST = "0.0.0.0";
const PORT = 3002;

app.listen(PORT, HOST, () => {
  console.log(`Backend B listening on ${HOST}:${PORT}`);
});
```

### Why `0.0.0.0` is Required

- **`127.0.0.1` (Loopback Interface)**: Binds only to the virtual loopback adapter. The operating system kernel drops or refuses any TCP packets arriving from external physical network interfaces (such as `en0`).
- **`0.0.0.0` (All IPv4 Interfaces / Inaddr-Any)**: Instructs the TCP socket to accept incoming connections across all active network interfaces on the host, including `127.0.0.1` (loopback) and `10.7.29.244` (`en0` Wi-Fi LAN interface).
- **Network Requirement for Task D**: In Task D, Mac 2 (`10.7.9.11`) acts as the edge reverse proxy and load balancer. To route client traffic to Backend B, Mac 2 must establish TCP connections to `10.7.29.244:3002` across the local area network. If Backend B were bound only to `127.0.0.1`, Mac 2 would receive connection refused (`RST`) errors.

---

## Service Listener Verification

Confirmation that the Node.js process is listening on TCP port 3002 on all interfaces (`0.0.0.0` / `*`):

```bash
sudo lsof -nP -iTCP:3002 -sTCP:LISTEN
```

### Output

```text
COMMAND  PID       USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    3669 ShreePatil   15u  IPv4 0x466b0bef654d22db      0t0  TCP *:3002 (LISTEN)
```

The socket state confirms `TCP *:3002 (LISTEN)` under IPv4.

---

## Local Verification Tests

Local curl queries were executed on Mac 4 against loopback (`127.0.0.1`).

### 1. `GET /` via Localhost

```bash
curl -i http://127.0.0.1:3002/
```

#### Response Output

```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: B
Content-Type: application/json; charset=utf-8
Content-Length: 62
ETag: W/"3e-L7e+fLmzUIpnHbkY2t3E2GNlFR0"
Date: Tue, 29 Sep 2026 11:17:58 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"backend":"B","status":"ok","message":"Backend B is running"}
```

- **HTTP Status**: `200 OK`
- **Header**: `X-Backend: B`
- **Body**: `{"backend":"B","status":"ok","message":"Backend B is running"}`

### 2. `GET /api/status` via Localhost

```bash
curl -i http://127.0.0.1:3002/api/status
```

#### Response Output

```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: B
Content-Type: application/json; charset=utf-8
Content-Length: 29
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"
Date: Tue, 29 Sep 2026 11:18:03 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"backend":"B","status":"ok"}
```

- **HTTP Status**: `200 OK`
- **Header**: `X-Backend: B`
- **Body**: `{"backend":"B","status":"ok"}`

---

## LAN Interface Verification Test

Verification of request delivery using Mac 4's assigned LAN IPv4 address (`10.7.29.244`):

```bash
curl -i http://10.7.29.244:3002/api/status
```

### Response Output

```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: B
Content-Type: application/json; charset=utf-8
Content-Length: 29
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"
Date: Tue, 29 Sep 2026 11:18:10 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"backend":"B","status":"ok"}
```

- **HTTP Status**: `200 OK`
- **Header**: `X-Backend: B`
- **Body**: `{"backend":"B","status":"ok"}`

---

## Cross-Machine Verification Test

Mac 2 (`10.7.9.11`) serves as the edge machine that will load balance traffic to Backend B in Task D. P2P cross-machine HTTP communication was verified directly across the LAN segment:

### Test Execution: Mac 2 → Mac 4

```bash
# Executed from Mac 2 (10.7.9.11) targeting Mac 4 (10.7.29.244:3002)
curl -i http://10.7.29.244:3002/api/status
```

### Result

```http
HTTP/1.1 200 OK
X-Backend: B
Content-Type: application/json; charset=utf-8

{"backend":"B","status":"ok"}
```

- **Verification Status**: `PASS`
- **HTTP Status Code**: `200 OK`
- **Header Confirmed**: `X-Backend: B`
- **Payload Confirmed**: `{"backend":"B","status":"ok"}`

---

## Task D Readiness Status

- [x] Node.js + Express backend service running on Mac 4
- [x] Bound to `0.0.0.0:3002` (accessible over LAN)
- [x] Endpoints `GET /` and `GET /api/status` operational
- [x] Correct header `X-Backend: B` returned
- [x] Validated locally (`127.0.0.1`) and over LAN interface (`10.7.29.244`)
- [x] Validated cross-machine from Mac 2 (`10.7.9.11`)
- [x] Ready to be configured as an upstream server in Nginx reverse proxy / load balancer for Task D

*(Note: Nginx reverse proxy and load balancing are to be configured in Task D and are not yet enabled on this backend.)*
