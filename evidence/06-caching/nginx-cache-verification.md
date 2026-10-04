# Task F — HTTP Caching Verification Evidence

This document records the empirical verification of Task F server-side HTTP caching on Mac 2 (`10.7.26.200`), including active nginx cache configuration directives, configuration syntax validation via `nginx -t`, process status, and empirical HTTP response header verification (`Cache-Control`, `X-Cache-Status`, `ETag`, `200 OK`) at the reverse-proxy layer over HTTPS port 8443.

---

## 1. Network & Proxy Architecture Overview

- **Mac 1 (DNS Server):** `10.7.26.214` — Resolves `app.teamX.test` to `10.7.26.200`
- **Mac 2 (Nginx Proxy / Load Balancer):** `10.7.26.200` — Reverse proxy + TLS termination + HTTP Caching
- **Mac 3 (Backend A):** `10.7.13.5:3001` — Node.js Express service
- **Mac 4 (Backend B):** `10.7.14.32:3002` — Node.js Express service
- **Public HTTPS Endpoint:** `https://app.teamX.test:8443`

---

## 2. Active Nginx Cache Configuration

The reverse-proxy caching configuration on Mac 2 is active in `/opt/homebrew/etc/nginx/nginx.conf` (version-controlled in [`configs/nginx/nginx.conf`](file:///Users/kaustubhhiwanj/CN-private-network-platform/configs/nginx/nginx.conf)).

### Cache Zone Declaration (`http` block)

```nginx
# Shared memory cache zone for HTTP response caching
proxy_cache_path /tmp/nginx_cache
    levels=1:2
    keys_zone=local_cache:10m
    max_size=100m
    inactive=60s
    use_temp_path=off;
```

### Server & Location Block Directives (`server` block for `8443 ssl`)

```nginx
server {
    listen 8443 ssl;
    server_name app.teamX.test;

    ssl_certificate /opt/homebrew/etc/nginx/certs/app.teamX.test.pem;
    ssl_certificate_key /opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem;

    location / {
        proxy_pass http://backend_pool;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Task F — HTTP Caching
        proxy_cache local_cache;
        proxy_cache_methods GET HEAD;
        proxy_cache_valid 200 60s;

        add_header Cache-Control "public, max-age=60" always;
        add_header X-Cache-Status $upstream_cache_status always;
    }
}
```

### Verified Directive Summary

| Directive | Configured Value | Description / Scope |
| :--- | :--- | :--- |
| `proxy_cache_path` | `/tmp/nginx_cache levels=1:2 keys_zone=local_cache:10m` | Defines 10MB shared memory zone `local_cache` and 2-level directory structure on disk |
| `proxy_cache` | `local_cache` | Enables proxy caching for requests matching location `/` |
| `proxy_cache_methods` | `GET HEAD` | Restricts cache key storage to `GET` and `HEAD` requests |
| `proxy_cache_valid` | `200 60s` | Caches successful HTTP 200 responses for 60 seconds |
| `add_header Cache-Control` | `"public, max-age=60" always` | Emits client-facing cache duration header |
| `add_header X-Cache-Status` | `$upstream_cache_status always` | Exposes proxy cache state (`HIT`, `MISS`, `EXPIRED`) to clients |

---

## 3. Nginx Configuration Syntax Testing (`sudo nginx -t`)

Configuration validity was tested against the active nginx configuration file.

### Verification Command

```bash
sudo nginx -t
```

### Verified Terminal Output

```
nginx: the configuration file /opt/homebrew/etc/nginx/nginx.conf syntax is ok
nginx: configuration file /opt/homebrew/etc/nginx/nginx.conf test is successful
```

**Result:** Syntax test passed cleanly with exit code `0`.

---

## 4. Nginx Process & Service Status

Verification of active nginx processes, including master, worker, and cache manager.

### Process Status (`ps aux | grep nginx`)

```bash
ps aux | grep nginx
```

### Verified Output

```
root              4800   0.0  0.0 435325888    656   ??  Ss   12:27AM   0:00.03 nginx: master process /opt/homebrew/opt/nginx/bin/nginx -g daemon off;
nobody            4801   0.0  0.0 435322640   3360   ??  S    12:27AM   0:00.12 nginx: worker process
nobody            4802   0.0  0.0 435322640   1360   ??  S    12:27AM   0:00.05 nginx: cache manager process
```

**Result:** Master process (PID `4800`), worker process (PID `4801`), and dedicated cache manager process (PID `4802`) are running continuously.

---

## 5. Server-Side Evidence & HTTP Cache Lifecycle Verification

### 5.1 Initial / Cache Refresh Request (`X-Cache-Status: MISS / EXPIRED`)

Upon cache initialization or after cache expiration (>60 seconds), nginx forwards the request to the upstream backend pool and populates the cache zone.

**Command:**
```bash
curl -i https://app.teamX.test:8443/api/status
```

**Verified Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Sun, 04 Oct 2026 19:06:59 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: A
ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
Cache-Control: public, max-age=60
X-Cache-Status: EXPIRED

{"backend":"A","status":"ok"}
```

---

### 5.2 Subsequent Cached Request (`X-Cache-Status: HIT`)

Subsequent requests executed within the 60-second window are served directly from nginx reverse-proxy cache without hitting upstream Node.js backends.

**Command:**
```bash
curl -i https://app.teamX.test:8443/api/status
```

**Verified Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Sun, 04 Oct 2026 19:07:06 GMT
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

**Verification Highlights:**
1. **HTTP Status:** `HTTP/1.1 200 OK`
2. **Cache Header:** `Cache-Control: public, max-age=60`
3. **Cache Status:** `X-Cache-Status: HIT`
4. **Validation Identifier:** `ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"` present
5. **Reverse Proxy Caching:** Served instantly by nginx at layer 7 before hitting backend servers.

---

### 5.3 Verbose TLS Handshake & Header Evidence

**Command:**
```bash
curl -v https://app.teamX.test:8443/api/status
```

**Verified Terminal Log:**
```
* Host app.teamX.test:8443 was resolved.
* IPv4: 10.7.26.200
* Trying 10.7.26.200:8443...
* Connected to app.teamX.test (10.7.26.200) port 8443
* ALPN: curl offers h2,http/1.1
* (304) (OUT), TLS handshake, Client hello (1):
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
* Server certificate:
*  subject: O=mkcert development certificate; OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)
*  SSL certificate verify ok.
> GET /api/status HTTP/1.1
> Host: app.teamX.test:8443
> User-Agent: curl/8.7.1
> Accept: */*
> 
< HTTP/1.1 200 OK
< Server: nginx/1.31.6
< Date: Sun, 04 Oct 2026 19:07:06 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 29
< Connection: keep-alive
< X-Powered-By: Express
< X-Backend: A
< ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
< Cache-Control: public, max-age=60
< X-Cache-Status: HIT
< 
{"backend":"A","status":"ok"}
```

---

## 6. Regression & Safety Compliance

- **TLS / HTTPS:** Port 8443 remains fully active with TLS 1.3 handshake negotiation and valid CA trust.
- **DNS Resolution:** `app.teamX.test` resolves to `10.7.26.200`.
- **Upstream Pool:** Backend A (`10.7.13.5:3001`) and Backend B (`10.7.14.32:3002`) configuration untouched.
- **Task D HTTP Port 8080:** Remains operational.
