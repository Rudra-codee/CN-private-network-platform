# Mac 1 — Primary DNS Server Configuration

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** Primary DNS Service Configuration, Validation, and Operations Reference  
**Target Path:** `docs/configuration/mac1-primary-dns/README.md`  
**Classification:** Operational Configuration Reference  
**Author:** Senior Linux/macOS DNS Administrator & Technical Documentation Engineer  

---

## 1. Node Profile

| Property | Value |
|---|---|
| Machine Identifier | Mac 1 |
| Operating System | macOS (Apple Silicon / arm64) |
| Phase 2 LAN IPv4 Address | `10.7.19.129` |
| Phase 1 LAN IPv4 Address | `10.7.17.222` *(superseded — DHCP reassignment)* |
| Network Interface | `en0` (Wi-Fi) |
| Primary Role | Authoritative Private DNS Server |
| Secondary Role | Test Client (curl, dig, Wireshark) |
| DNS Software | `dnsmasq` v2.93 (Homebrew) |
| Listening Port | `53` / UDP & TCP |

> [!NOTE]
> Mac 1's IP address changed from `10.7.17.222` (Phase 1) to `10.7.19.129` (Phase 2) due to DHCP lease expiration and reallocation on the private Wi-Fi router. The active runtime configuration and all Phase 2 operations use `10.7.19.129`.

---

## 2. Configuration File Location

### 2.1 Active Runtime Configuration

The dnsmasq configuration file managed by Homebrew and used for Phase 2 operations is:

```
/opt/homebrew/etc/dnsmasq.conf
```

This is the **definitive active configuration** file. All Phase 2 record changes (Extensions A, B, and E) were applied directly to this file.

### 2.2 Historical Backup Files (for reference only)

The following backup copies were preserved on disk at the time of inspection. They are **not loaded by the running daemon** and are provided for change-history reference only.

| File | Timestamp | Description |
|---|---|---|
| `/opt/homebrew/etc/dnsmasq.conf.backup` | 29 Sep 14:37 | Homebrew default template (all directives commented out) |
| `/opt/homebrew/etc/dnsmasq.conf.phase1-backup` | 24 Nov 17:19 | Phase 1 configuration (`10.7.26.214`, single-record state) |
| `/opt/homebrew/etc/dnsmasq.conf.pre-edge-migration` | 24 Nov 19:10 | Pre-Extension E state (`app.teamX.test` → Mac 2 `10.7.9.219`) |
| `/opt/homebrew/etc/dnsmasq.conf.pre-extension-f` | 24 Nov 19:24 | Pre-Extension F state (matches Phase 2 post-migration, no `fault-test` record) |

### 2.3 Repository Configuration Template

A Phase 1 configuration template is committed in the project repository at:

```
configs/dns/dnsmasq.conf
```

> [!IMPORTANT]
> The repository template is **not** the active configuration. It reflects the original Phase 1 IP assignments (`10.7.17.222`, records pointing to `10.7.9.11`) and has not been updated to reflect Phase 2 operational values. See Section 7 for the full discrepancy analysis.

### 2.4 Drop-in Directory

```
/opt/homebrew/etc/dnsmasq.d/
```

This directory exists but contains **no `.conf` drop-in files** relevant to the project. Only system-generated subdirectories (`dhcpc/`, `ppp/`) are present, neither of which is loaded by the project dnsmasq instance.

---

## 3. Active Configuration — Verified Directives

The following directives were read directly from `/opt/homebrew/etc/dnsmasq.conf` at the time of inspection (2026-11-24).

```ini
# Computer Networks Project - Private DNS
# Mac1 DNS Server

listen-address=127.0.0.1,10.7.19.129
bind-interfaces

port=53

# Private project domains point to Mac2 (Nginx Edge)
address=/app.teamX.test/10.7.24.216
address=/api.teamX.test/10.7.9.219
address=/ttl-test.teamX.test/10.7.9.219

# Forward external DNS queries
server=8.8.8.8
server=1.1.1.1
no-resolv

domain-needed
bogus-priv

local-ttl=30
address=/fault-test.teamX.test/10.7.9.219
```

---

## 4. DNS Records — Purpose and Verification

