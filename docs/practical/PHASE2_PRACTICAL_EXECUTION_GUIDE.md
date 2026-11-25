# Phase 2 Practical Execution Guide: Private Network Service Platform

**Course:** Computer Networks Laboratory  
**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Target Path:** `docs/practical/PHASE2_PRACTICAL_EXECUTION_GUIDE.md`  
**Purpose:** Step-by-step practical demonstration and lab evaluation runbook for undergraduate team members and course faculty.

---

## Safety and Cleanup Rules (Read Before Running Any Commands!)

> [!CAUTION]
> **Mandatory Safety Instructions for Live Demonstration:**
> 1. **Restore Primary DNS:** If you stop primary `dnsmasq` on Mac1 during Section 5, you **must restart it** (`sudo brew services start dnsmasq`) before moving to subsequent tests.
> 2. **Restart Backend A:** If you stop Backend A on Mac3 during Section 8, you **must restart it** using `./scripts/start-backends.sh` so that both backends are active.
> 3. **Clean Up Practice Faults:** If you add `fault-test.teamX.test` to Mac1's `dnsmasq.conf` during Section 13, you **must remove the line and restart dnsmasq** so that Mac1 is not left in a broken state.
> 4. **Keep PF Rules Active:** Do not run `sudo pfctl -d` (disable firewall) during normal operation. The Packet Filter firewall must remain active to demonstrate backend protection.
> 5. **Protect TLS Keys:** Never edit, delete, or commit private key files (`app.teamX.test-key.pem` or `rootCA-key.pem`).
> 6. **Do Not Revert to Stale Resolver IPs:** Never set `/etc/resolver/teamX.test` to the obsolete IP `10.7.26.214`. It must point to Mac1's verified IP: `10.7.19.129`.

---

## Section 1 — Before Starting

### 1.1 Cluster Overview & Machine Demarcation
Our network consists of **three active network servers** and **one documentation workstation**:

| Machine | Team Member | IPv4 Address | Assigned Services | Primary Execution Role |
|---|---|---|---|---|
| **Mac1** | Rudraksh | `10.7.19.129` | Primary `dnsmasq` (port 53), test client (`curl`, `dig`, `nc`) | Executes all client-side tests, DNS queries, and verification loops. |
| **Mac2** | Kaustubh | `10.7.9.219` | Primary `nginx` (HTTP `8080`, HTTPS `8443`) | Executes authorized firewall checks and troubleshooting tests. |
| **Mac3** | Pratyush | `10.7.24.216` | Backend A (`3001`), Backend B (`3002`), Backup `dnsmasq` (`53`), Standby `nginx` (`80`/`443`), PF firewall | Manages application lifecycles, backup DNS, standby edge, and firewall rules. |
| **Mac4** | Bhargav | *N/A (Workstation)* | Documentation & evidence audit station | **NOT an active network server.** Runs zero server daemons; assists with documentation and evaluation logs. |

### 1.2 Network Requirements
- All laptops must be connected to the same private Wi-Fi network (`10.7.0.0/19`).
- Subnet mask: `255.255.224.0`
- Default gateway: `10.7.0.1`

### 1.3 Pre-Practical Checklist
Before calling the professor or running tests, confirm the following:
- [ ] Mac1, Mac2, and Mac3 are powered on and connected to the private Wi-Fi network.
- [ ] On Mac1: Primary `dnsmasq` is running (`sudo brew services list | grep dnsmasq`).
- [ ] On Mac2: Primary Nginx is running (`brew services list | grep nginx`).
- [ ] On Mac3: Backend A and B are running (`./scripts/check-backends.sh`).
- [ ] On Mac3: Backup `dnsmasq` is running (`sudo brew services list | grep dnsmasq`).
- [ ] On Mac3: Standby Nginx is running (`ps aux | grep '[n]ginx'`).
- [ ] On Mac3: PF firewall is enabled (`sudo pfctl -s info | grep Status`).
- [ ] Open a clean Terminal window on each Mac. Use `Cmd + +` to enlarge text for evaluator visibility.

---

## Section 2 — Network Architecture and Connectivity

