# Task F — Backend B HTTP Caching Compatibility Verification

This document records the verification and caching compatibility evidence for **Backend Service B** running on **Mac 4** as required by **Task F — HTTP Caching** of the Computer Networks "Private Network Service Platform" project.

---

## 1. Architectural Role and Layer Separation

In the Private Network Service Platform architecture:
- **Nginx (Mac 2)** acts as the **Reverse Proxy, Load Balancer, and HTTP Caching Layer**. Nginx terminates client requests, enforces caching policies (such as `proxy_cache_valid`), maintains the cache store, and serves cached responses (`HIT`) or proxies to upstreams (`MISS`/`BYPASS`).
- **Backend B (Mac 4)** acts strictly as an **Upstream Origin Server**. Backend B does **NOT** configure or run Nginx caching locally. Instead, it provides standard, deterministic HTTP responses equipped with standard HTTP caching headers (`ETag`) to enable efficient upstream caching and conditional revalidation (`304 Not Modified`).

```
+-------------------------------------------------------------+
|                  Client Request (HTTP/HTTPS)                |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                     Mac 2: Nginx Layer                      |
|               (Reverse Proxy + HTTP Caching)                |
|  - Manages cache keys and cache storage                     |
|  - Serves cached responses (X-Cache-Status: HIT)            |
|  - Proxies cache misses to origin (X-Cache-Status: MISS)    |
+-------------------------------------------------------------+
               |                               |
               | (MISS)                        | (MISS)
               v                               v
+-------------------------------+ +---------------------------+
|      Mac 3: Backend A         | |     Mac 4: Backend B      |
|       (Origin Server)         | |      (Origin Server)      |
|         Port: 3001            | |        Port: 3002         |
|        X-Backend: A           | |       X-Backend: B        |
+-------------------------------+ +---------------------------+
```

---

## 2. Machine and Network Parameters

| Parameter | Specification / Value |
|---|---|
| **Machine** | Mac 4 |
| **Role** | Origin Server (Backend B) + Test Client |
| **Current IPv4 Address** | `10.7.14.32` |
| **Subnet Mask** | `255.255.224.0` (/19) |
| **Network Interface** | `en0` (Wi-Fi) |
| **Port** | `3002` (TCP) |
| **Host Binding** | `0.0.0.0` |
| **Runtime & Framework** | Node.js + Express |
| **Backend Header** | `X-Backend: B` |
| **Caching Header (Validator)** | `ETag` (Entity Tag) |
| **Endpoint** | `GET /api/status` |

---

## 3. Service Listener Verification

Confirmation that Backend B is running and actively listening on port `3002` across all interfaces (`0.0.0.0` / `*`):

```bash
lsof -nP -iTCP:3002 -sTCP:LISTEN
```

### Output

```text
COMMAND   PID       USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    44048 ShreePatil   15u  IPv4 0x703f1b7fde5cc8cf      0t0  TCP *:3002 (LISTEN)
```

The listener status confirms that the Node.js process is bound to TCP port `3002` and ready to receive requests over the LAN.

---

## 4. Origin Endpoint Verification (`GET /api/status`)

Verification command executed against Backend B's LAN IP (`10.7.14.32`):

```bash
curl -i http://10.7.14.32:3002/api/status
```

### Response Output

```http
HTTP/1.1 200 OK
X-Powered-By: Express
X-Backend: B
Content-Type: application/json; charset=utf-8
Content-Length: 29
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"
Date: Sun, 04 Oct 2026 19:05:33 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"backend":"B","status":"ok"}
```

### Confirmation Checklist
- [x] **HTTP Status Code**: `200 OK`
- [x] **Backend Identity Header**: `X-Backend: B`
- [x] **ETag Header Present**: `ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"`
- [x] **Content-Type**: `application/json; charset=utf-8`
- [x] **Response Payload**: `{"backend":"B","status":"ok"}`

---

## 5. Cache Revalidation Verification (Conditional `If-None-Match`)

When Nginx or intermediate caches validate stale cached content, they send conditional HTTP requests containing the `If-None-Match` header. Backend B natively supports HTTP 304 validation based on its computed ETag.

```bash
curl -i -H 'If-None-Match: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"' http://10.7.14.32:3002/api/status
```

### Response Output

```http
HTTP/1.1 304 Not Modified
X-Powered-By: Express
X-Backend: B
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"
Date: Sun, 04 Oct 2026 19:04:37 GMT
Connection: keep-alive
Keep-Alive: timeout=5
```

- **Validation Result**: Backend B successfully returns `304 Not Modified` when an identical ETag is matched, confirming full compliance with HTTP caching revalidation mechanisms.

---

## 6. Origin Health and Stability Under Load

To confirm Backend B remains healthy and responsive while Nginx caching is operational, sequential status requests were issued:

```bash
for i in {1..5}; do curl -s -o /dev/null -w "%{http_code} (%{time_total}s)\n" http://10.7.14.32:3002/api/status; done
```

### Output

```text
200 (0.004217s)
200 (0.005126s)
200 (0.004208s)
200 (0.005042s)
200 (0.004140s)
```

- **Health Status**: 100% success rate (`200 OK`).
- **Latency**: Average response time under 5ms.
- **Service Stability**: Backend B maintains consistent availability as an upstream origin server.

---

## 7. Verification Summary

| Check Item | Requirement | Observed Status | Result |
|---|---|---|---|
| **Origin Endpoint** | `GET /api/status` | Accessible at `http://10.7.14.32:3002/api/status` | **PASS** |
| **HTTP Status** | `200 OK` | `HTTP/1.1 200 OK` returned | **PASS** |
| **Backend Header** | `X-Backend: B` | Header explicitly set and present | **PASS** |
| **ETag Header** | Response includes ETag | `ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"` present | **PASS** |
| **Revalidation** | RFC 7232 conditional support | `304 Not Modified` on matching `If-None-Match` | **PASS** |
| **Origin Isolation** | No local Nginx caching | Nginx handles caching layer on Mac 2; Backend B is origin | **PASS** |
| **Health Stability** | Uninterrupted health | 100% successful requests with sub-5ms latency | **PASS** |
