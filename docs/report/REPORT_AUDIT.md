# Phase 2 Final Report Quality Audit & Readiness Review

**Document:** Quality Audit, Verification Checklist & Deliverable Readiness  
**Target Path:** `docs/report/REPORT_AUDIT.md`  
**Auditor / Reviewer:** Rudraksh (Mac1 Lead & Technical Documentation Reviewer)  
**Associated Deliverable:** [`docs/report/PHASE2_FINAL_REPORT.md`](PHASE2_FINAL_REPORT.md)  
**Date of Audit:** November 2026  

---

## 1. Files Inspected

Before drafting and validating the final comprehensive Phase 2 report, the following repository documents, configuration files, and empirical evidence artifacts were inspected:

### Documentation Roots
- [`README.md`](../../README.md) — Root project landing page, verified 3-server architecture, and port mappings.
- [`docs/report/sections/01_architecture_and_phase_changes.md`](sections/01_architecture_and_phase_changes.md) — Baseline architecture vs. Phase 2 resilience extensions.
- [`docs/report/sections/02_resilience_tests_and_results.md`](sections/02_resilience_tests_and_results.md) — Technical evaluations of Extensions A through E by Kaustubh.
- [`docs/report/sections/03_troubleshooting_and_learning.md`](sections/03_troubleshooting_and_learning.md) — Diagnostic methodology and practice fault analysis by Pratyush.
- [`docs/presentation/sections/01_introduction_and_architecture.md`](../presentation/sections/01_introduction_and_architecture.md) — Slide outlines, speaker scripts, and faculty Q&A defense.
- [`docs/architecture/sections/01_Project_Overview_and_Topology.md`](../architecture/sections/01_Project_Overview_and_Topology.md) — Network topology and OSI layer definitions.
- [`docs/architecture/sections/04_Security_Resilience_and_Troubleshooting.md`](../architecture/sections/04_Security_Resilience_and_Troubleshooting.md) — Host firewall isolation and failover mechanics.

### Configuration Bundles & Scripts
- [`docs/configuration/CONFIGURATION_INDEX.md`](../configuration/CONFIGURATION_INDEX.md) — Configuration asset inventory and drift catalog.
- [`docs/configuration/mac1-primary-dns/README.md`](../configuration/mac1-primary-dns/README.md) & [`dnsmasq.conf.example`](../configuration/mac1-primary-dns/dnsmasq.conf.example) — Primary DNS settings and directives.
- [`docs/configuration/mac3-backup-dns/README.md`](../configuration/mac3-backup-dns/README.md) & [`dnsmasq.conf`](../configuration/mac3-backup-dns/dnsmasq.conf) — Backup DNS configuration.
- [`docs/configuration/mac3-standby-nginx/README.md`](../configuration/mac3-standby-nginx/README.md) & [`standby.conf`](../configuration/mac3-standby-nginx/standby.conf) — Standby Nginx settings on ports 80/443.
- [`docs/configuration/security-and-validation/README.md`](../configuration/security-and-validation/README.md) — PKI setup and security boundary manual.
- [`scripts/start-backends.sh`](../../scripts/start-backends.sh), [`scripts/check-backends.sh`](../../scripts/check-backends.sh), [`scripts/stop-backends.sh`](../../scripts/stop-backends.sh) — Backend operational scripts.

### Evidence Trees
- [`evidence/MASTER_EVIDENCE_INDEX.md`](../../evidence/MASTER_EVIDENCE_INDEX.md) — Authoritative 46-file evidence index and demonstration runbook.
- [`evidence/FINAL_EVIDENCE_AUDIT.md`](../../evidence/FINAL_EVIDENCE_AUDIT.md) — Technical evidence audit, defect review, and unsupported claims analysis.
- [`evidence/dns/`](../../evidence/dns/) — DNS evidence suite (19 files across primary config, resolution, backup comparison, failover, TTL, and troubleshooting).
- [`evidence/nginx-http-tls/`](../../evidence/nginx-http-tls/) — Nginx proxy, TLS 1.3, load balancing, caching, and protocol analysis suite.
- [`evidence/resilience-security/`](../../evidence/resilience-security/) — Mac3 backend health, PF firewall, process failover, and standby edge migration suite.

