# Mac3 Standby Nginx Edge Gateway Configuration

This document details the configuration, TLS setup, operational procedures, and service lifecycle for the **Standby Nginx Edge Gateway** deployed on **Mac3** as part of the **Private Network Service Platform (Phase 2)**.

---

## 1. Architectural Role & Node Specifications

In Phase 2, Mac3 serves as both the application backend host and the **standby edge gateway** for the platform. When traffic is routed to Mac3 (via DNS failover or migration), this Nginx instance terminates HTTP and HTTPS traffic on standard web ports and proxies locally to co-located Node.js backends.

| Property | Value | Notes |
|---|---|---|
| **Host Node** | Mac3 | Dedicated host |
| **Physical IP Address** | `10.7.24.216` | Static/LAN lease |
| **HTTP Port** | **`80/TCP`** | Standard privileged web port |
| **HTTPS Port** | **`443/TCP`** | Standard privileged SSL/TLS web port |
| **Active Config Path** | `/opt/homebrew/etc/nginx/standby.conf` | Root-owned Nginx configuration |
| **PID File Location** | `/opt/homebrew/var/run/nginx-standby.pid` | Isolated runtime process ID |
| **Error Log File** | `/opt/homebrew/var/log/nginx-standby-error.log` | Dedicated standby log |
| **Proxy Cache Root** | `/opt/homebrew/var/cache/nginx-standby` | Dedicated standby cache path |
| **Repository Backup Path** | [`docs/configuration/mac3-standby-nginx/standby.conf`](standby.conf) | Sanitized repository copy |

> [!IMPORTANT]
> ### Standard Privileged Port Binding (`80` & `443`)
> Unlike Mac2's primary Nginx edge (which listens on unprivileged ports `8080` and `8443`), Mac3's standby edge binds directly to **port 80** and **port 443**. Binding to ports $< 1024$ on macOS strictly requires root superuser privileges (`sudo`).

---

## 2. Upstream Backend Architecture & Local Proxying

The upstream server pool delegates requests locally over the operating system loopback interface:

```nginx
upstream backend_pool {
    server 127.0.0.1:3001;
    server 127.0.0.1:3002;
}
```

- **Backend A**: `127.0.0.1:3001` (Node.js/Express)
- **Backend B**: `127.0.0.1:3002` (Node.js/Express)
- **Load Balancing Strategy**: Default Round-Robin (alternating sequential requests 50/50).
- **Inter-Process Communication (IPC)**: Traffic between standby Nginx and the backends traverses the kernel loopback adapter (`lo0`), eliminating physical Wi-Fi serialization and network latency.

---

## 3. Active Nginx Standby Configuration

The active configuration at `/opt/homebrew/etc/nginx/standby.conf` contains two server blocks and an integrated HTTP caching zone:

```nginx
worker_processes 1;
pid /opt/homebrew/var/run/nginx-standby.pid;
error_log /opt/homebrew/var/log/nginx-standby-error.log;

events {
    worker_connections 1024;
}

http {
    include /opt/homebrew/etc/nginx/mime.types;
    default_type application/octet-stream;

    sendfile on;
    keepalive_timeout 65;

    upstream backend_pool {
        server 127.0.0.1:3001;
        server 127.0.0.1:3002;
    }

    proxy_cache_path /opt/homebrew/var/cache/nginx-standby
        levels=1:2
        keys_zone=local_cache:10m
        max_size=100m
        inactive=60s
        use_temp_path=off;

    server {
        listen 80;
        server_name app.teamX.test;

        location / {
            proxy_pass http://backend_pool;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    server {
        listen 443 ssl;
        server_name app.teamX.test;

        ssl_certificate /opt/homebrew/etc/nginx/standby-certs/app.teamX.test.pem;
        ssl_certificate_key /opt/homebrew/etc/nginx/standby-certs/app.teamX.test-key.pem;

        location / {
            proxy_pass http://backend_pool;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

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

## 4. TLS Certificate Setup & Security Architecture

### 4.1 Certificate File Inventory & Verification

The standby Nginx SSL server block references X.509 TLS certificates located on the local filesystem:

| File Role | Active Production Path | Backup / Staging Path | Permissions | Owner |
|---|---|---|---|---|
| **Public X.509 Certificate** | `/opt/homebrew/etc/nginx/standby-certs/app.teamX.test.pem` | `/Users/pratyushchouksey/standby-certs/app.teamX.test.pem` | `-rw-r--r--` (`0644`) | `root:wheel` / `pratyushchouksey:staff` |
| **Private Key** | `/opt/homebrew/etc/nginx/standby-certs/app.teamX.test-key.pem` | `/Users/pratyushchouksey/standby-certs/app.teamX.test-key.pem` | `-rw-------` (`0600`) | `root:wheel` / `pratyushchouksey:staff` |

> [!CAUTION]
> ### Strict Security Compliance: Zero Private Key Commits
> Private key files (`app.teamX.test-key.pem`) contain sensitive cryptographic material and must **NEVER** be committed to Git, shared across non-secure channels, or displayed in documentation. Permissions must remain strictly restricted (`0600`).

### 4.2 Certificate Inspection & Metadata

Inspecting the public certificate using OpenSSL:

```bash
openssl x509 -in /opt/homebrew/etc/nginx/standby-certs/app.teamX.test.pem -noout -subject -issuer -dates -ext subjectAltName
```

**Verified Certificate Attributes:**
- **Subject**: `O=mkcert development certificate, OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)`
- **Issuer**: `O=mkcert development CA, OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj), CN=mkcert kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local`
- **Validity Window**: Valid through **29 December 2028** (`notAfter=Dec 29 19:39:57 2028 GMT`).
- **Subject Alternative Name (SAN)**: `DNS:app.teamX.test`. Matches the server name exactly, ensuring trusted client validation without browser warnings or `curl -k`.

### 4.3 Staging to Production Certificate Deployment Procedure

If certificates are updated or regenerated:
```bash
# 1. Ensure production directory exists
sudo mkdir -p /opt/homebrew/etc/nginx/standby-certs