### 2.1 Check Local IP Address on Mac1
Run this command in Terminal on **Mac1**:
```bash
ifconfig en0 | grep "inet "
```
- **What it does:** Displays the IPv4 address currently assigned to your Wi-Fi interface (`en0`).
- **Expected Output:**
  ```text
  inet 10.7.19.129 netmask 0xffffe000 broadcast 10.7.31.255
  ```
  *(Note: `0xffffe000` is the hexadecimal representation of `255.255.224.0`, which corresponds to `/19`.)*
- **What it proves:** Confirms Mac1 is on the private network with the correct IP address.

### 2.2 Ping Primary Edge (Mac2) from Mac1
Run this command in Terminal on **Mac1**:
```bash
ping -c 3 10.7.9.219
```
- **What it does:** Sends 3 ICMP echo request packets to Mac2 to test Layer 3 reachability.
- **Expected Output:**
  ```text
  PING 10.7.9.219 (10.7.9.219): 56 data bytes
  64 bytes from 10.7.9.219: icmp_seq=0 ttl=64 time=4.123 ms
  64 bytes from 10.7.9.219: icmp_seq=1 ttl=64 time=3.845 ms
  64 bytes from 10.7.9.219: icmp_seq=2 ttl=64 time=4.012 ms

  --- 10.7.9.219 ping statistics ---
  3 packets transmitted, 3 packets received, 0.0% packet loss
  ```
- **What it proves:** Confirms bidirectional network connectivity between Mac1 and Mac2 with 0% packet loss.

### 2.3 Ping Application Host (Mac3) from Mac1
Run this command in Terminal on **Mac1**:
```bash
ping -c 3 10.7.24.216
```
- **What it does:** Sends 3 ICMP echo request packets to Mac3.
- **Expected Output:**
  ```text
  3 packets transmitted, 3 packets received, 0.0% packet loss
  ```
- **What it proves:** Confirms network connectivity between Mac1 and Mac3.

---

## Section 3 — Primary and Backup DNS

### 3.1 Query Primary DNS Server Directly
Run this command in Terminal on **Mac1**:
```bash
dig @10.7.19.129 app.teamX.test
```
- **What it does:** Sends a DNS query for `app.teamX.test` directly to Mac1's `dnsmasq` service on port 53.
- **Expected Output:**
  ```text
  ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345
  ;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

  ;; ANSWER SECTION:
  app.teamX.test.    30    IN    A    10.7.24.216

  ;; SERVER: 10.7.19.129#53(10.7.19.129)
  ```
- **How to interpret the output:**
  - `status: NOERROR`: Resolution succeeded.
  - `flags: ... aa ...`: **Authoritative Answer**; Mac1 owns this private zone.
  - `A 10.7.24.216`: Resolves to Mac3 (migrated standby edge).
  - `30`: Time-To-Live in seconds.

### 3.2 Query Backup DNS Server Directly
Run this command in Terminal on **Mac1**:
```bash
dig @10.7.24.216 app.teamX.test
```
- **What it does:** Queries the secondary `dnsmasq` resolver running on Mac3.
- **Expected Output:**
  ```text
  ;; ANSWER SECTION:
  app.teamX.test.    30    IN    A    10.7.24.216

  ;; SERVER: 10.7.24.216#53(10.7.24.216)
  ```
- **What it proves:** Proves complete zone parity between Primary and Backup DNS servers.

### 3.3 Query Using Normal System DNS Resolution
Run this command in Terminal on **Mac1**:
```bash
dig app.teamX.test
```
- **What it does:** Sends a DNS query using macOS's default system resolver configuration without specifying `@IP`.
- **Expected Output:** Returns the exact same A record (`10.7.24.216`).

### 3.4 macOS Domain-Specific Resolver Inspection (`/etc/resolver/`)
macOS supports per-domain DNS configuration using files in `/etc/resolver/`.

Run these commands in Terminal on **Mac1**:
```bash
# 1. Inspect the teamX.test resolver file
cat /etc/resolver/teamX.test

# 2. Inspect active OS resolver routing table
scutil --dns | grep -A 5 "domain : teamX.test"

# 3. Test resolution using macOS native stub cache
dscacheutil -q host -a name app.teamX.test
```
- **Expected Output from `cat /etc/resolver/teamX.test`:**
  ```text
  nameserver 10.7.19.129
  ```
- **Expected Output from `dscacheutil`:**
  ```text
  name: app.teamX.test
  ip_address: 10.7.24.216
  ```