---

## 2. Report Sections Completed

The final report was compiled into [`docs/report/PHASE2_FINAL_REPORT.md`](PHASE2_FINAL_REPORT.md) covering all mandatory chapters and appendices in simple, student-friendly English:

- **Chapter 1 — Introduction:** High-level project motivation, Phase 1 limitations, and goals of Phase 2.
- **Chapter 2 — Phase 1 vs Phase 2:** Full comparison table and updated Mermaid cluster architecture diagram.
- **Chapter 3 — Updated Network Architecture:** Team allocation, active 3-server topology, IP inventory, DNS mappings, request sequence, and Mermaid protocol flow.
- **Chapter 4 — Extension A: Backup DNS:** Secondary `dnsmasq` setup on Mac3, direct query parity tests, primary outage simulation, and macOS resolver latency limitations.
- **Chapter 5 — Extension B: DNS TTL:** Definition of TTL, choice of 30 seconds, `local-ttl=30` directive, `dig` output interpretation, and wire TTL vs. OS client cache limitations.
- **Chapter 6 — Extension C: PF Firewall:** Security motivation, line-by-line breakdown of `/etc/pf.anchors/cn_backend`, the `quick` keyword, and authorized (Mac2) vs. unauthorized (Mac1) test results.
- **Chapter 7 — Extension D: Backend Failover:** Express backend setup, Nginx `max_fails=1 fail_timeout=10s` logic, 10-request baseline/failure/recovery results, and application-level resiliency vs. hardware SPOF distinction.
- **Chapter 8 — Extension E: DNS-Based Edge Migration:** Standby Nginx on Mac3 on standard ports `80`/`443`, certificate replication, DNS cutover verification, and port disparity (`8080`/`8443` vs `80`/`443`) limitations.
- **Chapter 9 — Extension F: Faculty-Injected Troubleshooting:** Systematic 4-tier diagnostic model (DNS $\rightarrow$ TCP $\rightarrow$ TLS $\rightarrow$ HTTP), walkthrough of `fault-test.teamX.test` practice fault, and demarcation between internal practice and future faculty evaluation.
- **Chapter 10 — Testing and Results:** 17-row comprehensive test results table with commands, expected results, observed outcomes, status labels, and primary evidence links.
- **Chapter 11 — Problems Faced and Solutions:** 6 genuine, repository-grounded engineering hurdles: DNS port 53 conflicts, SSH connection refused during cert copy, Nginx port 80/443 permissions, curl sandbox proxy confusion, PF rule evaluation ordering, and edge migration port disparity.
- **Chapter 12 — Team Contributions:** Detailed breakdowns for Rudraksh (Mac1), Kaustubh (Mac2), Pratyush (Mac3), and Bhargav (Mac4).
- **Chapter 13 — Limitations and Future Improvements:** Transparent disclosure of 8 real-world constraints (single-host backends, non-deterministic macOS failover, port asymmetry, etc.) and 5 realistic future enhancements.
- **Chapter 14 — Learning Outcomes and Conclusion:** Dedicated learning reflections for each extension A through F, summarizing core networking takeaways.
- **Appendix A — Important Commands:** Quick-reference command sheet organized across 6 categories.
- **Appendix B — Configuration Files:** Catalog of all key configuration files and repository paths.
- **Appendix C — Evidence Index:** Navigational cross-reference directly linking to empirical evidence files.

---

## 3. Technical Inconsistencies Disclosed

1. **Uncleaned Practice Fault (`fault-test.teamX.test`):**  
   - In Mac1's live `/opt/homebrew/etc/dnsmasq.conf`, line 22 still contains `address=/fault-test.teamX.test/10.7.9.219`, which returns `NOERROR` and points to Mac2.
   - On Mac3, `fault-test.teamX.test` returns `NXDOMAIN`.
   - The report explicitly documents this desynchronization rather than fabricating a claim that cleanup was performed.
