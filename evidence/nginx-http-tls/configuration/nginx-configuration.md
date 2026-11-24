# Nginx Configuration Evidence

**Component:** Nginx Reverse Proxy & Load Balancer Configuration  
**Node:** Mac 2 (Primary Edge)  
**Host IP (Phase 2):** `10.7.9.219` *(Historical: `10.7.9.11`, `10.7.26.200`)*  
**Active Config Path:** `/opt/homebrew/etc/nginx/nginx.conf`  
**Repository Path:** [`configs/nginx/nginx.conf`](file:///Users/kaustubhhiwanj/CN-private-network-platform/configs/nginx/nginx.conf)  
**Auditor:** Kaustubh Hiwanj (Senior Computer Networks Engineer)  
**Status:** **VERIFIED**

---

## 1. Nginx Daemon & Binary Identification

The installed Nginx binary and version on Mac 2:

```bash
$ nginx -v
nginx version: nginx/1.31.6
```

**Build & Module Metadata:**
- **Web Server:** Nginx 1.31.6 (Homebrew build on macOS Darwin)
- **SSL Support:** Built with OpenSSL / LibreSSL supporting TLS 1.2 and TLS 1.3
- **Core Modules:** `http_ssl_module`, `http_proxy_module`, `http_cache_module`, `http_upstream_module`

---

## 2. Configuration Syntax Testing (`sudo nginx -t`)

Syntax validation of the active configuration file:

```bash
$ sudo nginx -t -c /opt/homebrew/etc/nginx/nginx.conf
nginx: the configuration file /opt/homebrew/etc/nginx/nginx.conf syntax is ok
nginx: configuration file /opt/homebrew/etc/nginx/nginx.conf test is successful
```

**Result:** Syntax test passed with exit code `0`. All directives, upstream block structures, and cache memory allocations are structurally valid.

---

## 3. Active Configuration Inspection

The active configuration at `/opt/homebrew/etc/nginx/nginx.conf`:

```nginx
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;

    sendfile on;
    keepalive_timeout 65;

    # ==========================================
    # Task D - Backend Pool
    # ==========================================

    upstream backend_pool {
        server 10.7.24.216:3001;
        server 10.7.24.216:3002;
    }

    # ==========================================
    # Task F - HTTP Caching
    # ==========================================

    proxy_cache_path /tmp/nginx_cache
        levels=1:2
        keys_zone=local_cache:10m
        max_size=100m
        inactive=60s
        use_temp_path=off;

    # ==========================================
    # Task D - HTTP Reverse Proxy
    # ==========================================

    server {
        listen 8080;
        server_name app.teamX.test;

        location / {
            proxy_pass http://backend_pool;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    # ==========================================
    # Task E & F - HTTPS / TLS & HTTP Caching
    # ==========================================

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
}
```

---

## 4. Key Architectural Directives Breakdown

### 4.1 Upstream Block (`upstream backend_pool`)
- In active runtime `/opt/homebrew/etc/nginx/nginx.conf`:
  - `server 10.7.24.216:3001;` (Backend A on Mac 3)
  - `server 10.7.24.216:3002;` (Backend B on Mac 3)
- Algorithm: Default round-robin (equal weighted distribution).
- Connection Mode: Decoupled Layer 7 proxy connection over TCP.

### 4.2 Listener Directives
- **Port 8080**: `listen 8080;` handles unencrypted client HTTP requests for `app.teamX.test`.
- **Port 8443**: `listen 8443 ssl;` handles encrypted client HTTPS requests with TLS termination.
- **Port Boundary Rule**: Mac 2 listens strictly on `8080` and `8443`. It does not listen on standard ports `80` or `443`.

### 4.3 Proxy Header Sanitization
- `proxy_set_header Host $host;`: Passes the virtual hostname `app.teamX.test`.
- `proxy_set_header X-Real-IP $remote_addr;`: Passes client IPv4 to origin backends.
- `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`: Appends client IP to proxy chain.
- `proxy_set_header X-Forwarded-Proto $scheme;`: Passes `http` or `https` scheme.

### 4.4 Cryptographic Asset Paths
- `ssl_certificate /opt/homebrew/etc/nginx/certs/app.teamX.test.pem;`: X.509 public leaf certificate.
- `ssl_certificate_key /opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem;`: RSA/ECDSA private key *(strictly protected, permissions `0600`, excluded from Git)*.

---

## 5. Process & Socket State Evidence

Verification command:
```bash
sudo lsof -nP -iTCP:8080,8443 -sTCP:LISTEN
```

**Observed Listening State:**
```text
COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
nginx    6699   root    6u  IPv4 0x466b0bef654d22db      0t0  TCP *:8080 (LISTEN)
nginx    6699   root    7u  IPv4 0x466b0bef654d22dc      0t0  TCP *:8443 (LISTEN)
nginx    6700 nobody    6u  IPv4 0x466b0bef654d22db      0t0  TCP *:8080 (LISTEN)
nginx    6700 nobody    7u  IPv4 0x466b0bef654d22dc      0t0  TCP *:8443 (LISTEN)
```

- Confirms Nginx master (PID `6699`) and worker (PID `6700`) bound to both `8080` and `8443` across all IPv4 interfaces (`*`).
