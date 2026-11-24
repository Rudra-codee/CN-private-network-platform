# DNS Failover Procedure, Resolution Mechanics, and Evidence Audit

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** DNS Redundancy & Resolver Failover Technical Audit  
**Target Path:** `evidence/dns/failover/failover-procedure-and-status.md`  
**Classification:** Technical Evidence Audit  
**Auditor:** Rudraksh (Senior Computer Networks Engineer)  
**Date of Audit:** 2026-11-25  

---

## 1. Failover Architecture & Procedure

To eliminate the Single Point of Failure (SPOF) present in Phase 1 (where only Mac1 served DNS), Phase 2 Extension A introduced a redundant resolver on Mac3.

### 1.1 Dual-Resolver Client Configuration
Client workstations and servers on the `10.7.0.0/19` LAN are configured with dual nameservers in their network interface settings:

```text
nameserver 10.7.19.129   # Primary DNS (Mac1)
nameserver 10.7.24.216   # Backup DNS (Mac3)
```

### 1.2 Demonstrated Failover Procedure
The failover verification test sequence designed and executed in Phase 2 consisted of:

1. **Baseline State Verification:**
   Query both resolvers independently to verify they are active and return matching authoritative records for `.teamX.test`.
2. **Primary Service Deactivation:**
   Simulate a catastrophic primary resolver failure by stopping `dnsmasq` on Mac1 (`sudo brew services stop dnsmasq` or terminating the process).
3. **Failover Query Execution:**
   Issue client DNS queries from a client host (e.g. `dig app.teamX.test`).
4. **Resolution Continuity Confirmation:**
   Confirm that the client stub resolver detects the primary unresponsiveness, fails over to Mac3 (`10.7.24.216`), and receives an identical `NOERROR` answer with `10.7.24.216`.
5. **Primary Restoration:**
   Restart `dnsmasq` on Mac1 and confirm resumption of dual-resolver availability.

---

## 2. Evidence Status and Operational Boundary

### 2.1 Empirical Capabilities Verified Live
- **Mac3 Standalone Resolution:** Direct queries against Mac3 (`10.7.24.216`) were executed and verified live on 2026-11-25. The raw capture files prove Mac3 authoritatively resolves all production project records (`app.teamX.test`, `api.teamX.test`, `ttl-test.teamX.test`) with `NOERROR` and `local-ttl=30`.
  - Evidence: [`evidence/dns/backup-dns-comparison/dig-mac3-app.txt`](../backup-dns-comparison/dig-mac3-app.txt)
  - Evidence: [`evidence/dns/backup-dns-comparison/dig-mac3-api.txt`](../backup-dns-comparison/dig-mac3-api.txt)
  - Evidence: [`evidence/dns/backup-dns-comparison/dig-mac3-ttl-test.txt`](../backup-dns-comparison/dig-mac3-ttl-test.txt)

### 2.2 Operational Constraint & Non-Recreation Notice
> [!IMPORTANT]
> **Adherence to Audit Safeguards:**  
> In strict accordance with audit instructions (*"Do not stop or restart services. Do not stop the primary DNS service again just to recreate evidence"*), the primary DNS daemon on Mac1 was **not** stopped during this audit turn. Re-killing the primary DNS server on a live shared platform risks disrupting ongoing testing by team members.

---

## 3. Critical Technical Limitations: macOS Resolver Ordering Dynamics

A major systems networking finding from this project is the refutation of the common assumption that operating systems strictly follow sequential primary-then-secondary fallback.

### 3.1 `mDNSResponder` Dynamic Selection vs. Strict Sequential Ordering
On macOS systems (which govern Mac1, Mac2, Mac3, and Mac4):
1. **Dynamic RTT Scoring:** The macOS stub resolver daemon (`mDNSResponder`) does not strictly query Server 1, wait indefinitely for a timeout, and then query Server 2. Instead, it measures exponential moving average Round Trip Times (RTT) across all configured nameservers.
2. **Parallel Probing:** Under certain network conditions, `mDNSResponder` dispatches parallel DNS queries to both `10.7.19.129` and `10.7.24.216`, adopting whichever valid response arrives first.
3. **Failover Latency:** When the primary resolver becomes completely unresponsive, the client experiences a transport timeout (typically 1–2 seconds for UDP before fallback), after which queries route to `10.7.24.216`.

### 3.2 Audit Claim Boundary
- **What is PROVEN:** Mac3 (`10.7.24.216`) possesses the complete configuration and verified runtime capacity to independently resolve all project names when Mac1 fails.
- **What is NOT PROVEN in current logs:** A live synchronized Wireshark packet capture showing an automated client transitioning from Mac1 to Mac3 during an injected crash is not currently committed in the evidence directory.
- **Classification:** **HISTORICALLY DOCUMENTED / PARTIALLY VERIFIED** (Resolver capability verified; packet capture of active transition absent).
