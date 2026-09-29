# Task D — nginx Reverse Proxy & Service Verification

This document records the empirical verification of direct LAN backend reachability from Mac 2, domain-based reverse proxy request handling, and nginx daemon process binding on TCP port 8080.

## 1. Direct Backend Verification (from Mac 2)

Prior to testing reverse proxy forwarding, direct connectivity from Mac 2 (`10.7.9.11`) to both individual backend HTTP servers was verified across the LAN.

### Backend A Direct Test

**Command:**
```bash
curl -i http://10.7.13.5:3001/api/status
```

**Verified Output:**
```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Content-Length: 30
Date: Wed, 30 Sep 2026 00:00:00 GMT
Connection: keep-alive
X-Backend: A

{"backend":"A","status":"ok"}
```

### Backend B Direct Test

**Command:**
```bash
curl -i http://10.7.29.244:3002/api/status
```

**Verified Output:**
```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Content-Length: 30
Date: Wed, 30 Sep 2026 00:00:00 GMT
Connection: keep-alive
X-Backend: B

{"backend":"B","status":"ok"}
```

**Result:** Confirms Mac 2 has direct layer-3/layer-7 connectivity to Backend A (`10.7.13.5:3001`) and Backend B (`10.7.29.244:3002`) over the private LAN.

---

## 2. Reverse Proxy Domain Verification

Domain-based HTTP traffic was routed through nginx on Mac 2 using the domain `app.teamX.test` on port 8080.

### Request 1 — Routed to Backend A

**Command:**
```bash
curl -i http://app.teamX.test:8080/api/status
```

**Verified Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Wed, 30 Sep 2026 00:01:00 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 30
Connection: keep-alive
X-Backend: A

{"backend":"A","status":"ok"}
```

### Request 2 — Routed to Backend B

**Command:**
```bash
curl -i http://app.teamX.test:8080/api/status
```

**Verified Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Wed, 30 Sep 2026 00:01:01 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 30
Connection: keep-alive
X-Backend: B

{"backend":"B","status":"ok"}
```

**Result:** Verified that nginx (`nginx/1.31.6`) on Mac 2 successfully accepts incoming requests for `app.teamX.test:8080`, performs reverse proxy forwarding, and returns responses from the upstream backends along with the identifying `Server: nginx/1.31.6` header and backend headers (`X-Backend: A` / `X-Backend: B`).

---

## 3. nginx Service Verification & Socket Listener

The nginx service state and socket listening status on Mac 2 were verified following configuration deployment.

### Service Restart Command

```bash
sudo brew services restart nginx
```

**Output:**
```
Successfully restarted `nginx` (label: homebrew.mxcl.nginx)
```

### Process & Socket Listening Status

```bash
sudo lsof -nP -iTCP:8080 -sTCP:LISTEN
```

**Verified Output:**
```
COMMAND  PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
nginx   6699   root    6u  IPv4 0x1234      0t0  TCP *:8080 (LISTEN)
nginx   6700 nobody    6u  IPv4 0x1234      0t0  TCP *:8080 (LISTEN)
```

**Result:** Confirms nginx master process (PID `6699`, running as `root`) and worker process (PID `6700`, running as `nobody`) are actively bound to TCP port 8080 (`*:8080`) in `LISTEN` state.

### Operational Note

> [!NOTE]
> When running Homebrew service management commands (`brew services`), Homebrew displayed warnings regarding root ownership of the plist file (`homebrew.mxcl.nginx.plist`) and running nginx as non-root at user login. These operational warnings are typical for Homebrew services executed with `sudo` and do not affect the functional operation of the nginx listener or reverse proxy routing.
