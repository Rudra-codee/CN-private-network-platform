# Practical Execution Runbook & Demonstration Guides

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Target Directory:** `docs/practical/`  
**Purpose:** Practical lab demonstration runbooks, step-by-step terminal execution guides, and faculty evaluation documentation for team members.

---

## 1. Directory Overview

This directory contains practical, beginner-friendly, and step-by-step terminal execution guides designed so that any team member can run live demonstrations on their assigned machine, understand the expected output, and explain the networking principles to the evaluating faculty.

### Primary Documents:
- [`PHASE2_PRACTICAL_EXECUTION_GUIDE.md`](PHASE2_PRACTICAL_EXECUTION_GUIDE.md): The master 16-section practical execution manual covering all six Phase 2 extensions (A through F), pre-practical checklists, safety rules, detailed output interpretations, and viva Q&A defense.
- [`PRACTICAL_GUIDE_AUDIT.md`](PRACTICAL_GUIDE_AUDIT.md): Technical audit, command verification checklist, and deliverable readiness review for the practical guide.

---

## 2. Quick Machine & Role Reference

| Machine | Member | IP Address | Primary Practical Duties |
|---|---|---|---|
| **Mac1** | Rudraksh | `10.7.19.129` | Client testing, DNS resolution (`dig`), wire TTL validation, HTTPS verification, curl loops. |
| **Mac2** | Kaustubh | `10.7.9.219` | Primary Nginx reverse proxy (`8080`), TLS terminator (`8443`), authorized firewall testing. |
| **Mac3** | Pratyush | `10.7.24.216` | Backend services (`3001`/`3002`), backup DNS (`53`), standby Nginx (`80`/`443`), PF firewall. |
| **Mac4** | Bhargav | *N/A* | Documentation workstation only (assists with evaluation logging; runs zero server daemons). |

---

## 3. Related Documentation Links

- **Main Project README:** [`../../README.md`](../../README.md)
- **Phase 2 Technical Report:** [`../report/PHASE2_FINAL_REPORT.md`](../report/PHASE2_FINAL_REPORT.md)
- **Master Evidence Index:** [`../../evidence/MASTER_EVIDENCE_INDEX.md`](../../evidence/MASTER_EVIDENCE_INDEX.md)
- **Primary DNS Configuration:** [`../configuration/mac1-primary-dns/README.md`](../configuration/mac1-primary-dns/README.md)
- **Standby Nginx Configuration:** [`../configuration/mac3-standby-nginx/README.md`](../configuration/mac3-standby-nginx/README.md)
