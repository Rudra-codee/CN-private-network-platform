# Task E — Server-Side Completion Report: HTTPS / TLS Termination on Mac 2

## 1. Objective

Implement server-side HTTPS and TLS termination on Mac 2 using `nginx` on TCP port 8443 for `https://app.teamX.test:8443`, enabling secure encrypted communication at the edge while maintaining existing HTTP port 8080 functionality and round-robin load balancing across Backend A and Backend B.

## 2. Mac 2 Role & Deployment Parameters

| Attribute | Value |
|---|---|
| Host Machine | Mac 2 |
| IPv4 Address | 10.7.9.11 |
| Architectural Role | Edge / Reverse Proxy / Load Balancer |
| Software Version | nginx 1.31.6 |
| Certificate Tooling | mkcert (development CA) |
| HTTPS Port | 8443/TCP (`listen 8443 ssl;`) |
| HTTP Port (Task D) | 8080/TCP (`listen 8080;`) |
| Target Hostname | `app.teamX.test` |
| Certificate Location | `/opt/homebrew/etc/nginx/certs/app.teamX.test.pem` |
| Key Location | `/opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem` |

## 3. Active nginx TLS Configuration

The active configuration file at [`configs/nginx/nginx.conf`](../../configs/nginx/nginx.conf) includes both the unencrypted HTTP block and the new HTTPS TLS block:

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

    upstream backend_pool {
        server 10.7.13.5:3001;
        server 10.7.29.244:3002;
    }

    # Task D - HTTP Listener
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

    # Task E - HTTPS / TLS Listener
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
        }
    }
}
```

## 4. TLS Certificate & SAN Verification

- **Hostname**: `app.teamX.test`
- **Certificate Tool**: `mkcert`
- **OpenSSL Verification**:
  ```bash
  openssl x509 -in /opt/homebrew/etc/nginx/certs/app.teamX.test.pem -noout -subject -issuer -ext subjectAltName
  ```
- **Verified Extensions**: Subject Alternative Name includes `DNS:app.teamX.test`.

## 5. TLS Termination Model

TLS negotiation occurs exclusively at the nginx edge on Mac 2. Upon successful handshake, nginx decrypts incoming HTTP/1.1 traffic and proxies it to `backend_pool` (`10.7.13.5:3001` / `10.7.29.244:3002`) over standard HTTP. TLS is not run directly on the backend servers.

## 6. Verification Summary

1. **Trusted HTTPS Request (No `curl -k`)**:
   `curl -i https://app.teamX.test:8443/api/status` returned `HTTP/1.1 200 OK` and valid response payload without certificate flags or insecure bypasses.
2. **Verbose Handshake Analysis (`curl -v`)**:
   Confirmed TLS 1.3 handshake negotiation (`TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256`), ClientHello, ServerHello, Certificate exchange, and Finished frames.
3. **HTTPS Load Balancing**:
   Executed 10 sequential HTTPS requests to `https://app.teamX.test:8443/api/status`, confirming strict 50/50 round-robin alternation across Backend A (`X-Backend: A`) and Backend B (`X-Backend: B`).
4. **Task D Regression Test**:
   `curl -i http://app.teamX.test:8080/api/status` confirmed unencrypted HTTP on port 8080 remains 100% operational.

## 7. Security & Key Exclusion Policy

> [!CAUTION]
> Private key files (`app.teamX.test-key.pem` and `rootCA-key.pem`) are strictly excluded from version control via `.gitignore`. Only configuration files, documentation, and public certificates/verification logs are committed.

## 8. Client Trust Setup for Mac 1 & Mac 4

To allow Mac 1 and Mac 4 client machines to validate HTTPS requests to Mac 2 without `-k`:
1. Obtain `rootCA.pem` from `mkcert -CAROOT` (`/Users/kaustubhhiwanj/Library/Application Support/mkcert/rootCA.pem`).
2. Transfer ONLY `rootCA.pem` to Mac 1 and Mac 4.
3. Import `rootCA.pem` into their respective system trust stores (`sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.pem`).

## 9. Task E Server-Side Completion Checklist

- [x] mkcert verified on Mac 2
- [x] TLS certificate generated for `app.teamX.test`
- [x] Certificate SAN verified (`DNS:app.teamX.test`)
- [x] Backup of Task D nginx config verified
- [x] HTTPS listener configured on port 8443
- [x] nginx configuration validated (`nginx -t`)
- [x] nginx restarted and bound to port 8443
- [x] HTTPS verified locally from Mac 2 without `curl -k`
- [x] Verbose TLS handshake verified (`curl -v`)
- [x] Task D HTTP port 8080 preserved and regression tested
- [x] 10-request HTTPS round-robin load balancing demonstrated
- [x] Private keys (`*-key.pem`, `rootCA-key.pem`) protected in `.gitignore`
- [x] Server-side documentation and verification artifacts created
