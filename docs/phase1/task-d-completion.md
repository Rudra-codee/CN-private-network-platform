# Task D — Completion Report: Edge Reverse Proxy + Load Balancer

## 1. Objective

Deploy and verify an edge reverse proxy and round-robin load balancer on Mac 2 using `nginx` to accept HTTP requests on TCP port 8080 for `app.teamX.test` and balance traffic between Backend A (Mac 3) and Backend B (Mac 4).

## 2. Mac 2 Role

Mac 2 serves as the single edge entry point for all client web traffic within the platform architecture.

| Attribute | Value |
|---|---|
| Host Machine | Mac 2 |
| IP Address | 10.7.9.11 |
| Architectural Role | Edge / Reverse Proxy / Load Balancer |
| Software Version | nginx 1.31.6 |
| Listener Protocol | HTTP |
| Listener Port | 8080/TCP |
| Configured Domain | `app.teamX.test` |

## 3. nginx Configuration

The active configuration file is stored at [`configs/nginx/nginx.conf`](../../configs/nginx/nginx.conf):

```nginx
events {
    worker_connections 1024;
}

http {
    upstream backend_pool {
        server 10.7.13.5:3001;
        server 10.7.29.244:3002;
    }

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
}
```

## 4. Backend Upstream Pool

The reverse proxy delegates HTTP request execution to two backend application servers registered in `backend_pool`:

| Backend Service | Host Machine | IPv4 Address | Port | Identification Header |
|---|---|---|---|---|
| Backend A | Mac 3 | 10.7.13.5 | 3001 | `X-Backend: A` |
| Backend B | Mac 4 | 10.7.29.244 | 3002 | `X-Backend: B` |

## 5. Reverse Proxy Behavior

The edge proxy decouples clients from internal backend infrastructure:
- **Client Isolation**: The client does not need to know Backend A (`10.7.13.5:3001`) or Backend B (`10.7.29.244:3002`) IP addresses or ports.
- **Edge Routing**: The client sends requests solely to `app.teamX.test:8080` (resolving to Mac 2 at `10.7.9.11`). nginx intercepts the incoming HTTP connection and proxies the request to an upstream server in `backend_pool`.
- **Header Propagation**: Standard HTTP forwarding headers (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) are injected into the upstream request.

## 6. Domain-Based Access

Private domain resolution maps `app.teamX.test` to Mac 2 (`10.7.9.11`). When clients query `http://app.teamX.test:8080/api/status`, nginx matches the request against `server_name app.teamX.test;` and executes the `location /` proxy rules.

## 7. Round-Robin Load Balancing

nginx balances incoming HTTP traffic across Backend A and Backend B using standard round-robin selection. A sequential 10-request verification loop produced strict 50/50 alternating responses (`A` → `B` → `A` → `B` ...):

```
Request 1: X-Backend: A
Request 2: X-Backend: B
Request 3: X-Backend: A
Request 4: X-Backend: B
Request 5: X-Backend: A
Request 6: X-Backend: B
Request 7: X-Backend: A
Request 8: X-Backend: B
Request 9: X-Backend: A
Request 10: X-Backend: B
```

## 8. Direct Backend Verification

Direct LAN connectivity from Mac 2 to both backend nodes was verified prior to testing reverse proxy routing:

- **Backend A Direct Test**: `curl -i http://10.7.13.5:3001/api/status` returned `HTTP/1.1 200 OK` and `X-Backend: A`.
- **Backend B Direct Test**: `curl -i http://10.7.29.244:3002/api/status` returned `HTTP/1.1 200 OK` and `X-Backend: B`.

This confirms that Mac 2 can directly reach both backend services across the LAN network.

## 9. nginx Service Verification

The nginx service on Mac 2 was restarted and verified using Homebrew service management:

- **Restart Command**: `sudo brew services restart nginx` (succeeded).
- **Socket Listener Verification**: `sudo lsof -nP -iTCP:8080 -sTCP:LISTEN` confirmed `nginx` master (PID 6699) and worker (PID 6700) processes listening on TCP port 8080 (`*:8080`).
- **Operational Note**: Homebrew CLI emitted standard warnings regarding root plist ownership and background user execution; these do not impact the active port 8080 HTTP listener.

## 10. Evidence / Results

Verification artifacts and evidence logs are documented in the following repository files:

| Artifact | File Path |
|---|---|
| nginx Active Configuration | [`configs/nginx/nginx.conf`](../../configs/nginx/nginx.conf) |
| Architecture & Design Specification | [`docs/architecture/nginx-architecture.md`](../architecture/nginx-architecture.md) |
| Direct Backend & Proxy Verification | [`evidence/04-nginx/nginx-verification.md`](../../evidence/04-nginx/nginx-verification.md) |
| Load Balancing Test Output Log | [`evidence/04-nginx/load-balancing.md`](../../evidence/04-nginx/load-balancing.md) |

## 11. Task D Completion Status

| Requirement | Status |
|---|---|
| nginx 1.31.6 installed on Mac 2 | ✅ Complete |
| nginx configuration created (`configs/nginx/nginx.conf`) | ✅ Complete |
| nginx configuration validated | ✅ Complete |
| nginx listening on port 8080 | ✅ Complete |
| Direct Backend A (`10.7.13.5:3001`) reachable from Mac 2 | ✅ Complete |
| Direct Backend B (`10.7.29.244:3002`) reachable from Mac 2 | ✅ Complete |
| Reverse proxy routing working | ✅ Complete |
| `app.teamX.test` reaches nginx | ✅ Complete |
| Backend A returned through proxy (`X-Backend: A`) | ✅ Complete |
| Backend B returned through proxy (`X-Backend: B`) | ✅ Complete |
| Round-robin behavior demonstrated (10/10 test) | ✅ Complete |
| Evidence documented | ✅ Complete |

## 12. Boundary Between Task D and Task E

> [!IMPORTANT]
> Task D delivers unencrypted **HTTP reverse proxying and round-robin load balancing on port 8080**.
>
> The following items are explicitly **OUT OF SCOPE** for Task D and belong to subsequent tasks:
> - **Task E**: HTTPS / TLS certificate generation, TLS handshake, and port 443 termination.
> - **Task F**: HTTP caching (`Cache-Control`, `304 Not Modified`).
> - **Task G**: Wireshark packet capture trace analysis.
> - **Task H**: Failure injection testing (backend shutdown, network drop).