- **Important Technical Lesson:** If `/etc/resolver/teamX.test` contains an outdated IP (e.g. `10.7.26.214`), macOS will query the old IP and fail, completely ignoring your Wi-Fi DNS settings. Always ensure this file contains `nameserver 10.7.19.129`.

---

## Section 4 — DNS TTL (Time-To-Live)

Run these commands in Terminal on **Mac1**:
```bash
# Query Primary DNS for dedicated TTL record
dig @10.7.19.129 ttl-test.teamX.test +noall +answer

# Query Backup DNS for dedicated TTL record
dig @10.7.24.216 ttl-test.teamX.test +noall +answer
```
- **What it does:** Inspects the Answer section of the dedicated test record on both resolvers.
- **Expected Output:**
  ```text
  ttl-test.teamX.test.    30    IN    A    10.7.9.219
  ```
- **What it proves:** The second column shows `30`, verifying that `local-ttl=30` is configured and active in both `dnsmasq` instances.
- **Limitation Note:** This proves the **wire response TTL**. It does not prove client OS cache expiration behavior, because `dig` bypasses macOS's internal `mDNSResponder` cache.

---

## Section 5 — Backup DNS Failure Demonstration

In this practical, we simulate a failure of the primary DNS server on Mac1 and prove that the backup DNS server on Mac3 remains fully available.

### Step 5.1: Confirm Backup DNS is Healthy
On **Mac1**, test Mac3's backup DNS before injecting any failure:
```bash
dig @10.7.24.216 app.teamX.test +short
```
- **Expected Output:** `10.7.24.216`

### Step 5.2: Stop Primary DNS on Mac1
On **Mac1**, stop the `dnsmasq` service:
```bash
sudo brew services stop dnsmasq
```
- **Expected Output:** `Stopping `dnsmasq`... (success)`
- **Verify Port 53 is Closed on Mac1:**
  ```bash
  dig @10.7.19.129 app.teamX.test +time=2
  ```
  *(Output will show: `;; connection timed out; no servers could be reached`)*

### Step 5.3: Test Backup DNS Availability
On **Mac1**, query the backup resolver on Mac3 while primary DNS is stopped:
```bash
dig @10.7.24.216 app.teamX.test +noall +answer
```
- **Expected Output:**
  ```text
  app.teamX.test.    30    IN    A    10.7.24.216
  ```
- **What it proves:** Mac3 continues answering DNS queries independently, eliminating DNS as a single point of failure.

### Step 5.4: Cleanup — Restart Primary DNS on Mac1
> [!IMPORTANT]
> Always restart primary DNS immediately after completing this demonstration!

On **Mac1**, restart `dnsmasq`:
```bash
sudo brew services start dnsmasq
```
Verify resolution on Mac1:
```bash
dig @10.7.19.129 app.teamX.test +short
```
- **Expected Output:** `10.7.24.216` (Primary DNS is restored).

---

## Section 6 — Nginx Reverse Proxy

In this practical, we demonstrate Layer 7 reverse proxying through the primary Nginx edge on Mac2.

Run this command in Terminal on **Mac1**:
```bash
curl -i http://10.7.9.219:8080/
```
- **What it does:** Sends an HTTP/1.1 GET request to Mac2's primary Nginx edge on port `8080`.
- **Expected Output:**
  ```http
  HTTP/1.1 200 OK
  Server: nginx/1.31.6
  Date: ...
  Content-Type: application/json; charset=utf-8
  Content-Length: 64
  Connection: keep-alive
  X-Backend: A

  {"backend":"A","status":"ok","message":"Backend A is running"}
  ```
- **Request Flow Explained:**
  1. Mac1 connects to Mac2 (`10.7.9.219:8080`).
  2. Nginx on Mac2 terminates the connection and inspects the request.
  3. Nginx forwards the request across the LAN to Mac3 (`10.7.24.216:3001` or `:3002`).
  4. Backend A returns `X-Backend: A` and JSON payload.
  5. Nginx forwards the response back to Mac1.

---

## Section 7 — Load Balancing

In this practical, we verify that Nginx distributes incoming HTTP requests across both backend instances using round-robin scheduling.

