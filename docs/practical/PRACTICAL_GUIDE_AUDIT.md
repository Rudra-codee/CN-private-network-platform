# Phase 2 Practical Execution Guide: Quality & Verification Audit

**Document:** Quality Audit, Command Verification & Evaluation Readiness Review  
**Target Path:** `docs/practical/PRACTICAL_GUIDE_AUDIT.md`  
**Auditor / Reviewer:** Rudraksh (Mac1 Lead & Computer Networks Lab Documentation Specialist)  
**Associated Deliverables:**
- [`PHASE2_PRACTICAL_EXECUTION_GUIDE.md`](PHASE2_PRACTICAL_EXECUTION_GUIDE.md)
- [`README.md`](README.md)  
**Date of Audit:** November 2026  

---

## 1. Files Inspected

Before drafting the practical guide, all operational shell scripts, service configuration templates, evidence indexes, and architecture guides were inspected:

### Project Scripts & Manifests
- [`scripts/start-backends.sh`](../../scripts/start-backends.sh) — Starts Backend A (3001) & Backend B (3002) with pre-checks.
- [`scripts/check-backends.sh`](../../scripts/check-backends.sh) — Checks process listeners and queries `/api/status` with `--noproxy "*"`.
- [`scripts/stop-backends.sh`](../../scripts/stop-backends.sh) — Stops services using targeted PIDs and SIGTERM/SIGKILL escalation.

### Configuration Bundles
- [`docs/configuration/mac1-primary-dns/README.md`](../configuration/mac1-primary-dns/README.md) & [`dnsmasq.conf.example`](../configuration/mac1-primary-dns/dnsmasq.conf.example) — Primary DNS settings and service commands.
- [`docs/configuration/mac3-backup-dns/README.md`](../configuration/mac3-backup-dns/README.md) & [`dnsmasq.conf`](../configuration/mac3-backup-dns/dnsmasq.conf) — Backup DNS on Mac3.
- [`docs/configuration/mac3-standby-nginx/README.md`](../configuration/mac3-standby-nginx/README.md) & [`standby.conf`](../configuration/mac3-standby-nginx/standby.conf) — Standby Nginx on Mac3 on standard ports 80/443.
- [`docs/configuration/security-and-validation/README.md`](../configuration/security-and-validation/README.md) — PKI setup, TLS certificates, and PF rules.

### Evidence & Documentation Roots
- [`README.md`](../../README.md) — Root repository overview and verified topology.
- [`docs/report/PHASE2_FINAL_REPORT.md`](../report/PHASE2_FINAL_REPORT.md) — Complete Phase 2 technical report.
- [`evidence/MASTER_EVIDENCE_INDEX.md`](../../evidence/MASTER_EVIDENCE_INDEX.md) — Master catalog of 46 evidence files.
- [`evidence/FINAL_EVIDENCE_AUDIT.md`](../../evidence/FINAL_EVIDENCE_AUDIT.md) — Defect analysis and unsupported claims audit.
- [`evidence/dns/troubleshooting/troubleshooting-log-analysis.md`](../../evidence/dns/troubleshooting/troubleshooting-log-analysis.md) — Practice fault investigation and macOS resolver incident.

---

## 2. Files Created

1. [`docs/practical/PHASE2_PRACTICAL_EXECUTION_GUIDE.md`](PHASE2_PRACTICAL_EXECUTION_GUIDE.md)  
   - Master 16-section execution guide for undergraduate team members.
   - Includes safety warnings, pre-practical checklists, machine assignments, step-by-step commands, expected outputs, troubleshooting flows, and viva questions.
2. [`docs/practical/README.md`](README.md)  
   - Quick navigational summary linking to the execution guide and related project documentation.

---

## 3. Practicals Covered & Verified Commands

The practical execution guide details the following 16 operational sections:

