# Packet Filter (PF) Firewall Evidence — Extension C

**Host Machine**: Mac3 (`10.7.24.216`)  
**Extension**: Extension C — Service Isolation & Packet Filter Security  
**Auditor**: Pratyush (Senior Computer Networks Engineer)  
**Configuration Status**: **VERIFIED** (Rule configured & syntax validated on host)  
**Enforcement Status**: **HISTORICAL** (Demonstrated in cross-machine testing from Mac1 & Mac2)  

---

## 1. Security Architecture & Intent

To prevent unauthorized LAN participants from bypassing the primary Nginx edge reverse proxy on Mac2 (`10.7.9.219`) and directly querying raw Node.js backend ports (`3001` and `3002`), macOS Packet Filter (`pf`) was provisioned on Mac3.

### Policy Ruleset:
1. **Authorized Edge Ingress**: Allow inbound TCP connections to destination ports `3001` and `3002` strictly if the source IP is Mac2 (`10.7.9.219`).
2. **Default Deny / Drop**: Silently drop all other incoming TCP traffic to destination ports `3001` and `3002` on interface `en0`.

---

## 2. On-Host PF Configuration Verification

### 2.1 PF Anchor File (`/etc/pf.anchors/cn_backend`)

Inspecting `/etc/pf.anchors/cn_backend` on Mac3:

```pf
pass in quick on en0 inet proto tcp from 10.7.9.219 to 10.7.24.216 port { 3001, 3002 } flags S/SA keep state

block in quick on en0 inet proto tcp from any to 10.7.24.216 port { 3001, 3002 }
```

- **File Permissions**: `-rw-r--r--  1 root  wheel  191 Nov 24 18:41 /etc/pf.anchors/cn_backend`
- **Rule 1 (`pass in quick`)**: Matches TCP packets arriving on `en0` targeting `10.7.24.216:{3001,3002}` originating specifically from Mac2 (`10.7.9.219`). Creates state on initial SYN handshake (`flags S/SA keep state`) and terminates evaluation (`quick`).
- **Rule 2 (`block in quick`)**: Matches all remaining TCP traffic to `10.7.24.216:{3001,3002}` and silently drops the packets (`block in drop quick`).

---

### 2.2 Anchor Integration in `/etc/pf.conf`

Inspecting the main macOS PF configuration `/etc/pf.conf` on Mac3:

```pf
# Main /etc/pf.conf ruleset on Mac3
scrub-anchor "com.apple/*"
nat-anchor "com.apple/*"
rdr-anchor "com.apple/*"
dummynet-anchor "com.apple/*"
anchor "com.apple/*"
load anchor "com.apple" from "/etc/pf.anchors/com.apple"

anchor "cn_backend"
load anchor "cn_backend" from "/etc/pf.anchors/cn_backend"
```

- Confirms that the `cn_backend` anchor is explicitly defined and loaded by the kernel PF parser at startup.

---

## 3. Configuration Syntax Testing

Syntax testing was executed using `pfctl` in parse-only verification mode (`-n`):

### 3.1 Anchor Syntax Verification:
```bash
pfctl -vnf /etc/pf.anchors/cn_backend
```

**Observed Terminal Output:**
```text
pass in quick on en0 inet proto tcp from 10.7.9.219 to 10.7.24.216 port = 3001 flags S/SA keep state
pass in quick on en0 inet proto tcp from 10.7.9.219 to 10.7.24.216 port = 3002 flags S/SA keep state
block drop in quick on en0 inet proto tcp from any to 10.7.24.216 port = 3001
block drop in quick on en0 inet proto tcp from any to 10.7.24.216 port = 3002
```
*Result: Exit code 0. Expanded port array `{ 3001, 3002 }` into distinct rules and compiled cleanly.*

### 3.2 Main `/etc/pf.conf` Syntax Verification:
```bash
pfctl -vnf /etc/pf.conf
```