### 4.1 Authoritative Zone Records Table

| FQDN | Record Type | Target IP | Target Node | Purpose |
|---|---|---|---|---|
| `app.teamX.test` | `A` | `10.7.24.216` | Mac 3 (Standby/Migrated Edge) | Application entry point; TLS-terminated by nginx on Mac 3. Set during Extension E edge migration. |
| `api.teamX.test` | `A` | `10.7.9.219` | Mac 2 (Primary Edge) | Backend API entry point; proxied through nginx on Mac 2 to upstream backends. |
| `ttl-test.teamX.test` | `A` | `10.7.9.219` | Mac 2 (Primary Edge) | Dedicated TTL validation record introduced in Extension B; demonstrates controlled record changes and cache propagation delays. |
| `fault-test.teamX.test` | `A` | `10.7.9.219` | Mac 2 (Primary Edge) | Failure scenario injection record (Task H / Extension H); used to demonstrate DNS-layer failure modes. |

### 4.2 Record Purpose: Detailed Explanation

**`app.teamX.test → 10.7.24.216`**

This record is the application-layer entry point for end-to-end client requests. During Phase 1, it resolved to Mac 2 (`10.7.9.11` / `10.7.9.219`). In Phase 2 Extension E, the DNS record was updated via a controlled cutover to point to Mac 3 (`10.7.24.216`), which runs a standby nginx proxy. By changing this single A record, all LAN clients that re-query the name after TTL expiry are seamlessly redirected to the new edge node without any client-side reconfiguration.

**`api.teamX.test → 10.7.9.219`**

This record provides a stable, name-based access path for API consumers. The name decouples the API endpoint from Mac 2's physical IP address. If Mac 2's DHCP lease changes, only this DNS record requires updating; client applications continue using the same FQDN without modification.

**`ttl-test.teamX.test → 10.7.9.219`**

Introduced in Phase 2 Extension B to study DNS TTL propagation mechanics in isolation. This record is updated to a new IP, the daemon is reloaded, and subsequent queries are timed to verify how quickly resolvers and clients reflect the change. It provides a non-production hostname specifically for TTL validation without affecting live traffic on `app.teamX.test` or `api.teamX.test`.

**`fault-test.teamX.test → 10.7.9.219`**

Reserved for failure demonstration tasks. It allows deliberate misconfiguration (e.g., pointing to a non-listening IP or stopped service) to generate and document expected error conditions such as TCP connection refused, `SERVFAIL` responses, or HTTP 502 Bad Gateway from the edge proxy.

### 4.3 TTL Configuration

```ini
local-ttl=30
```

| Parameter | Value | Effect |
|---|---|---|
| `local-ttl` | `30` | Instructs dnsmasq to set the DNS wire TTL field to `30` seconds in all Answer Sections for locally synthesised `address=` records. |
| Scope | Wire packet only | Controls the value transmitted in the DNS response packet. Does **not** control client-side OS cache retention, which is implementation-dependent (macOS `mDNSResponder` behavior may differ). |
| Impact on migration | Low propagation delay | A 30-second TTL means that after a DNS record change and daemon reload, all querying clients will receive the updated record within at most 30 seconds (assuming their cache honors the wire TTL). |

### 4.4 Upstream Forwarding

```ini
server=8.8.8.8
server=1.1.1.1
no-resolv
```

Queries for any domain not matching a local `address=` record (i.e., any external domain such as `google.com`) are forwarded to Google Public DNS (`8.8.8.8`) and Cloudflare (`1.1.1.1`). The `no-resolv` directive ensures dnsmasq does not consult `/etc/resolv.conf` for upstream resolvers, keeping forwarding exclusively controlled by the explicit `server=` lines.

> [!NOTE]
> The repository template (`configs/dns/dnsmasq.conf`) uses `server=10.7.0.1` (the LAN gateway) as the upstream forwarder. The active runtime configuration uses `server=8.8.8.8` and `server=1.1.1.1` (public resolvers). This is a confirmed configuration divergence between the Phase 1 template and Phase 2 runtime. See Section 7 for the full discrepancy table.

---

## 5. Service Management Commands