# 2. Copy certificate and key from staging
sudo cp /Users/pratyushchouksey/standby-certs/app.teamX.test.pem /opt/homebrew/etc/nginx/standby-certs/
sudo cp /Users/pratyushchouksey/standby-certs/app.teamX.test-key.pem /opt/homebrew/etc/nginx/standby-certs/

# 3. Enforce secure file permissions
sudo chmod 644 /opt/homebrew/etc/nginx/standby-certs/app.teamX.test.pem
sudo chmod 600 /opt/homebrew/etc/nginx/standby-certs/app.teamX.test-key.pem
sudo chown root:wheel /opt/homebrew/etc/nginx/standby-certs/*
```

---

## 5. Configuration Validation Commands

Because `/opt/homebrew/etc/nginx/standby.conf` reads private keys restricted to `root` and binds privileged ports, validation commands must be executed using `sudo`:

```bash
# Validate syntax and test configuration load
sudo nginx -t -c /opt/homebrew/etc/nginx/standby.conf
```

**Expected Successful Output:**
```text
nginx: the configuration file /opt/homebrew/etc/nginx/standby.conf syntax is ok
nginx: configuration file /opt/homebrew/etc/nginx/standby.conf test is successful
```

---

## 6. Service Management Commands (Start, Stop, Reload, Status)

To prevent collision with default Nginx configurations, all management commands must explicitly target the standby configuration file (`-c`) and PID file:

### 6.1 Start Service
```bash
# Ensure cache directory exists
sudo mkdir -p /opt/homebrew/var/cache/nginx-standby

# Start Nginx standby gateway
sudo nginx -c /opt/homebrew/etc/nginx/standby.conf
```

### 6.2 Stop Service
```bash
# Fast shutdown via signal
sudo nginx -s stop -c /opt/homebrew/etc/nginx/standby.conf

# Alternatively, terminate using stored PID
sudo kill -TERM $(cat /opt/homebrew/var/run/nginx-standby.pid)
```

### 6.3 Graceful Reload (Zero-Downtime Config Reload)
```bash
# Reload configuration without dropping active connections
sudo nginx -s reload -c /opt/homebrew/etc/nginx/standby.conf
```

### 6.4 Service Restart
```bash
# Restart daemon
sudo nginx -s stop -c /opt/homebrew/etc/nginx/standby.conf && sleep 1 && sudo nginx -c /opt/homebrew/etc/nginx/standby.conf
```

### 6.5 Runtime Status & Socket Inspection
```bash
# Check if ports 80 and 443 are listening
sudo lsof -nP -iTCP:80,443 -sTCP:LISTEN

# Verify running process IDs
ps aux | grep nginx-standby
```

---

## 7. Functional Verification Tests

Execute the following queries targeting the standby edge on Mac3 (`10.7.24.216`):

### 7.1 HTTP (Port 80) Request
```bash
curl -i http://app.teamX.test/api/status --resolve app.teamX.test:80:10.7.24.216
```
**Expected Headers & Payload:**
- `HTTP/1.1 200 OK`
- `Server: nginx/1.31.6`
- `X-Backend: A` or `X-Backend: B`
- `{"backend":"A|B","status":"ok"}`

### 7.2 HTTPS (Port 443) Trusted Request
```bash
curl -i https://app.teamX.test/api/status --resolve app.teamX.test:443:10.7.24.216
```
**Expected Headers & Payload:**
- `HTTP/1.1 200 OK`
- `X-Cache-Status: MISS` (first request) or `HIT` (subsequent request within 60s)
- `Cache-Control: public, max-age=60`
- Zero SSL certificate errors (validated without `-k`).

### 7.3 Cache Lifecycle Verification
```bash
# Request 1: Cache MISS
curl -s -D - https://app.teamX.test/api/status --resolve app.teamX.test:443:10.7.24.216 | grep -i "X-Cache-Status"
# Output: X-Cache-Status: MISS

# Request 2 (Immediate): Cache HIT
curl -s -D - https://app.teamX.test/api/status --resolve app.teamX.test:443:10.7.24.216 | grep -i "X-Cache-Status"
# Output: X-Cache-Status: HIT
```