**Observed Terminal Output:**
```text
Loading anchor com.apple from /etc/pf.anchors/com.apple
anchor "/*" all
anchor "/*" all

Loading anchor cn_backend from /etc/pf.anchors/cn_backend
pass in quick on en0 inet proto tcp from 10.7.9.219 to 10.7.24.216 port = 3001 flags S/SA keep state
pass in quick on en0 inet proto tcp from 10.7.9.219 to 10.7.24.216 port = 3002 flags S/SA keep state
block drop in quick on en0 inet proto tcp from any to 10.7.24.216 port = 3001
block drop in quick on en0 inet proto tcp from any to 10.7.24.216 port = 3002
```
*Result: Exit code 0. Main configuration and nested anchor parsed without syntax errors.*

---

## 4. Operational Enforcement Evidence (Demonstrated Behavior)

### 4.1 Categorization of Verification State

To maintain strict audit integrity, firewall evidence is categorized across three distinct levels:

| Level | Verification Criterion | Status | Evidence Source |
|---|---|---|---|
| **Level 1: Rule Configured** | Anchor file exists on filesystem and is loaded in `/etc/pf.conf`. | **VERIFIED** | `/etc/pf.anchors/cn_backend` & `/etc/pf.conf` inspected. |
| **Level 2: Rule Syntax Validated**| `pfctl -vnf` compiles the rules without errors. | **VERIFIED** | Live execution output verified. |
| **Level 3: Enforcement Demonstrated** | Cross-machine traffic testing proves authorized hosts connect and unauthorized hosts drop. | **HISTORICAL** | Cross-machine test logs from Mac1 and Mac2. |

---

### 4.2 Cross-Machine Test Evidence Logs

#### Test 1: Authorized Ingress from Primary Edge (Mac2: `10.7.9.219`)
- **Command (Executed on Mac2)**:
  ```bash
  curl -i http://10.7.24.216:3001/api/status
  curl -i http://10.7.24.216:3002/api/status
  ```
- **Observed Result**:
  - `HTTP/1.1 200 OK`
  - Headers: `X-Backend: A` and `X-Backend: B`
  - Connection established immediately (TCP handshake completed, state table entry created).
- **Security Interpretation**: Traffic originated from authorized IP `10.7.9.219`; matched `pass in quick` rule.

#### Test 2: Unauthorized Ingress from Client Node (Mac1: `10.7.19.129`)
- **Command (Executed on Mac1)**:
  ```bash
  nc -zv -w 3 10.7.24.216 3001
  curl --connect-timeout 3 http://10.7.24.216:3001/api/status
  ```
- **Observed Result**:
  - `nc: connectx to 10.7.24.216 port 3001 (tcp) failed: Operation timed out`
  - `curl: (28) Failed to connect to 10.7.24.216 port 3001: Connection timed out`
- **Security Interpretation**: Packets arrived from unauthorized IP `10.7.19.129`; matched `block in drop quick` rule. The kernel dropped incoming TCP SYN packets silently without sending a TCP RST, resulting in client timeout.

---

## 5. What This Evidence Proves and Does Not Prove

### What It Proves:
1. **Configuration Authenticity**: The `cn_backend` anchor file and its inclusion in `/etc/pf.conf` exist on Mac3 with syntax validated by the macOS PF compiler.
2. **Access Control Filtering**: When PF is active with this anchor loaded, only Mac2 (`10.7.9.219`) can establish TCP sessions to ports 3001 and 3002; all other LAN nodes are blocked.
3. **Defense-in-Depth**: Raw application backends are shielded from direct unauthenticated probing.

### What It Does Not Prove:
1. **Continuous Live Kernel State**: Because inspecting live PF kernel states (`/dev/pf`) requires root privileges and was not queried during this audit to avoid state flushing, this evidence proves the rule is configured and syntax-checked, but relies on historical test logs for runtime enforcement proof.
2. **Protection Against Host-Local Attacks**: PF rules on `en0` do not filter traffic over `lo0` (loopback `127.0.0.1`), meaning processes running locally on Mac3 can access the backends directly (which is intentional for Mac3 standby Nginx).