All service management is performed via Homebrew Services on macOS. The dnsmasq process runs as the current user and binds to port 53 on the specified listen addresses.

### 5.1 Starting the Service

```bash
# Start dnsmasq and register it to launch at login
sudo brew services start dnsmasq
```

> [!IMPORTANT]
> `sudo` is required because dnsmasq binds to privileged port 53 (< 1024). Without elevated privileges, the bind call will fail with `EACCES`.

### 5.2 Stopping the Service

```bash
# Stop the running dnsmasq instance
sudo brew services stop dnsmasq
```

### 5.3 Reloading Configuration (Without Downtime)

After editing `/opt/homebrew/etc/dnsmasq.conf`, reload the daemon without dropping existing connections:

```bash
# Send SIGHUP to trigger a configuration reload
sudo brew services restart dnsmasq

# Alternative: send SIGHUP directly if the PID is known
sudo kill -HUP $(pgrep dnsmasq)
```

> [!TIP]
> For Phase 2 controlled DNS record changes (Extension B and E), the preferred workflow is:
> 1. Edit `/opt/homebrew/etc/dnsmasq.conf` (update the `address=` line).
> 2. Run `dnsmasq --test -C /opt/homebrew/etc/dnsmasq.conf` to validate syntax before reloading.
> 3. Reload with `sudo brew services restart dnsmasq`.
> 4. Immediately verify with `dig @10.7.19.129 <changed-record>` to confirm the new record is live.

### 5.4 Checking Service Status

```bash
# List all Homebrew-managed services and their state
brew services list

# Verify dnsmasq process and port binding
sudo lsof -i :53

# Check macOS launchd service state
sudo launchctl list | grep dnsmasq
```

---

## 6. DNS Validation Commands

### 6.1 Configuration Syntax Validation

Before reloading or starting dnsmasq, validate the configuration file for syntax errors:

```bash
# Validate the active configuration file
dnsmasq --test -C /opt/homebrew/etc/dnsmasq.conf
```

**Expected output on success:**
```
dnsmasq: syntax check OK.
```

If the configuration is invalid, dnsmasq prints the offending directive and line number. The daemon is **not** started or modified by `--test`.

### 6.2 Querying DNS Records with `dig`

#### Query the primary DNS server directly (bypasses OS resolver cache):

```bash
# Query app.teamX.test directly against Mac 1
dig @10.7.19.129 app.teamX.test

# Query api.teamX.test directly against Mac 1
dig @10.7.19.129 api.teamX.test

# Query the TTL validation record
dig @10.7.19.129 ttl-test.teamX.test
```

#### Query using the system-configured resolver (confirms client resolver settings):

```bash
# Uses whatever resolver the OS has configured — SERVER line in output confirms which
dig app.teamX.test
dig api.teamX.test
```

#### Check the wire TTL in the Answer Section:

```bash
# The TTL value in the ANSWER SECTION should be 30 seconds
dig @10.7.19.129 app.teamX.test | grep -A 1 "ANSWER SECTION"
```

**Expected output (Phase 2 state):**
```
;; ANSWER SECTION:
app.teamX.test.         30      IN      A       10.7.24.216
```

#### Verify NOERROR status and authoritative answer flag:

```bash
# Short-form output showing only the most relevant fields
dig @10.7.19.129 app.teamX.test +short

# Full output including flags (look for 'aa' in the flags line)
dig @10.7.19.129 app.teamX.test +nocomments
```

#### Verify the DNS server port binding:

```bash
# Confirm dnsmasq is listening on port 53 and which address it is bound to
sudo lsof -i :53
```

**Expected output:**
```
COMMAND   PID  USER  FD  TYPE DEVICE  SIZE/OFF NODE NAME
dnsmasq   <pid> rudra  ...  IPv4  ...  UDP  *:domain
dnsmasq   <pid> rudra  ...  IPv4  ...  TCP  *:domain (LISTEN)
```

### 6.3 Checking Service Status with `brew services list`

```bash
brew services list
```

**Expected output (while dnsmasq is running):**
```
Name     Status  User  File
dnsmasq  started root  ~/Library/LaunchAgents/homebrew.mxcl.dnsmasq.plist
```