2. **Edge Proxy Port Asymmetry:**  
   - Mac2 Primary Nginx listens on unprivileged ports `8080/tcp` (HTTP) and `8443/tcp` (HTTPS).
   - Mac3 Standby Nginx listens on standard privileged ports `80/tcp` (HTTP) and `443/tcp` (HTTPS).
   - The report repeatedly clarifies that DNS record changes cannot remap TCP ports, and that reverting DNS back to Mac2 does not automatically restore standard-port access.
3. **Template Configuration Drift:**  
   - Root template files [`configs/dns/dnsmasq.conf`](../../configs/dns/dnsmasq.conf) and [`configs/nginx/nginx.conf`](../../configs/nginx/nginx.conf) contain Phase 1 IP addresses (`10.7.17.222`, `10.7.9.11`, `10.7.13.5`, `10.7.14.32`) and lack `local-ttl=30` and Mac3 consolidated backends.
   - The report directs readers to the verified Phase 2 runtime guides in `docs/configuration/` and active dumps in `evidence/`.

---

## 4. Missing Evidence Catalog

The audit confirmed the following evidence gaps in the repository:
1. **Raw Packet Capture Traces (`.pcap` / `.pcapng`):**  
   - Only exported PNG frame screenshots exist in [`evidence/07-wireshark/mac1/`](../../evidence/07-wireshark/mac1/). The underlying raw binary pcap captures were not committed.
2. **Client-Side OS DNS Cache Retention:**  
   - Wire packet responses verify `TTL: 30`, but non-network OS cache retention logs (e.g., periodic `dscacheutil -q host -a name ...` traces proving cache hits without network packets) are absent.
3. **Automated Client Failover Transition Packet Capture:**  
   - While direct queries to Mac3 during a Mac1 shutdown returned `NOERROR`, a synchronized Wireshark trace showing client stub resolver failover timing was not captured.
4. **Live PF Firewall Kernel State Table:**  
   - Rule syntax and cross-machine test logs are documented, but raw terminal text output from `sudo pfctl -a cn_backend -s state` or `sudo pfctl -a cn_backend -s info` is not archived in `evidence/resilience-security/pf-firewall/`.
5. **Empty `evidence/08-failures/` Directory:**  
   - Contains only `.gitkeep`. Failure scenario evidence was documented in markdown files under `evidence/resilience-security/` and `evidence/dns/troubleshooting/` rather than raw text dumps in this folder.

---

## 5. Claims Requiring Team Confirmation Before Final Viva

Before final evaluation and demonstration, the team should align on the following items:
1. **Pre-Evaluation Cleanup of `fault-test.teamX.test`:**  
   - If the faculty requests a clean DNS zone prior to the exam, Rudraksh must remove line 22 from `/opt/homebrew/etc/dnsmasq.conf` on Mac1 and reload the daemon (`sudo brew services restart dnsmasq`), confirming `dig` returns `NXDOMAIN`.
2. **Demonstration of Edge Migration:**  
   - During the live demo of Extension E, team members must remember that curl requests to Mac3 must target `https://app.teamX.test/` (port 443), while requests to Mac2 must target `https://app.teamX.test:8443/` (port 8443).
3. **Faculty Exam Readiness:**  
   - The team must be prepared to execute the 4-tier troubleshooting protocol (DNS $\rightarrow$ TCP $\rightarrow$ TLS $\rightarrow$ HTTP) during the unannounced faculty fault injection challenge.

---

## 6. Final Readiness Assessment

- **Academic Integrity:** 100% compliant. No invented tests, no fabricated IP addresses, and no false claims of complete hardware redundancy.
- **Clarity & Tone:** Written in natural, student-friendly undergraduate English ("We configured...", "We tested...", "We observed...").
- **Reproducibility:** A professor or student can reproduce every configuration and test procedure using the provided commands and file references.
- **Deliverable Status:** **READY FOR SUBMISSION & TEAM REVIEW**.
