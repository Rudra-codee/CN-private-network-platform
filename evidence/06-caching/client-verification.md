# Task F — HTTP Caching Client Verification (Mac 1)

**Date:** 2026-10-05 (00:34 - 00:39 IST) / 2026-10-04 (19:04 - 19:09 UTC)  
**Client Hostname:** `Rudrakshs-MacBook-Pro.local` (Mac 1)  
**Client IP:** `10.7.26.214`  
**Target Server:** Mac 2 / nginx reverse proxy (`10.7.26.200:8443`)  
**Target URL:** `https://app.teamX.test:8443/api/status`  
**Role:** Private DNS Server + Test Client  

---

## 1. Objective

Verify client-side HTTP caching behavior against the HTTPS edge proxy (`https://app.teamX.test:8443/api/status`), confirming:
1. Origin server caching headers (`Cache-Control: public, max-age=60`, `ETag`).
2. Edge proxy caching header (`X-Cache-Status`).
3. Initial cache `MISS` fetching response from upstream backend.
4. Subsequent immediate request resulting in cache `HIT` served by nginx.
5. Conditional validation producing `304 Not Modified` with matching `ETag` / `If-None-Match`.

---

## 2. Network & Host Configuration

| Property | Value |
|---|---|
| Client Hostname | `Rudrakshs-MacBook-Pro.local` |
| Client IPv4 | `10.7.26.214` |
| DNS Resolver | `10.7.26.214` (local dnsmasq resolver via `/etc/resolver/teamX.test`) |
| Domain Resolution | `app.teamX.test` → `10.7.26.200` |
| Edge Server | Mac 2 (`10.7.26.200:8443`) |
| Backends | Backend A (`10.7.13.5:3001`), Backend B (`10.7.14.32:3002`) |
| Security | TLSv1.3 (mkcert local CA trusted in macOS System keychain) |

---

## 3. Initial Verification & Cache Transition (MISS → HIT)

### Step 1: Initial Request (Cache MISS)

Execution of initial request after cache cold/expiry:

```bash
$ curl -i https://app.teamX.test:8443/api/status
```

**Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Sun, 04 Oct 2026 19:04:50 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: A
ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
Cache-Control: public, max-age=60
X-Cache-Status: MISS

{"backend":"A","status":"ok"}
```

**Observation:**
- **Status:** `200 OK`
- **Cache-Control:** `public, max-age=60`
- **X-Cache-Status:** `MISS` (Nginx fetched response from Backend A)
- **ETag:** `W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"`

---

### Step 2: Immediate Subsequent Request (Cache HIT)

Re-executing the identical request within the 60-second TTL window:

```bash
$ curl -i https://app.teamX.test:8443/api/status
```

**Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Sun, 04 Oct 2026 19:04:57 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: A
ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
Cache-Control: public, max-age=60
X-Cache-Status: HIT

{"backend":"A","status":"ok"}
```

**Observation:**
- **Status:** `200 OK`
- **X-Cache-Status:** `HIT` (Served directly from nginx cache on Mac 2 without querying upstream backends)
- **Response Time / Headers:** Identical payload and ETag maintained

---

## 4. Cache Expiration Verification (TTL Expiry Demonstration)

To demonstrate cache lifecycle behavior without modifying nginx configuration, a client request was held until after the 60-second `max-age` expired:

```bash
$ sleep 65 && curl -i https://app.teamX.test:8443/api/status && echo "--- 2nd request immediately after ---" && curl -i https://app.teamX.test:8443/api/status
```

**Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Sun, 04 Oct 2026 19:08:56 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: B
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"
Cache-Control: public, max-age=60
X-Cache-Status: MISS

{"backend":"B","status":"ok"}
--- 2nd request immediately after ---
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Sun, 04 Oct 2026 19:08:56 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: B
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"
Cache-Control: public, max-age=60
X-Cache-Status: HIT

{"backend":"B","status":"ok"}
```

**Observation:**
- After TTL expiry (> 60s), the first request yielded `X-Cache-Status: MISS` and round-robined to Backend B (`ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"`).
- The subsequent request immediately received `X-Cache-Status: HIT`.

---

## 5. Conditional Validation (`If-None-Match` → `304 Not Modified`)

Testing conditional revalidation using the cached resource's ETag:

```bash
$ curl -i -H 'If-None-Match: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"' https://app.teamX.test:8443/api/status
```

**Output:**
```http
HTTP/1.1 304 Not Modified
Server: nginx/1.31.6
Date: Sun, 04 Oct 2026 19:05:03 GMT
Connection: keep-alive
X-Powered-By: Express
X-Backend: A
ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
Cache-Control: public, max-age=60
X-Cache-Status: HIT
```

**Observation:**
- HTTP status code returned is `304 Not Modified`.
- No response body is transmitted, conserving network bandwidth.
- Caching headers (`Cache-Control: public, max-age=60`, `ETag`, `X-Cache-Status: HIT`) are properly returned.

---

## 6. Summary of Header Evidence

| Header | Value | Purpose / Meaning |
|---|---|---|
| `Cache-Control` | `public, max-age=60` | Directs intermediate caches and clients to cache response for 60 seconds |
| `ETag` | `W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"` / `W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"` | Weak entity tag for conditional validation |
| `X-Cache-Status` | `MISS` (first call), `HIT` (subsequent) | Custom Nginx cache status indicator header |
| `X-Backend` | `A` or `B` | Upstream backend identifier |
| `Server` | `nginx/1.31.6` | Edge reverse proxy web server |

---

## 7. Verification Checklist

- [x] Client hostname (`Rudrakshs-MacBook-Pro.local`) and IP (`10.7.26.214`) recorded
- [x] HTTPS URL verified: `https://app.teamX.test:8443/api/status`
- [x] `Cache-Control: public, max-age=60` header verified
- [x] `ETag` header verified
- [x] `X-Cache-Status: MISS` and `X-Cache-Status: HIT` verified
- [x] Cache expiry demonstration (> 60s) verified
- [x] Conditional revalidation (`304 Not Modified`) verified
- [x] Responses from both Backend A and Backend B verified