Run this loop command in Terminal on **Mac1**:
```bash
for i in {1..10}; do
  curl -s http://10.7.9.219:8080/ | grep -o '"backend":"[AB]"'
done
```
- **What it does:** Sends 10 sequential HTTP requests to Nginx and extracts the responding backend identifier.
- **Expected Output:**
  ```text
  "backend":"A"
  "backend":"B"
  "backend":"A"
  "backend":"B"
  "backend":"A"
  "backend":"B"
  "backend":"A"
  "backend":"B"
  "backend":"A"
  "backend":"B"
  ```
- **What it proves:** Requests alternate cleanly between Backend A (port `3001`) and Backend B (port `3002`) in round-robin fashion (50% to A, 50% to B).

---

## Section 8 — Backend Failover

In this practical, we simulate a crash of Backend A and prove that Nginx automatically fails over all traffic to Backend B without returning errors to clients.

### Step 8.1: Check Baseline Normal Responses
On **Mac1**, send 5 requests to observe normal round-robin behavior:
```bash
for i in {1..5}; do
  curl -s http://10.7.9.219:8080/ | grep -o '"backend":"[AB]"'
done
```
*(Output will alternate between A and B.)*

### Step 8.2: Stop Backend A on Mac3
Switch to **Mac3**. Stop Backend A using the targeted PID lookup method:
```bash
# Inspect PID of Backend A (port 3001)
lsof -tiTCP:3001 -sTCP:LISTEN

# Stop Backend A gracefully
lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -TERM
```
- **Confirm port 3001 is closed on Mac3:**
  ```bash
  lsof -tiTCP:3001 -sTCP:LISTEN
  ```
  *(Output should be completely empty.)*

### Step 8.3: Test Failover from Mac1
Switch back to **Mac1**. Send 10 requests through Nginx:
```bash
for i in {1..10}; do
  curl -s http://10.7.9.219:8080/ | grep -o '"backend":"[AB]"'
done
```
- **Expected Output:**
  ```text
  "backend":"B"
  "backend":"B"
  "backend":"B"
  "backend":"B"
  "backend":"B"
  "backend":"B"
  "backend":"B"
  "backend":"B"
  "backend":"B"
  "backend":"B"
  ```
- **What it proves:** 10 out of 10 requests succeed cleanly with HTTP 200 OK, served exclusively by Backend B. Nginx masks the process crash completely from the user.

### Step 8.4: Cleanup — Restart Backend A on Mac3
> [!IMPORTANT]
> Restart Backend A immediately after completing this test!

Switch to **Mac3**. Run the repository startup script:
```bash
cd ~/CN-private-network-platform
./scripts/start-backends.sh
```
Verify both backends are running:
```bash
./scripts/check-backends.sh
```
*(Status should report: `ALL BACKENDS HEALTHY AND OPERATIONAL ✅`)*

---

## Section 9 — HTTPS and TLS

In this practical, we verify encrypted HTTPS communication and inspect the X.509 certificate hierarchy.

### 9.1 Test HTTPS Without Insecure Flags
Run this command in Terminal on **Mac1**:
```bash
curl -i https://app.teamX.test/
```
- **What it does:** Connects via HTTPS to `app.teamX.test` on port `443` (Mac3 standby edge) or port `8443` (Mac2 primary edge) without using the insecure `-k` flag.
- **Expected Output:**
  ```http
  HTTP/1.1 200 OK
  Server: nginx/1.31.6
  Content-Type: application/json; charset=utf-8
  X-Backend: A
  ```
- **What it proves:** The client trusts our private Certificate Authority (`mkcert`), validates the certificate chain, and establishes a secure TLS 1.3 session.

### 9.2 Inspect Certificate Chain with OpenSSL
Run this command in Terminal on **Mac1**:
```bash
openssl s_client -connect app.teamX.test:443 -servername app.teamX.test </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```
- **What it does:** Extracts the Subject, Issuer, and Validity dates from the live server certificate.
- **Expected Output:**
  ```text
  subject=O = mkcert development certificate, OU = ...
  issuer=O = mkcert development CA, OU = ...
  notBefore=Dec 30 ...
  notAfter=Dec 30 2028 ...
  ```
- **What it proves:** Proves that the server presents a valid certificate issued by our private CA, with Subject Alternative Name `DNS:app.teamX.test`, valid through 2028.

---

## Section 10 — HTTP Caching

In this practical, we observe Nginx's shared-memory proxy caching headers.

