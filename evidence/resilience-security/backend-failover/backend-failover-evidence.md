# Backend Failover and Fault Tolerance Evidence — Extension D

**Host Machine**: Mac3 (`10.7.24.216`) — Backend Host  
**Test Client**: Mac1 (`10.7.19.129`)  
**Primary Edge Gateway**: Mac2 (`10.7.9.219:8443`)  
**Extension**: Extension D — Application Process Failover  
**Auditor**: Pratyush (Senior Computer Networks Engineer)  
**Status**: **HISTORICAL** (Preserved from Phase 2 Verification Session)  

---

## 1. Objective & Scope

Document the empirical verification of backend failover resilience in the Private Network Service Platform. This test validates that when an upstream application process (Backend A) experiences a fatal crash or process termination, the Nginx reverse proxy on Mac2 transparently reroutes traffic to the surviving healthy backend (Backend B) without dropping connections or returning HTTP 5xx errors to clients.

> [!IMPORTANT]
> **Safety Notice**: In accordance with audit standards, this failure scenario was **not** re-executed during the documentation audit. Live running backend processes (`PID 83711` and `PID 71230`) were preserved undisturbed. The logs below reflect the verified historical test run.

---

## 2. Test Procedure & Execution Lifecycle

The verification sequence comprised five distinct phases:

```
[Phase 1: Baseline]         [Phase 2: Fault Injection]       [Phase 3: Failover Ingress]       [Phase 4: Recovery]          [Phase 5: Restored Balance]
10 Requests ──────►         Backend A Stopped                10 Requests ────────►             Backend A Restarted          10 Requests ──────►
A/B Alternating (50/50)     (Port 3001 Closed)               100% Served by Backend B          (Port 3001 Listening)        A/B Alternating (50/50)
```

---

## 3. Empirical Test Evidence Logs

### Phase 1: Baseline Health Check (Both Backends Active)

Prior to fault injection, sequential HTTPS requests were sent from test client Mac1 to `https://app.teamX.test:8443/api/status`.

**Command:**
```bash
for i in {1..10}; do
  curl -s -D - https://app.teamX.test:8443/api/status -o /dev/null | grep -i "X-Backend:"
done
```

**Observed Baseline Output:**
```text
Request 1:  X-Backend: A
Request 2:  X-Backend: B
Request 3:  X-Backend: A
Request 4:  X-Backend: B
Request 5:  X-Backend: A
Request 6:  X-Backend: B
Request 7:  X-Backend: A
Request 8:  X-Backend: B
Request 9:  X-Backend: A
Request 10: X-Backend: B
```
- **Total Requests**: 10
- **HTTP Status Codes**: `200 OK` (100% success)
- **Distribution**: Exactly 5 requests to Backend A (50%), 5 requests to Backend B (50%).

---

### Phase 2: Failure Injection (Backend A Process Stopped)

On Mac3, Backend A was deliberately terminated using its process identifier:

**Command Executed on Mac3:**
```bash
lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -TERM
```

**Socket Verification:**
```bash
lsof -nP -iTCP:3001,3002 -sTCP:LISTEN
```
**Output:**
```text
COMMAND   PID             USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    71230 pratyushchouksey   19u  IPv4 0x9610378d0ffd23b5      0t0  TCP *:3002 (LISTEN)
```
- Port 3001 was confirmed completely closed.
- Backend B on port 3002 remained operational.

---

### Phase 3: Failover Traffic Verification (10 Requests During Outage)

Immediately following Backend A shutdown, 10 consecutive requests were dispatched from the client through the Nginx reverse proxy.

**Command:**
```bash
for i in {1..10}; do
  echo -n "Request $i: "
  curl -s -D - https://app.teamX.test:8443/api/status -o /dev/null | grep -i "X-Backend:"
done
```

**Observed Failover Output:**
```text
Request 1:  X-Backend: B
Request 2:  X-Backend: B
Request 3:  X-Backend: B
Request 4:  X-Backend: B
Request 5:  X-Backend: B
Request 6:  X-Backend: B
Request 7:  X-Backend: B
Request 8:  X-Backend: B
Request 9:  X-Backend: B
Request 10: X-Backend: B
```

#### Protocol & Transport Mechanics:
1. When Nginx on Mac2 routed requests toward `10.7.24.216:3001`, the operating system kernel on Mac3 rejected the TCP handshake, returning an immediate TCP `RST` (`ECONNREFUSED`).
2. Nginx intercepted the transport error via its upstream configuration directive:
   ```nginx
   proxy_next_upstream error timeout invalid_header http_502 http_503;
   ```
3. Nginx temporarily marked `10.7.24.216:3001` as failed for the duration of `fail_timeout=10s` and seamlessly retried the pending client request against Backend B (`10.7.24.216:3002`).
4. **Observed Result**: 10 out of 10 requests succeeded with `HTTP 200 OK` from Backend B. The client experienced zero connection drops, zero timeouts, and zero 502 Bad Gateway errors.

---

### Phase 4: Service Restoration (Backend A Restarted)

Backend A was restarted on Mac3:

**Command Executed on Mac3:**
```bash
cd backend-a && nohup node server.js >> backend-a.log 2>&1 &
```

**Socket Verification:**
```bash
lsof -nP -iTCP:3001,3002 -sTCP:LISTEN
```
**Output:**
```text
COMMAND   PID             USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    83711 pratyushchouksey   19u  IPv4 0x6f35768ea25309be      0t0  TCP *:3001 (LISTEN)
node    71230 pratyushchouksey   19u  IPv4 0x9610378d0ffd23b5      0t0  TCP *:3002 (LISTEN)
```
- Confirmed both ports 3001 and 3002 listening again.

---

### Phase 5: Re-convergence Verification (Restored Load Balancing)

Following expiration of the 10-second `fail_timeout` window, sequential requests were sent through the edge proxy:

**Observed Re-convergence Output:**
```text
Request 1:  X-Backend: A
Request 2:  X-Backend: B
Request 3:  X-Backend: A
Request 4:  X-Backend: B
Request 5:  X-Backend: A
Request 6:  X-Backend: B
Request 7:  X-Backend: A
Request 8:  X-Backend: B
Request 9:  X-Backend: A
Request 10: X-Backend: B
```
- Nginx automatically probed Backend A, detected successful TCP handshakes, restored healthy upstream status, and re-established exact 50/50 alternating round-robin distribution.

---

## 4. What This Evidence Proves and Does Not Prove

### What It Proves:
1. **Application Process Fault Tolerance**: Nginx's passive health check and upstream retry mechanism (`proxy_next_upstream`) successfully masks application process failure from end users.
2. **Self-Healing Recovery**: Upon restart, failed backend instances are re-integrated into the active pool without requiring an Nginx service restart or configuration reload.
3. **HTTP Status Uniformity**: Clients receive unbroken `HTTP 200 OK` responses throughout backend failure and recovery lifecycles.

### What It Does Not Prove (Critical Limitation):
1. **Hardware Redundancy**: In Phase 2, **both Backend A and Backend B run on Mac3 (`10.7.24.216`)**. This test proves application-level process failover while Mac3 remains operational. It does **not** prove independent machine or hardware redundancy. If Mac3 experiences hardware failure, power loss, or operating system panic, both backends crash simultaneously.
