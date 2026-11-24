# DNS Troubleshooting Log, Fault Audit & Negative Resolution Evidence

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** DNS Troubleshooting, Port Listeners, Practice Fault Audit & Negative Resolution  
**Target Path:** `evidence/dns/troubleshooting/troubleshooting-log-analysis.md`  
**Classification:** Technical Evidence Audit  
**Auditor:** Rudraksh (Senior Computer Networks Engineer)  
**Date of Audit:** 2026-11-25  

---

## 1. Practice Fault Audit: `fault-test.teamX.test`

During Phase 2 failure injection and troubleshooting testing (Task H / Extension H), a practice fault was intentionally introduced into Mac1's primary DNS configuration to test error detection and routing discrepancies.

### 1.1 Configured Directive on Mac1
Inspection of `/opt/homebrew/etc/dnsmasq.conf` (line 22) reveals:

```ini
address=/fault-test.teamX.test/10.7.9.219
```

### 1.2 Multi-Server Resolution Discrepancy
Direct empirical queries were executed against both cluster resolvers:
- **Raw Evidence File:** [`evidence/dns/troubleshooting/fault-test-record-audit.txt`](fault-test-record-audit.txt)

#### Primary DNS (Mac1: `10.7.19.129`):
```text
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 32425
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; ANSWER SECTION:
fault-test.teamX.test.  30  IN  A  10.7.9.219
```
*Mac1 authoritatively answers with an A record pointing to Mac2 (`10.7.9.219`).*

#### Backup DNS (Mac3: `10.7.24.216`):
```text
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 62560
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; AUTHORITY SECTION:
.       0   IN  SOA ...
```
*Mac3 returns `status: NXDOMAIN` (`RCODE 3`), as the domain is unmapped in its zone table.*

### 1.3 Auditor Assessment: Cleanup Status
> [!WARNING]
> **Audit Finding — Uncleaned Fault Record:**  
> Cleanup of the practice fault was **NOT completed** following the testing session. The `fault-test.teamX.test` entry remains active in Mac1's operational `/opt/homebrew/etc/dnsmasq.conf`. In strict compliance with audit restrictions (*"Do not modify dnsmasq configuration... If it remains configured, report it clearly. Do not silently remove it"*), this record has been documented rather than altered.

---

## 2. Negative Resolution & NXDOMAIN Verification

To confirm that the primary resolver correctly synthesizes negative responses for unmapped domain names within the `.teamX.test` zone, a query was dispatched for an arbitrary non-existent hostname:

```bash
dig @10.7.19.129 nonexistent.teamX.test
```

### 2.1 Observed Result
- **Raw Evidence File:** [`evidence/dns/troubleshooting/nxdomain-test.txt`](nxdomain-test.txt)
- **Response Flags & Status:**
  ```text
  ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 43564
  ;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
  ```
- **Technical Interpretation:**
  The server responds with `RCODE 3` (`NXDOMAIN`) and `ANSWER: 0`. The presence of the recursion flags confirms dnsmasq correctly processed the query locally and refused to leak the unqualified `.test` domain to external upstreams, satisfying the `bogus-priv` and `domain-needed` directives.

---

## 3. Port 53 Listener & Process State Audit

A common DNS troubleshooting failure mode is socket binding collision (where another daemon like macOS `mDNSResponder` or an old `dnsmasq` instance monopolizes port 53).

### 3.1 Socket Listener Verification
- **Raw Evidence File:** [`evidence/dns/primary-dns-config/mac1-port53-listeners.txt`](../primary-dns-config/mac1-port53-listeners.txt)
- **Netstat Output:**
  ```text
  tcp4       0      0  127.0.0.1.53           *.*                    LISTEN     
  tcp4       0      0  10.7.19.129.53         *.*                    LISTEN     
  udp4       0      0  127.0.0.1.53           *.*                               
  udp4       0      0  10.7.19.129.53         *.*                               
  ```
- **Audit Findings:**
  1. `dnsmasq` is properly bound to both **UDP port 53** (datagram queries) and **TCP port 53** (stream queries / large payloads).
  2. The `bind-interfaces` directive is functioning as intended: sockets are bound specifically to `127.0.0.1` and `10.7.19.129`, rather than wildcard `0.0.0.0`, avoiding conflicts on interface `en0`.

### 3.2 Process Execution State
- **Raw Evidence File:** [`evidence/dns/primary-dns-config/mac1-dns-service-status.txt`](../primary-dns-config/mac1-dns-service-status.txt)
- **Process State:**
  ```text
  nobody 74977 ... /opt/homebrew/opt/dnsmasq/sbin/dnsmasq --keep-in-foreground -C /opt/homebrew/etc/dnsmasq.conf -7 /opt/homebrew/etc/dnsmasq.d,*.conf
  ```
- **Audit Findings:**
  1. The daemon runs under unprivileged user `nobody`, adhering to security best practices after privileged port 53 acquisition.
  2. The process explicitly loads `/opt/homebrew/etc/dnsmasq.conf`, confirming that this file is the active configuration source.