| Section | Feature / Practical | Target Machine | Key Command(s) | Verification & Evidence Status |
|---|---|---|---|---|
| **Sec 1** | Pre-Practical Checklist | All Macs | Service and network status checks | **Verified** |
| **Sec 2** | Network Connectivity | Mac1 | `ifconfig en0`, `ping -c 3 10.7.9.219`, `ping -c 3 10.7.24.216` | **Verified** (0% packet loss) |
| **Sec 3** | Primary & Backup DNS | Mac1 | `dig @10.7.19.129 app.teamX.test`, `dig @10.7.24.216 app.teamX.test`, `cat /etc/resolver/teamX.test` | **Verified** (`NOERROR`, `A 10.7.24.216`) |
| **Sec 4** | DNS TTL (30s) | Mac1 | `dig @10.7.19.129 ttl-test.teamX.test +noall +answer` | **Verified** (`TTL: 30`) |
| **Sec 5** | Backup DNS Failover | Mac1 & Mac3 | `sudo brew services stop dnsmasq`, `dig @10.7.24.216 app.teamX.test` | **Verified** (Mac3 answers independently) |
| **Sec 6** | Nginx Reverse Proxy | Mac1 | `curl -i http://10.7.9.219:8080/` | **Verified** (HTTP 200 OK via Mac2) |
| **Sec 7** | Load Balancing | Mac1 | `for i in {1..10}; do curl -s http://10.7.9.219:8080/ \| grep -o '"backend":"[AB]"'; done` | **Verified** (Alternating 50/50 A/B) |
| **Sec 8** | Backend Failover | Mac3 & Mac1 | `lsof -tiTCP:3001 \| xargs kill -TERM` on Mac3; 10 curl requests on Mac1; restart with `./scripts/start-backends.sh` | **Verified** (100% served by Backend B) |
| **Sec 9** | HTTPS & TLS 1.3 | Mac1 | `curl -i https://app.teamX.test/`, `openssl s_client -connect app.teamX.test:443 -servername app.teamX.test` | **Verified** (TLS 1.3, valid SAN, no `-k`) |
| **Sec 10** | HTTP Proxy Caching | Mac1 | `curl -s -D - -o /dev/null https://app.teamX.test/ \| grep -iE 'cache\|expires\|etag\|x-backend'` | **Verified** (`X-Cache-Status: MISS` $\rightarrow$ `HIT`) |
| **Sec 11** | PF Host Firewall | Mac2 & Mac1 | `nc -vz 10.7.24.216 3001` on Mac2 (allowed); `nc -vz -w 5 10.7.24.216 3001` on Mac1 (timed out) | **Verified** (Layer 4 microsegmentation) |
| **Sec 12** | Edge Migration | Mac1 | `dig app.teamX.test`, `curl -i http://app.teamX.test/`, `curl -i https://app.teamX.test/` | **Verified** (Ports 80/443 on Mac3) |
| **Sec 13** | Troubleshooting Practice | Mac1 & Mac2 | Inject `fault-test.teamX.test`, run 4-tier diagnostic model, execute cleanup | **Verified** (Diagnostic flow confirmed) |
| **Sec 14** | Final Health Check | Mac1 | Compact multi-service validation loop | **Verified** |
| **Sec 15** | Troubleshooting Reference | All Macs | 6 common error codes and solutions + resolver drift case study | **Verified** |
| **Sec 16** | Viva Quick-Fire Q&A | All Members | 10 rapid technical Q&A pairs for oral exam | **Verified** |

---

## 4. Commands Requiring Team Confirmation Prior to Evaluation

1. **Backend Termination Method on Mac3:**  
   - In Section 8, the guide documents stopping Backend A using `lsof -tiTCP:3001 -sTCP:LISTEN | xargs kill -TERM` rather than broad commands like `killall node`. Pratyush must confirm this is executed strictly on port `3001`.
2. **Restarting Backends on Mac3:**  
   - After failover testing, Pratyush must run `./scripts/start-backends.sh` and `./scripts/check-backends.sh` to restore both backends.
3. **Practice Fault Ingestion and Removal:**  
   - In Section 13, Rudraksh temporarily appends `address=/fault-test.teamX.test/10.7.9.219` to Mac1's `/opt/homebrew/etc/dnsmasq.conf`. **Rudraksh must execute the cleanup command (`sudo sed -i '' '/fault-test\.teamX\.test/d' ...`) immediately after the test.**
4. **macOS Resolver File (`/etc/resolver/teamX.test`):**  
   - Rudraksh and test clients must confirm that `/etc/resolver/teamX.test` contains `nameserver 10.7.19.129` and not the obsolete IP `10.7.26.214`.

---

## 5. Missing Evidence & Disclosures

1. **Client-Side Cache Retention Evidence:**  
   - Section 4 notes that `dig` outputs prove the 30-second wire TTL, but do not prove OS stub resolver cache retention (which requires OS-level cache inspection like `dscacheutil`).
2. **Raw Binary `.pcap` Files:**  
   - Wireshark captures exist as exported PNG screenshots in [`evidence/07-wireshark/mac1/`](../../evidence/07-wireshark/mac1/); binary pcap captures were not committed to the repository.
3. **Standby Edge Port Asymmetry:**  
   - The guide repeatedly warns that Mac2 uses ports `8080`/`8443` while Mac3 standby Nginx uses standard ports `80`/`443`. Switching DNS to Mac3 changes the target port from `8443` to `443`.

---

## 6. Technical Inconsistencies Disclosed

1. **Mac1 Practice Fault Residual State:**  
   - Prior to running Section 13, Mac1's live config still has `fault-test.teamX.test` configured from earlier testing. Section 13 explains this and provides the exact cleanup command.
2. **Template Drift in `configs/`:**  
   - The guide explicitly warns team members not to copy `configs/dns/dnsmasq.conf` or `configs/nginx/nginx.conf` directly, as those template files contain Phase 1 IP addresses.

---

## 7. Final Deliverable Readiness Assessment

- **Pedagogical Quality:** Beginner-friendly, step-by-step layout with exact commands, machine labels, expected terminal outputs, and clear explanations of what each result proves.
- **Safety & Reversibility:** Every destructive or temporary action (stopping DNS, killing Backend A, injecting a fault) is paired with an immediate, prominent cleanup command.
- **Accuracy:** Zero placeholder IPs, zero invented paths, and strict adherence to the verified 3-server topology.
- **Status:** **FULLY READY FOR LAB DEMONSTRATION AND VIVA DEFENSE**.
