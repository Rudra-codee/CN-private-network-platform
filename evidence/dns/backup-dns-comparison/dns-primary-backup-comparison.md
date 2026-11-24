# Primary vs. Backup DNS Resolution Comparison Matrix

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** Authoritative Record Comparison (Primary Mac1 vs. Backup Mac3)  
**Target Path:** `evidence/dns/backup-dns-comparison/dns-primary-backup-comparison.md`  
**Classification:** Technical Evidence Audit  
**Auditor:** Rudraksh (Senior Computer Networks Engineer)  
**Date of Audit:** 2026-11-25  

---

## 1. Overview and Node Demarcation

In Phase 2, DNS high availability (Extension A) was introduced by deploying a secondary `dnsmasq` resolver on **Mac3** to mirror the authoritative zone records hosted by the primary resolver on **Mac1**.

- **Primary DNS Host (Mac1):** `10.7.19.129:53` (UDP/TCP)
- **Backup DNS Host (Mac3):** `10.7.24.216:53` (UDP/TCP)
- **Target Authoritative Zone:** `.teamX.test`
- **Configured Wire TTL:** `local-ttl=30` (30 seconds)

This audit executes direct `dig` queries against both resolvers across all project domains to evaluate record synchronization, authoritative flags, response statuses, and any discrepancies.

---

## 2. Side-by-Side Resolution Comparison Matrix

The table below records the empirical query results captured on 2026-11-25 using `dig` from client workstation Mac1.

| Fully Qualified Domain Name (FQDN) | Primary DNS (Mac1: `10.7.19.129`) Result | Backup DNS (Mac3: `10.7.24.216`) Result | Status / Flags | Wire TTL | Consistency Assessment |
|---|---|---|---|---|---|
| **`app.teamX.test`** | `10.7.24.216` | `10.7.24.216` | `NOERROR` (`qr aa rd ra`) on both | `30s` on both | **PERFECT MATCH (VERIFIED)**<br/>Both resolvers correctly route application traffic to the Mac3 standby/migrated edge proxy. |
| **`api.teamX.test`** | `10.7.9.219` | `10.7.9.219` | `NOERROR` (`qr aa rd ra`) on both | `30s` on both | **PERFECT MATCH (VERIFIED)**<br/>Both resolvers route backend API traffic to Mac2 primary edge proxy. |
| **`ttl-test.teamX.test`** | `10.7.9.219` | `10.7.9.219` | `NOERROR` (`qr aa rd ra`) on both | `30s` on both | **PERFECT MATCH (VERIFIED)**<br/>Dedicated TTL experimentation record is identical across both nodes. |
| **`fault-test.teamX.test`** | `10.7.9.219` | `NXDOMAIN` (`qr rd ra`, Answer: 0) | `NOERROR` (Mac1)<br/>`NXDOMAIN` (Mac3) | `30s` (Mac1)<br/>*N/A* (Mac3) | **DISCREPANCY (UNSYNCHRONIZED)**<br/>Practice fault mapping remains active on Mac1, whereas Mac3 does not contain this record. |

---

## 3. Detailed Query Output Evidence

### 3.1 `app.teamX.test` (Migrated Edge / Nginx Proxy)
- **Raw Evidence Files:**
  - Mac1 Primary: [`evidence/dns/resolution-tests/dig-mac1-app.txt`](../resolution-tests/dig-mac1-app.txt)
  - Mac3 Backup: [`evidence/dns/backup-dns-comparison/dig-mac3-app.txt`](dig-mac3-app.txt)
- **Analysis:**
  Both resolvers respond with `status: NOERROR`, set the Authoritative Answer flag (`aa`), advertise an identical 30-second TTL (`local-ttl=30`), and return IPv4 address `10.7.24.216`. This confirms that Phase 2 Extension E (edge migration cutover to Mac3) was consistently applied to both resolvers.

### 3.2 `api.teamX.test` (Primary Edge / Load Balancer)
- **Raw Evidence Files:**
  - Mac1 Primary: [`evidence/dns/resolution-tests/dig-mac1-api.txt`](../resolution-tests/dig-mac1-api.txt)
  - Mac3 Backup: [`evidence/dns/backup-dns-comparison/dig-mac3-api.txt`](dig-mac3-api.txt)
- **Analysis:**
  Both resolvers return `10.7.9.219` with `status: NOERROR` and `flags: qr aa rd ra`. Ingress API traffic directed to `api.teamX.test` targets Mac2 regardless of which resolver answers the client.

### 3.3 `ttl-test.teamX.test` (Extension B Validation Record)
- **Raw Evidence Files:**
  - Mac1 Primary: [`evidence/dns/resolution-tests/dig-mac1-ttl-test.txt`](../resolution-tests/dig-mac1-ttl-test.txt)
  - Mac3 Backup: [`evidence/dns/backup-dns-comparison/dig-mac3-ttl-test.txt`](dig-mac3-ttl-test.txt)
- **Analysis:**
  Both resolvers return `10.7.9.219` with TTL `30`. Record synchronization is verified.

### 3.4 `fault-test.teamX.test` (Troubleshooting / Fault-Injection Record)
- **Raw Evidence File:** [`evidence/dns/troubleshooting/fault-test-record-audit.txt`](../troubleshooting/fault-test-record-audit.txt)
- **Mac1 Response:**
  ```text
  ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 32425
  ;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
  fault-test.teamX.test.  30  IN  A  10.7.9.219
  ```
- **Mac3 Response:**
  ```text
  ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 62560
  ;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
  ```
- **Root Cause Analysis:**
  A practice fault was intentionally introduced on Mac1 to demonstrate DNS failure scenarios (Task H / troubleshooting exercises) by adding `address=/fault-test.teamX.test/10.7.9.219`. Post-test cleanup was **not performed** on Mac1. Because Mac3 was provisioned from the clean Phase 2 specification template (`docs/configuration/mac3-backup-dns/dnsmasq.conf`), Mac3 never received this fault record. Consequently, queries to Mac1 succeed while queries to Mac3 return `NXDOMAIN`.

---

## 4. Auditor Conclusion

1. **Production Zone Synchronization:** For all intended production records (`app.teamX.test`, `api.teamX.test`, and `ttl-test.teamX.test`), Mac1 and Mac3 exhibit **100% record parity, identical TTL values (30s), and authoritative answer semantics**.
2. **Discrepancy Disclosure:** The discrepancy on `fault-test.teamX.test` is an active operational artifact from troubleshooting exercises. It has been documented without alteration, preserving system state.