### 10.1 Send Sequential Requests to Observe Cache Status
Run these commands in Terminal on **Mac1**:
```bash
# First request (triggers cache population)
curl -s -D - -o /dev/null https://app.teamX.test/ | grep -iE 'cache|expires|etag|x-backend'

# Second request (within 60 seconds)
curl -s -D - -o /dev/null https://app.teamX.test/ | grep -iE 'cache|expires|etag|x-backend'
```
- **Expected Headers:**
  ```text
  Cache-Control: public, max-age=60
  ETag: W/"..."
  X-Cache-Status: MISS   <-- First request
  X-Cache-Status: HIT    <-- Second request (when caching is active)
  ```
- **Key Concepts Explained:**
  - `Cache-Control: public, max-age=60`: Tells clients and proxies that the response can be cached for up to 60 seconds.
  - `ETag`: An entity tag used for conditional cache revalidation (`If-None-Match`).
  - `X-Cache-Status: MISS`: The proxy did not have the item in memory; it fetched it from the backend.
  - `X-Cache-Status: HIT`: The proxy served the response directly from `/opt/homebrew/var/cache/nginx-standby` without querying the backend.

---

## Section 11 — PF Firewall

In this practical, we verify Layer 4 microsegmentation on Mac3 using macOS Packet Filter (`pf`).

### 11.1 Test Authorized Connection from Mac2
Open Terminal on **Mac2** (`10.7.9.219`). Probe Backend A and B on Mac3:
```bash
nc -vz 10.7.24.216 3001
nc -vz 10.7.24.216 3002
```
- **Expected Output:**
  ```text
  Connection to 10.7.24.216 port 3001 [tcp] succeeded!
  Connection to 10.7.24.216 port 3002 [tcp] succeeded!
  ```
- **Why it succeeded:** Mac2's IP matches Rule 1 (`pass in quick on en0 inet proto tcp from 10.7.9.219 to 10.7.24.216 port { 3001, 3002 } flags S/SA keep state`).

### 11.2 Test Unauthorized Connection from Mac1
Open Terminal on **Mac1** (`10.7.19.129`). Attempt to probe backend ports on Mac3:
```bash
nc -vz -w 5 10.7.24.216 3001
nc -vz -w 5 10.7.24.216 3002
```
- **Expected Output:**
  ```text
  nc: connectx to 10.7.24.216 port 3001 (tcp) failed: Operation timed out
  nc: connectx to 10.7.24.216 port 3002 (tcp) failed: Operation timed out
  ```
- **Why it failed:** Rule 2 (`block in quick on en0 inet proto tcp from any to 10.7.24.216 port { 3001, 3002 }`) silently dropped the incoming TCP SYN packet from Mac1.
- **What it proves:** Unauthorized clients cannot bypass Nginx to reach the backends directly.

---

## Section 12 — DNS-Based Edge Migration

In this practical, we verify disaster recovery edge migration where `app.teamX.test` is served by Mac3's standby Nginx edge on standard ports 80 and 443.

Run these commands in Terminal on **Mac1**:
```bash
# 1. Verify DNS points to Mac3 (Standby Edge)
dig app.teamX.test +short

# 2. Test HTTP on standard port 80
curl -i http://app.teamX.test/api/status

# 3. Test HTTPS on standard port 443 without -k
curl -i https://app.teamX.test/api/status
```
- **Expected Output:**
  - `dig` returns `10.7.24.216`.
  - HTTP returns `HTTP/1.1 200 OK` from `Server: nginx/1.31.6` on port 80.
  - HTTPS returns `HTTP/1.1 200 OK` with valid TLS on port 443.
- **Key Technical Note on Ports:** Mac3 standby Nginx runs on standard privileged web ports `80` and `443`. In contrast, Mac2 primary Nginx runs on unprivileged ports `8080` and `8443`.

---

## Section 13 — Faculty-Injected Troubleshooting Practice

During the final lab exam, the professor will inject a secret fault into our platform. In this section, we practice isolating an injected DNS fault using our 4-tier methodology.

### 13.1 Deliberately Inject the Practice Fault
On **Mac1**, temporarily add the faulty record to `/opt/homebrew/etc/dnsmasq.conf`:
```bash
echo "address=/fault-test.teamX.test/10.7.9.219" | sudo tee -a /opt/homebrew/etc/dnsmasq.conf
sudo brew services restart dnsmasq
```

### 13.2 Execute the 4-Tier Diagnostic Sequence

