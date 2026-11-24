# DNS-Based Edge Migration Evidence — Extension E

**Target Domain**: `app.teamX.test`  
**Original Primary Edge**: Mac2 (`10.7.9.219`)  
**Standby Migrated Edge**: Mac3 (`10.7.24.216`)  
**Extension**: Extension E — Edge Disaster Recovery & Migration  
**Auditor**: Pratyush (Senior Computer Networks Engineer)  
**Configuration Status**: **VERIFIED** on Disk  
**Cutover Test Status**: **HISTORICAL** (Demonstrated in Phase 2 Testing)  

---

## 1. Migration Architecture & Rationale

Extension E implements an edge gateway cutover procedure for the primary application domain `app.teamX.test`. When the primary edge gateway on Mac2 undergoes planned maintenance or suffers an edge-level failure, traffic is rerouted to the standby edge gateway hosted on Mac3.

### Edge Tier Comparison Matrix:

| Feature / Attribute | Primary Edge (Mac2) | Standby Edge (Mac3) |
|---|---|---|
| **Host IP** | `10.7.9.219` | `10.7.24.216` |
| **HTTP Port** | `8080/TCP` (Unprivileged) | **`80/TCP`** (Standard Privileged) |
| **HTTPS Port** | `8443/TCP` (Unprivileged) | **`443/TCP`** (Standard Privileged) |
| **Upstream Pool Target** | `10.7.24.216:3001` & `3002` (LAN) | `127.0.0.1:3001` & `3002` (Loopback IPC) |
| **Active Config File** | `/opt/homebrew/etc/nginx/nginx.conf` | `/opt/homebrew/etc/nginx/standby.conf` |
| **TLS Certificate Files** | `/opt/homebrew/etc/nginx/certs/` | `/opt/homebrew/etc/nginx/standby-certs/` |

---

## 2. DNS Record Transition Evidence

The edge migration is triggered at the naming layer by updating the authoritative `A` record in `dnsmasq`:

### 2.1 Pre-Migration State
- **Primary DNS (Mac1: `10.7.19.129`)**:
  ```ini
  address=/app.teamX.test/10.7.9.219
  address=/api.teamX.test/10.7.9.219
  ```
- **Client Resolution**: Queries for `app.teamX.test` resolved to Mac2 (`10.7.9.219`). Traffic entered ports 8080 and 8443.

### 2.2 Post-Migration State (Cutover to Standby Edge)
- **Primary DNS (Mac1: `10.7.19.129`)** and **Backup DNS (Mac3: `10.7.24.216`)**:
  ```ini
  address=/app.teamX.test/10.7.24.216
  address=/api.teamX.test/10.7.9.219
  address=/ttl-test.teamX.test/10.7.9.219
  local-ttl=30
  ```
- **Client Resolution**: Following the 30-second TTL expiration (`local-ttl=30`), queries for `app.teamX.test` resolve to Mac3 (`10.7.24.216`).

---

## 3. Standby Nginx Configuration & TLS Setup

### 3.1 Standby Configuration (`/opt/homebrew/etc/nginx/standby.conf`)

The configuration file was verified on Mac3 at `/opt/homebrew/etc/nginx/standby.conf`:

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

### 3.2 Replicated TLS Certificate Inspection

The standby Nginx server references replicated certificates verified on Mac3:
- **Production Path**: `/opt/homebrew/etc/nginx/standby-certs/app.teamX.test.pem`
- **Staging Path**: `/Users/pratyushchouksey/standby-certs/app.teamX.test.pem`

#### OpenSSL Certificate Validation Output:
```bash
openssl x509 -in /opt/homebrew/etc/nginx/standby-certs/app.teamX.test.pem -noout -subject -issuer -dates -ext subjectAltName
```
**Verified Attributes:**
```text
subject=O=mkcert development certificate, OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)
issuer=O=mkcert development CA, OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj), CN=mkcert kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)
notBefore=Sep 29 19:39:57 2026 GMT
notAfter=Dec 29 19:39:57 2028 GMT
X509v3 Subject Alternative Name: 
    DNS:app.teamX.test
```
- Certificate SAN matches `app.teamX.test` exactly.
- Validated against the root CA trusted in the macOS System Keychain.

