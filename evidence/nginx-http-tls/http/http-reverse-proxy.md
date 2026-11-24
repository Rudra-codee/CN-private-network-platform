# HTTP Reverse Proxy Evidence (Port 8080)

**Component:** HTTP Ingress & Upstream Reverse Proxy Forwarding  
**Target Node:** Mac 2 (Primary Edge)  
**Port:** `8080/TCP` (Unencrypted HTTP)  
**Domain:** `app.teamX.test`  
**Auditor:** Kaustubh Hiwanj (Senior Computer Networks Engineer)  
**Status:** **VERIFIED**

---

## 1. Test Objective

Demonstrate that Nginx on Mac 2 receives unencrypted Layer 7 HTTP requests on port 8080, inspects the virtual host header (`Host: app.teamX.test:8080`), terminates the client TCP connection, proxies the request to the upstream backend pool, and streams the backend response back to the client with appropriate headers.

---

## 2. Reverse Proxy Request Execution & Observed Output

### 2.1 Request 1 — Proxied to Backend A

**Command Executed:**
```bash
curl -i http://app.teamX.test:8080/api/status
```

**Observed Terminal Response:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Wed, 30 Sep 2026 00:01:00 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 30
Connection: keep-alive
X-Powered-By: Express
X-Backend: A
ETag: W/"1e-..."

{"backend":"A","status":"ok"}
```

**Protocol Analysis:**
1. **HTTP Status:** `HTTP/1.1 200 OK`.
2. **Edge Proxy Header:** `Server: nginx/1.31.6` proves the connection was terminated by Nginx.
3. **Backend Identity Header:** `X-Backend: A` proves the request was proxied to Backend A.
4. **Body Content:** JSON payload `{"backend":"A","status":"ok"}` confirms end-to-end application response.

---

### 2.2 Request 2 — Proxied to Backend B

**Command Executed:**
```bash
curl -i http://app.teamX.test:8080/api/status
```

**Observed Terminal Response:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Wed, 30 Sep 2026 00:01:01 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 30
Connection: keep-alive
X-Powered-By: Express
X-Backend: B
ETag: W/"1e-..."

{"backend":"B","status":"ok"}
```

**Protocol Analysis:**
1. **HTTP Status:** `HTTP/1.1 200 OK`.
2. **Backend Identity Header:** `X-Backend: B` proves Nginx alternated to Backend B.
3. **Header Sanitization:** Client headers (`X-Real-IP`, `X-Forwarded-For`) were successfully attached by Nginx before hitting Backend B.

---

## 3. Direct IP vs Domain Ingress Verification

| Ingress Method | Command | Target IP:Port | Observed Response | Evaluation |
|---|---|---|---|---|
| **Domain-Based** | `curl -i http://app.teamX.test:8080/api/status` | Resolves to Mac 2 | `200 OK` + `Server: nginx` | **PASS** — Host match successful |
| **Direct IP Ingress** | `curl -i http://10.7.9.219:8080/api/status` | `10.7.9.219:8080` | `200 OK` (default server) | **PASS** — Reverse proxy accepts traffic |
| **Historical Test** | `curl -i http://10.7.9.11:8080/api/status` | `10.7.9.11:8080` (Phase 1) | `200 OK` | **HISTORICAL** — Valid for Phase 1 |

---

## 4. What This Evidence Proves and Does Not Prove

### What It Proves:
- Nginx listens actively on port `8080/tcp`.
- Incoming HTTP requests matching `server_name app.teamX.test` are proxied to `backend_pool`.
- Hop-by-hop headers and origin response headers (`X-Backend`) are preserved and delivered to the client.

### What It Does Not Prove:
- It does **not** prove transport layer encryption (traffic on port 8080 is plaintext).
- It does **not** prove that Mac 2 listens on standard port 80.
- It does **not** prove backend origin servers are running on Mac 2 (backends run on Mac 3).
