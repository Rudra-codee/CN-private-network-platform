# Mac3 Backup DNS Server Configuration (dnsmasq)

This document provides the operational configuration, verification procedures, and service management instructions for the **Backup DNS Server** running on **Mac3** as part of the **Private Network Service Platform (Phase 2)**.

---

## 1. System Metadata & Host Role

| Attribute | Value |
|---|---|
| **Host Machine** | Mac3 |
| **Operating System** | macOS (Darwin ARM64) |
| **Physical IP Address** | `10.7.24.216` |
| **DNS Server Software** | dnsmasq |
| **Transport Protocol & Port** | UDP & TCP Port `53` |
| **Listening Interfaces** | Loopback (`127.0.0.1`) and LAN interface (`10.7.24.216`) |
| **Active Configuration Path** | `/opt/homebrew/etc/dnsmasq.conf` |
| **Repository Backup Path** | [`docs/configuration/mac3-backup-dns/dnsmasq.conf`](dnsmasq.conf) |

---

## 2. Configuration Analysis & Authoritative Records

The backup DNS daemon provides local name resolution for the private domain space `*.teamX.test` and forwards external Internet queries to public upstream resolvers.

### 2.1 Active Configuration File (`/opt/homebrew/etc/dnsmasq.conf`)

```ini
# Phase 2 - Backup DNS Resolver on Mac3

port=53
listen-address=127.0.0.1,10.7.24.216
bind-interfaces

# Internal application records
address=/app.teamX.test/10.7.24.216
address=/api.teamX.test/10.7.9.219
address=/ttl-test.teamX.test/10.7.9.219

# Forward external DNS queries
server=8.8.8.8
server=1.1.1.1
no-resolv

# DNS security and validation
domain-needed
bogus-priv

local-ttl=30
```

### 2.2 Authoritative Domain Mappings

| Domain Name | Record Type | Target IP Address | Architectural Target / Purpose |
|---|---|---|---|
| `app.teamX.test` | A | `10.7.24.216` | **Mac3 Standby Edge**: Routes web application traffic to Mac3's standby Nginx (ports 80 & 443). |
| `api.teamX.test` | A | `10.7.9.219` | **Mac2 Primary Edge**: Routes API traffic to Mac2's primary edge proxy. |
| `ttl-test.teamX.test` | A | `10.7.9.219` | **TTL Experimentation Record**: Dedicated hostname for testing DNS cache expiration and TTL timing. |

### 2.3 Directive Mechanics & Security Controls

- `port=53`: Binds to the standard IANA-assigned DNS port.
- `listen-address=127.0.0.1,10.7.24.216`: Restricts DNS query listeners strictly to local loopback and the assigned Wi-Fi LAN interface, preventing rogue interface binding.
- `bind-interfaces`: Instructs dnsmasq to bind sockets to the individual IP addresses specified by `listen-address` rather than wildcard `0.0.0.0`. This prevents socket binding conflicts with macOS native mDNS/Bonjour daemons.
- `server=8.8.8.8`, `server=1.1.1.1`: Designates Google Public DNS (`8.8.8.8`) and Cloudflare DNS (`1.1.1.1`) as external fallback upstream resolvers for non-local domains (e.g., `google.com`).
- `no-resolv`: Instructs dnsmasq **not** to read `/etc/resolv.conf`, ensuring upstream query forwarding strictly follows the designated servers.
- `domain-needed`: Prevents forwarding plain, unqualified names (names without a dot) upstream to public resolvers.
- `bogus-priv`: Drops reverse DNS lookups (PTR queries) for private RFC 1918 IP addresses (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) locally, returning NXDOMAIN instead of leaking internal IP ranges to the Internet.
- `local-ttl=30`: Enforces a 30-second Time-To-Live (TTL) on all locally served authoritative records. This allows rapid DNS cache invalidation during edge failover and testing.

---

## 3. Configuration Validation

Before starting or reloading `dnsmasq`, always validate configuration file syntax using the built-in syntax checker:

```bash
# Validate syntax of active Homebrew configuration
dnsmasq --test -C /opt/homebrew/etc/dnsmasq.conf
```

**Expected Successful Output:**
```text
dnsmasq: syntax check OK.
```

---

## 4. Service Management Lifecycle

`dnsmasq` requires superuser privileges to bind to privileged UDP/TCP port 53. It can be managed either via Homebrew services or directly as a standalone daemon.

### 4.1 Homebrew Service Management (Recommended)

```bash
# Start dnsmasq as root background service
sudo brew services start dnsmasq

# Restart dnsmasq (applies configuration changes)
sudo brew services restart dnsmasq

# Stop dnsmasq
sudo brew services stop dnsmasq

# Check service status
sudo brew services info dnsmasq
```

### 4.2 Standalone Daemon Management

```bash
# Start directly in foreground (useful for debugging)
sudo dnsmasq -C /opt/homebrew/etc/dnsmasq.conf --no-daemon

# Start as background daemon
sudo dnsmasq -C /opt/homebrew/etc/dnsmasq.conf

# Graceful termination
sudo killall dnsmasq

# Force termination (if unresponsive)
sudo pkill -9 dnsmasq
```

### 4.3 Runtime Listener Verification

Confirm that `dnsmasq` is actively bound to UDP and TCP port 53:

```bash
# Check UDP socket listener
sudo lsof -nP -iUDP:53

# Check TCP socket listener
sudo lsof -nP -iTCP:53 -sTCP:LISTEN
```

**Expected Listener Output:**
```text
COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
dnsmasq 84210 root    4u  IPv4 0xb63d6330243dd353      0t0  UDP 127.0.0.1:53
dnsmasq 84210 root    5u  IPv4 0xb63d6330243dd353      0t0  TCP 127.0.0.1:53 (LISTEN)
dnsmasq 84210 root    6u  IPv4 0xb63d6330243dd353      0t0  UDP 10.7.24.216:53
dnsmasq 84210 root    7u  IPv4 0xb63d6330243dd353      0t0  TCP 10.7.24.216:53 (LISTEN)
```

---

## 5. DNS Resolution Verification Tests

Execute the following `dig` queries locally on Mac3 or from any LAN client machine (e.g., Mac1, Mac2, Mac4) to verify resolution:

### 5.1 Test 1: Verify `app.teamX.test` (Standby Edge)
```bash
dig @10.7.24.216 app.teamX.test +noall +answer
```
**Expected Output:**
```text
app.teamX.test.     30      IN      A       10.7.24.216
```

### 5.2 Test 2: Verify `api.teamX.test` (Primary Edge)
```bash
dig @10.7.24.216 api.teamX.test +noall +answer
```
**Expected Output:**
```text
api.teamX.test.     30      IN      A       10.7.9.219
```

### 5.3 Test 3: Verify `ttl-test.teamX.test` & TTL Duration
```bash
dig @10.7.24.216 ttl-test.teamX.test +noall +answer
```
**Expected Output:**
```text
ttl-test.teamX.test. 30     IN      A       10.7.9.219
```
*Note: The second column confirms the 30-second TTL (`local-ttl=30`).*

### 5.4 Test 4: Verify External Recursive Forwarding
```bash
dig @10.7.24.216 google.com +noall +answer
```
**Expected Output:**
```text
google.com.         250     IN      A       142.250.x.x
```
*Confirms recursive upstream query resolution via `8.8.8.8` / `1.1.1.1`.*