#### Tier 1: Query DNS on Both Resolvers
On **Mac1**:
```bash
dig @10.7.19.129 fault-test.teamX.test +short
dig @10.7.24.216 fault-test.teamX.test +noall +comments
```
- **Observation:** Mac1 returns `10.7.9.219` (`NOERROR`), but Mac3 returns `NXDOMAIN`.
- **Finding:** The DNS servers are desynchronized.

#### Tier 2: Probe TCP Reachability
On **Mac2**:
```bash
curl -v --connect-timeout 5 http://fault-test.teamX.test/
```
- **Observation:** `Failed to connect to fault-test.teamX.test port 80: Connection refused`.
- **Finding:** The host at `10.7.9.219` rejected connection on port 80.

#### Tier 3: Identify Intended Service Location
We check if the service is running on Mac3 (`10.7.24.216:80`):
```bash
curl -i http://10.7.24.216/
```
- **Observation:** Returns `HTTP/1.1 200 OK`.
- **Root Cause Isolated:** Standby Nginx is alive on Mac3 (`10.7.24.216`), but Mac1's DNS incorrectly pointed `fault-test` to Mac2 (`10.7.9.219`).

### 13.3 Diagnostic Decision Table

| Symptom / Command Output | Diagnostic Conclusion | Action to Take |
|---|---|---|
| `dig` returns `NXDOMAIN` or wrong IP | **DNS Layer Fault** | Inspect `dnsmasq.conf` on Mac1/Mac3; correct A record; reload daemon. |
| `nc` returns `Operation timed out` | **Firewall / Layer 3 Fault** | Inspect PF rules on destination (`pfctl -sr`); check routing table. |
| `nc` returns `Connection refused` | **Process / Transport Fault** | Check if service is running on target port (`lsof -i :PORT`); restart daemon. |
| `curl` returns `SSL certificate problem` | **TLS / Crypto Layer Fault** | Verify certificate validity, expiry, SAN list, and root CA trust store. |
| `curl` returns `HTTP 502 Bad Gateway` | **Upstream Backend Fault** | Edge proxy is alive, but all upstream backends are down or unreachable. |

### 13.4 Cleanup — Remove Practice Fault from Mac1
> [!IMPORTANT]
> Remove the practice fault immediately so Mac1 is clean!

On **Mac1**, run:
```bash
sudo sed -i '' '/fault-test\.teamX\.test/d' /opt/homebrew/etc/dnsmasq.conf
sudo brew services restart dnsmasq
dig @10.7.19.129 fault-test.teamX.test +noall +comments
```
*(Verify output shows status `NXDOMAIN`.)*

---

## Section 14 — Final Health Check

Before presenting to the professor, run this compact verification script on **Mac1** to confirm the entire cluster is green:

```bash
echo "=== 1. Primary DNS Check ==="
dig @10.7.19.129 app.teamX.test +short

echo "=== 2. Backup DNS Check ==="
dig @10.7.24.216 app.teamX.test +short

echo "=== 3. HTTP Edge Check (Port 80) ==="
curl -s -o /dev/null -w "%{http_code}\n" http://app.teamX.test/

echo "=== 4. HTTPS Edge Check (Port 443) ==="
curl -s -o /dev/null -w "%{http_code}\n" https://app.teamX.test/

echo "=== 5. Backend Response Check ==="
curl -s https://app.teamX.test/ | grep -o '"backend":"[AB]"'
```
**Expected Output:**
```text
=== 1. Primary DNS Check ===
10.7.24.216
=== 2. Backup DNS Check ===
10.7.24.216
=== 3. HTTP Edge Check (Port 80) ===
200
=== 4. HTTPS Edge Check (Port 443) ===
200
=== 5. Backend Response Check ===
"backend":"A" (or "backend":"B")
```

---

## Section 15 — Troubleshooting Reference

### Common Error Messages and Fixes

#### 1. `curl: (6) Could not resolve host: app.teamX.test`
- **Cause:** Client computer cannot reach the DNS server or has wrong DNS settings.
- **Fix:** Check `/etc/resolver/teamX.test` contains `nameserver 10.7.19.129`. Run `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`.