| Column | Meaning |
|---|---|
| `Status: started` | The service process is running and was started via launchd. |
| `Status: stopped` | The service is not running. |
| `Status: error` | launchd attempted to start the service but it exited with a non-zero code — check logs. |

---

## 7. Controlled DNS Record Changes

This section documents the operational procedure used in Phase 2 to perform controlled, DNS-based service migrations and TTL validation tests.

### 7.1 Procedure: Updating a DNS Record

```
Step 1 — Backup the current configuration
  cp /opt/homebrew/etc/dnsmasq.conf \
     /opt/homebrew/etc/dnsmasq.conf.pre-<change-label>

Step 2 — Edit the target address= line in /opt/homebrew/etc/dnsmasq.conf
  # Change:   address=/app.teamX.test/10.7.9.219
  # To:       address=/app.teamX.test/10.7.24.216

Step 3 — Validate the edited file
  dnsmasq --test -C /opt/homebrew/etc/dnsmasq.conf
  # Must output: dnsmasq: syntax check OK.

Step 4 — Reload the daemon
  sudo brew services restart dnsmasq

Step 5 — Verify the new record is live
  dig @10.7.19.129 app.teamX.test +short
  # Must return: 10.7.24.216

Step 6 — Verify propagation from client machines
  # From Mac 2 or Mac 3 (which use Mac 1 as resolver):
  dig app.teamX.test +short
  # Must return: 10.7.24.216 within one TTL interval (30 seconds)
```

### 7.2 Executed Migrations (Phase 2 History)

The following controlled record changes were executed during Phase 2, evidenced by the backup files preserved on disk:

| Change Event | Record Affected | Before | After | Backup Preserved |
|---|---|---|---|---|
| Extension E: Edge Migration | `app.teamX.test` | `10.7.9.219` (Mac 2) | `10.7.24.216` (Mac 3) | `dnsmasq.conf.pre-edge-migration` |
| Extension B: TTL Record Addition | `ttl-test.teamX.test` | *(not present)* | `10.7.9.219` | *(added in pre-edge state)* |
| Extension F / Fault Test Addition | `fault-test.teamX.test` | *(not present)* | `10.7.9.219` | `dnsmasq.conf.pre-extension-f` |

### 7.3 TTL Propagation Window

With `local-ttl=30`, the worst-case propagation delay after a record change is 30 seconds (time for all cached client resolvers to expire and re-query). In practice:

```
T=0:        DNS record updated, dnsmasq reloaded.
T=0–30s:    Cached clients still serve stale record.
            New queries (after cache miss) return new record immediately.
T=30s:      All cached entries have expired. All clients resolve new record.
```

---

## 8. Verification Evidence

### 8.1 Phase 1 Evidence (Historical)

The following evidence was collected during Phase 1 (Mac 1 at `10.7.17.222`, records pointing to `10.7.9.11`). This evidence is **historical** and reflects the Phase 1 configuration, not the Phase 2 runtime state.

| Test | Server | Domain | Status | Resolved IP | Evidence Location |
|---|---|---|---|---|---|
| Direct server query | `10.7.17.222#53` | `app.teamX.test` | `NOERROR` | `10.7.9.11` | `evidence/02-dns/dns-server-verification.md` |
| Direct server query | `10.7.17.222#53` | `api.teamX.test` | `NOERROR` | `10.7.9.11` | `evidence/02-dns/dns-server-verification.md` |
| Client query (Mac 2) | `10.7.17.222#53` | `app.teamX.test` | `NOERROR` | `10.7.9.11` | `evidence/02-dns/client-verification.md` |
| Client query (Mac 2) | `10.7.17.222#53` | `api.teamX.test` | `NOERROR` | `10.7.9.11` | `evidence/02-dns/client-verification.md` |
| Client query (Mac 4) | `10.7.17.222#53` | `app.teamX.test` | `NOERROR` | `10.7.9.11` | `evidence/02-dns/client-verification.md` |
| Client query (Mac 4) | `10.7.17.222#53` | `api.teamX.test` | `NOERROR` | `10.7.9.11` | `evidence/02-dns/client-verification.md` |

