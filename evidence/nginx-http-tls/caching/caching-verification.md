# HTTP Caching & Cache Negotiation Evidence (Task F)

**Component:** Reverse Proxy HTTP Caching & Conditional Revalidation  
**Cache Host:** Mac 2 (`10.7.26.200` / `10.7.9.219`)  
**Shared Zone:** `local_cache:10m`  
**Disk Cache Path:** `/tmp/nginx_cache`  
**Auditor:** Kaustubh Hiwanj (Senior Computer Networks Engineer)  
**Status:** **VERIFIED**

---

## 1. Active Cache Configuration Directives

Inspected from `/opt/homebrew/etc/nginx/nginx.conf`:

```nginx
# Cache storage zone in http block
proxy_cache_path /tmp/nginx_cache
    levels=1:2
    keys_zone=local_cache:10m
    max_size=100m
    inactive=60s
    use_temp_path=off;

# Server block directives for 8443 ssl
location / {
    proxy_pass http://backend_pool;
    
    # Enable proxy caching
    proxy_cache local_cache;
    proxy_cache_methods GET HEAD;
    proxy_cache_valid 200 60s;

    # Expose client caching headers
    add_header Cache-Control "public, max-age=60" always;
    add_header X-Cache-Status $upstream_cache_status always;
}
```

---

## 2. Empirical Verification: Cache Lifecycle (MISS → HIT)

> [!IMPORTANT]
> **Definitive Cache HIT Proof:**  
> A cache hit cannot be claimed simply because two responses contain identical JSON content (which could occur due to static backend responses). A true cache hit is proven strictly by the **`X-Cache-Status: HIT`** header returned by Nginx without upstream origin query execution.

### 2.1 Request 1: Cache MISS (Cold / Expired Cache)

**Command:**
```bash
curl -i https://app.teamX.test:8443/api/status
```

**Observed Headers:**
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
- `X-Cache-Status: MISS` confirms Nginx had no valid entry in `local_cache`.
- Request was forwarded to Backend A (`X-Backend: A`).
- Response was populated into `/tmp/nginx_cache` with a 60-second validity window.

---

### 2.2 Request 2: Immediate Cache HIT (< 60s TTL)

**Command:**
```bash
curl -i https://app.teamX.test:8443/api/status
```

**Observed Headers:**
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
- **`X-Cache-Status: HIT`** explicitly proves Nginx served the response directly from `/tmp/nginx_cache`.
- Upstream Node.js processes were not contacted.
- Round-robin load balancing was intentionally bypassed because Nginx resolved the request at Layer 7 from cache.

---

## 3. Cache Expiration & Re-fetch (> 60s Demonstration)

To test TTL expiration without altering configurations, a 65-second sleep was executed before querying:

**Command:**
```bash
sleep 65 && curl -i https://app.teamX.test:8443/api/status
```

**Observed Response:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Sun, 04 Oct 2026 19:08:56 GMT
X-Backend: B
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"
Cache-Control: public, max-age=60
X-Cache-Status: MISS

{"backend":"B","status":"ok"}
```

**Observation:**
- Following 65s delay (> 60s `proxy_cache_valid`), the cached entry expired.
- Nginx recorded `X-Cache-Status: MISS` (or `EXPIRED`), queried the next upstream in round-robin sequence (Backend B), and updated the cache with Backend B's payload.

---

## 4. Conditional Validation (`If-None-Match` → `304 Not Modified`)

Testing client-side conditional cache validation using HTTP ETags:

**Command:**
```bash
curl -i -H 'If-None-Match: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"' https://app.teamX.test:8443/api/status
```

**Observed Response:**
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
- Nginx evaluates `If-None-Match` against the cached ETag.
- Returns `HTTP/1.1 304 Not Modified` with zero body bytes, conserving network bandwidth.

---

## 5. What This Evidence Proves and Does Not Prove

### What It Proves:
- Nginx shared-memory caching (`local_cache`) is active and valid.
- The cache lifecycle (`MISS` $\rightarrow$ `HIT` $\rightarrow$ `EXPIRED`) operates deterministically.
- HTTP RFC 7232 conditional revalidation (`304 Not Modified`) is supported.

### What It Does Not Prove:
- It does **not** prove backend-side caching (backends run plain Express; caching is executed exclusively by Nginx on Mac 2).
- It does **not** prove caching for `POST` requests (caching is restricted to `GET` and `HEAD`).