#### 2. `status: NXDOMAIN`
- **Cause:** Domain name is not defined in `dnsmasq.conf`.
- **Fix:** Verify `address=/app.teamX.test/10.7.24.216` exists in `/opt/homebrew/etc/dnsmasq.conf` on Mac1 and Mac3, then reload dnsmasq (`sudo killall -HUP dnsmasq`).

#### 3. `curl: (7) Failed to connect: Connection refused`
- **Cause:** The target machine is reachable, but no process is listening on that port.
- **Fix:** Verify daemon status using `lsof -nP -iTCP:PORT -sTCP:LISTEN` on the target machine and restart the service.

#### 4. `nc: connectx ... failed: Operation timed out`
- **Cause:** Packet was silently dropped by a firewall or routing table failure.
- **Fix:** Check PF firewall rules on Mac3 (`sudo pfctl -a cn_backend -sr`). Ensure Mac2's IP is allowed.

#### 5. `curl: (60) SSL certificate problem: unable to get local issuer certificate`
- **Cause:** Client machine does not trust the `mkcert` root CA.
- **Fix:** Export `rootCA.pem` from Mac2, copy to client, and run `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.pem`.

#### 6. Real Project Incident: macOS Resolver File Drift
- **Incident:** During earlier testing, `/etc/resolver/teamX.test` pointed to `10.7.26.214` (Mac1's old IP). When Mac1's IP changed to `10.7.19.129`, plain `curl` failed with `Could not resolve host` even though `dig @10.7.19.129` worked.
- **Resolution:** Updated `/etc/resolver/teamX.test` to `nameserver 10.7.19.129`, flushed system caches (`sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`), after which `dscacheutil` resolved `app.teamX.test` to `10.7.24.216` and HTTPS succeeded with HTTP 200.

---

## Section 16 — Viva Explanations (Quick-Fire Q&A)

### Q1: What does Extension A (Backup DNS) demonstrate?
- **Answer:** High availability in domain naming. If Mac1 crashes, Mac3's secondary `dnsmasq` resolver continues resolving `.teamX.test` records, eliminating DNS as a single point of failure.

### Q2: What does `local-ttl=30` do in Extension B?
- **Answer:** It sets the Time-To-Live in the DNS answer packet to 30 seconds, instructing clients and resolvers to refresh their cache every 30 seconds so that IP changes propagate quickly.

### Q3: Why do we need the PF firewall on Mac3 (Extension C)?
- **Answer:** Because backends bind to `0.0.0.0`, any device on Wi-Fi could bypass Nginx and access them directly. The PF firewall drops all connections to ports `3001` and `3002` unless they originate from the Nginx proxy (`10.7.9.219`).

### Q4: Why is the `quick` keyword important in PF rules?
- **Answer:** PF normally uses "last match wins". The `quick` keyword stops evaluation immediately when a rule matches, ensuring Mac2 is allowed through before the subsequent block rule can drop it.

### Q5: How does Backend Failover work in Extension D?
- **Answer:** Nginx monitors upstream responses. When Backend A is killed, the kernel returns TCP RST (`Connection refused`). Nginx intercepts this error, marks Backend A down for 10 seconds, and retries the request against Backend B without returning an error to the user.

### Q6: What is the main limitation of Backend Failover in our project?
- **Answer:** Both backends run on the same physical Mac (Mac3). This provides application process-level resiliency, but zero hardware redundancy. If Mac3 crashes, both backends go down together.

### Q7: What does Extension E (Edge Migration) prove?
- **Answer:** It proves that changing an authoritative DNS A record allows us to migrate production traffic from the primary edge (Mac2) to a warm standby edge (Mac3) without changing application code.

### Q8: What is the port asymmetry limitation in Extension E?
- **Answer:** Mac2 listens on high ports (`8080`/`8443`), while Mac3 standby Nginx listens on standard ports (`80`/`443`). DNS can only change IP addresses; it cannot remap ports. Reverting DNS to Mac2 does not restore service on port 443.

### Q9: How do we systematically troubleshoot a service failure (Extension F)?
- **Answer:** We test bottom-up across layers: DNS resolution first (`dig`), then TCP connectivity (`nc`), then TLS negotiation (`openssl`), and finally HTTP application status (`curl`).

### Q10: Why is Mac4 not listed as an active server?
- **Answer:** Mac4 was withdrawn from active server duties due to hardware constraints. It functions exclusively as a documentation and evidence workstation. Backend B was moved to Mac3.