### 8.2 Phase 2 Evidence Status

Phase 2 live dig outputs against `10.7.19.129` for the current record state (`app.teamX.test → 10.7.24.216`) are **not stored in the repository evidence directory** at the time of writing. The active configuration was verified by direct file inspection of `/opt/homebrew/etc/dnsmasq.conf`, which contains the confirmed directives.

> [!IMPORTANT]
> Phase 2 dig evidence (queries against `10.7.19.129` returning `10.7.24.216` for `app.teamX.test`) should be collected and stored in `evidence/02-dns/` to complete the Phase 2 verification record.

---

## 9. Configuration Discrepancies & Unverified Details

### 9.1 Verified Discrepancies (Repository Template vs. Runtime)

| Property | Repository Template (`configs/dns/dnsmasq.conf`) | Active Runtime (`/opt/homebrew/etc/dnsmasq.conf`) | Classification |
|---|---|---|---|
| Mac 1 IP (`listen-address`) | `10.7.17.222` | `127.0.0.1,10.7.19.129` | **Discrepancy** — DHCP lease change |
| `app.teamX.test` target | `10.7.9.11` | `10.7.24.216` | **Discrepancy** — Extension E migration |
| `api.teamX.test` target | `10.7.9.11` | `10.7.9.219` | **Discrepancy** — DHCP address shift on Mac 2 |
| `ttl-test.teamX.test` | *Not present* | `10.7.9.219` | **Discrepancy** — Extension B addition |
| `fault-test.teamX.test` | *Not present* | `10.7.9.219` | **Discrepancy** — Extension H addition |
| Upstream forwarder | `server=10.7.0.1` (LAN gateway) | `server=8.8.8.8`, `server=1.1.1.1` (public) | **Discrepancy** — different upstream resolver |
| `local-ttl` directive | *Not present* | `local-ttl=30` | **Discrepancy** — Extension B addition |
| Loopback listener | *Not present* | `listen-address=127.0.0.1,...` | **Discrepancy** — added for local resolution |

### 9.2 Unverified Details

- [ ] **Phase 2 live dig evidence**: Direct query output from `dig @10.7.19.129 app.teamX.test` returning `10.7.24.216` has not been captured into the repository evidence directory. This should be collected and committed.
- [ ] **DHCP lease stability**: Current IPs (`10.7.19.129` for Mac 1, `10.7.9.219` for Mac 2, `10.7.24.216` for Mac 3) are DHCP-assigned and subject to change on router reboot. These values must be re-verified with `ifconfig en0` or `networksetup -getinfo Wi-Fi` at the start of each test session.
- [ ] **Client-side cache retention**: The `local-ttl=30` directive sets the wire TTL to 30 seconds, but actual client-side stub resolver cache retention on macOS (`mDNSResponder`) was not empirically verified via OS-level cache inspection (e.g., `dscacheutil -q host -a name app.teamX.test`).
- [ ] **Backup DNS resolver (Mac 3) synchronisation**: The active record state on the backup dnsmasq instance on Mac 3 (`10.7.24.216`) was not inspected as part of this document. It should mirror the primary to ensure consistent failover resolution.

---

## 10. Related Documents

| Document | Location | Description |
|---|---|---|
| DNS Architecture Section | `docs/architecture/sections/02_DNS_Architecture.md` | Full protocol mechanics, failover, TTL dynamics, and Extension E migration |
| Project Overview | `docs/architecture/sections/01_Project_Overview_and_Topology.md` | Network topology and service-port mapping |
| Phase 1 DNS Architecture | `docs/architecture/dns.md` | Phase 1 DNS design reference |
| Repository Config Template | `configs/dns/dnsmasq.conf` | Phase 1 baseline (outdated, see Section 9.1) |
| DNS Server Evidence (Phase 1) | `evidence/02-dns/dns-server-verification.md` | Phase 1 dig verification output |
| DNS Client Evidence (Phase 1) | `evidence/02-dns/client-verification.md` | Phase 1 client resolution verification |
| Sanitized Config Example | `docs/configuration/mac1-primary-dns/dnsmasq.conf.example` | Annotated copy of the active runtime configuration |