---

## 4. Historical Test Execution & Evidence Logs

During the Phase 2 demonstration, the standby edge was activated and verified:

### 4.1 Standby Nginx Syntax Validation
```bash
sudo nginx -t -c /opt/homebrew/etc/nginx/standby.conf
```
**Output:**
```text
nginx: the configuration file /opt/homebrew/etc/nginx/standby.conf syntax is ok
nginx: configuration file /opt/homebrew/etc/nginx/standby.conf test is successful
```

---

### 4.2 Local HTTP and HTTPS Probes (Mac3)
```bash
# Standard HTTP (Port 80)
curl -i http://127.0.0.1/api/status -H "Host: app.teamX.test"

# Standard HTTPS (Port 443)
curl -i https://127.0.0.1/api/status -H "Host: app.teamX.test"
```
**Output Highlights:**
- `HTTP/1.1 200 OK`
- `Server: nginx/1.31.6`
- `X-Backend: A` or `X-Backend: B`
- Cache header: `X-Cache-Status: MISS` (initial) / `HIT` (subsequent)

---

### 4.3 Cross-Machine Ingress from Primary Edge (Mac2 $\rightarrow$ Mac3)
```bash
# Querying Mac3 Standby Edge from Mac2
curl -i http://10.7.24.216/api/status -H "Host: app.teamX.test"
curl -i https://10.7.24.216/api/status -H "Host: app.teamX.test"
```
**Output Highlights:**
- Confirmed that Mac2 can reach the standby edge on ports 80 and 443 across the physical LAN.

---

### 4.4 Fully Qualified Domain Name (FQDN) Verification without `-k`
```bash
curl -i https://app.teamX.test/api/status
```
**Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Tue, 24 Nov 2026 19:40:15 GMT
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
- Fully validated over standard HTTPS (port 443) without `-k` bypass flags.

---

## 5. Current Runtime Audit & Status Distinction

| Component | Status | Observation / Verification Details |
|---|---|---|
| **Standby Nginx Configuration** | **VERIFIED** | `/opt/homebrew/etc/nginx/standby.conf` syntax check verified. |
| **Standby TLS Certificates** | **VERIFIED** | `/opt/homebrew/etc/nginx/standby-certs/` certificates validated via OpenSSL. |
| **Backup DNS Configuration** | **VERIFIED** | `/opt/homebrew/etc/dnsmasq.conf` maps `app.teamX.test` to `10.7.24.216`. |
| **Active Sockets 80 / 443** | **HISTORICAL** | Sockets 80 and 443 are currently **idle/stopped** on Mac3. The cutover demonstration was conducted historically during Phase 2 testing. |

---

## 6. Critical Operational Limitations

### 6.1 Port Asymmetry & Rollback Limitation
- **Mac3 Standby Edge**: Listens on standard ports **80** (HTTP) and **443** (HTTPS).
- **Mac2 Primary Edge**: Listens on high non-standard ports **8080** (HTTP) and **8443** (HTTPS).
- **Rollback Consequence**: If the DNS record for `app.teamX.test` is reverted from `10.7.24.216` back to `10.7.9.219`, standard client requests (`http://app.teamX.test` or `https://app.teamX.test`) will **fail with connection refused**. Mac2 does not listen on ports 80/443; clients must explicitly specify ports `8080` and `8443`.

### 6.2 Triple Co-Location Single Point of Failure (SPOF)
During standby edge operation on Mac3:
- Standby Nginx Gateway (ports 80 & 443)
- Application Backend A (port 3001)
- Application Backend B (port 3002)
- Backup DNS Resolver (port 53)

All four critical components reside on **Mac3 (`10.7.24.216`)**. A physical hardware crash or network interface loss on Mac3 eliminates both ingress routing and application execution simultaneously.
