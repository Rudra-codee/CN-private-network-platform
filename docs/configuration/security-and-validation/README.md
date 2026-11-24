# Security Configuration, TLS Architecture & Validation Runbook

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Document:** Security Configuration, TLS Implementation, PF Firewall, Validation Checklist, and Bundle Review  
**Target Path:** `docs/configuration/security-and-validation/README.md`  
**Classification:** Operational Security & Configuration Governance  
**Author:** Senior Network Security & TLS Documentation Engineer  

---

## 1. Executive Summary & Operational Boundary

This document serves as the authoritative security configuration reference, cryptographic validation manual, and configuration bundle quality review for the **Private Network Service Platform**.

### 1.1 Cluster Hardware & Infrastructure Demarcation

The active infrastructure operates exclusively across three physical Apple macOS workstations on the `10.7.0.0/19` private network segment:

| Node | Current Phase 2 IPv4 | Active Production Roles | Listening Ports / Services | Security Domain |
|---|---|---|---|---|
| **Mac 1** | `10.7.19.129` | Primary Authoritative DNS Resolver | `53/udp`, `53/tcp` (`dnsmasq`) | Private Naming Tier |
| **Mac 2** | `10.7.9.219` | Primary Edge Reverse Proxy, TLS Termination, Caching | `8080/tcp` (HTTP), `8443/tcp` (HTTPS/TLS) (`nginx`) | Public Cluster Ingress |
| **Mac 3** | `10.7.24.216` | Backend A (`node` / 3001)<br/>Backend B (`node` / 3002)<br/>Backup DNS Resolver (`dnsmasq`)<br/>Standby Edge Proxy (`nginx`) | `3001/tcp`<br/>`3002/tcp`<br/>`53/udp`, `53/tcp`<br/>`80/tcp`, `443/tcp` | Isolated Application Tier & Standby Ingress |
| **Mac 4** | *N/A (Host Station)* | **UNAVAILABLE AS PROJECT SERVER**<br/>Administrative Workstation (Documentation Only) | *None* | Non-infrastructure |

> [!CRITICAL]
> **Administrative Workstation Demarcation (Mac 4):**  
> Mac 4 is **strictly a client workstation used for documentation and repository management**. It is **not** an active infrastructure server, hosts no production daemon processes, and must never be referenced as an active backend or edge node in Phase 2 production architecture.

---

## 2. TLS Architecture & Cryptographic Implementation

The platform enforces end-to-end transport encryption between client applications and the edge reverse proxy using Transport Layer Security (TLS 1.3 and TLS 1.2).

### 2.1 Private Public Key Infrastructure (PKI) Architecture

The platform employs a private, two-tier Certificate Authority (CA) hierarchy provisioned via `mkcert`:

```
+──────────────────────────────────────────────────────────────────────────+
|                       Private Root CA (mkcert)                           |
|           Issuer: "mkcert kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local"   |
|           Public Certificate: rootCA.pem                                 |
|           Private Key: rootCA-key.pem (HELD EXCLUSIVELY ON MAC 2)        |
+────────────────────────────────────┬─────────────────────────────────────+
                                     │
                                     │ Signs leaf certificate
                                     ▼
+──────────────────────────────────────────────────────────────────────────+
|                    Edge Server Leaf Certificate                          |
|           Subject: O=mkcert development certificate                      |
|           Common Name / SAN: DNS:app.teamX.test                          |
|           Public Certificate: app.teamX.test.pem                         |
|           Private Key: app.teamX.test-key.pem                            |
|           Deployment Path: /opt/homebrew/etc/nginx/certs/                |
+──────────────────────────────────────────────────────────────────────────+
```

### 2.2 Certificate Creation Procedure

The TLS certificate for the private domain was generated on the primary edge host (Mac 2):

```bash
# 1. Provision certificate storage directory with restricted permissions
sudo mkdir -p /opt/homebrew/etc/nginx/certs
cd /opt/homebrew/etc/nginx/certs

# 2. Generate local CA and leaf certificate for the application FQDN
mkcert -install
mkcert app.teamX.test
```

**Generation Telemetry & Output:**
```text
Created a new certificate valid for the following names 📜
 - "app.teamX.test"

The certificate is at "./app.teamX.test.pem" and the key at "./app.teamX.test-key.pem" ✅
It will expire on 30 December 2028 🗓
```

### 2.3 Verified Certificate Subject & SAN Information

Verification of `/opt/homebrew/etc/nginx/certs/app.teamX.test.pem` executed via OpenSSL confirms:

```bash
openssl x509 -in /opt/homebrew/etc/nginx/certs/app.teamX.test.pem -noout -subject -issuer -dates -ext subjectAltName
```

**Verified Cryptographic Attributes:**
- **Subject**: `O = mkcert development certificate, OU = kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)`
- **Issuer**: `O = mkcert development CA, OU = kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj), CN = mkcert kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)`
- **Validity Window**: Active through `December 30, 2028`
- **X509v3 Subject Alternative Name (SAN)**:
  ```text
  X509v3 Subject Alternative Name: 
      DNS:app.teamX.test
  ```

### 2.4 Nginx Cryptographic Reference & Configuration

In [`configs/nginx/nginx.conf`](file:///Users/kaustubhhiwanj/CN-private-network-platform/configs/nginx/nginx.conf), Nginx binds the certificate and private key within the HTTPS virtual host block:

```nginx
# ==========================================
# Task E & F - HTTPS / TLS & HTTP Caching
# ==========================================
server {
    listen 8443 ssl;
    server_name app.teamX.test;

    # Cryptographic Material Bindings
    ssl_certificate     /opt/homebrew/etc/nginx/certs/app.teamX.test.pem;
    ssl_certificate_key /opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem;

    # Modern TLS Protocol Constraints
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers   HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://backend_pool;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 2.5 Private Key Protection Policy

> [!CAUTION]
> **Strict Key Containment Rule:**  
> 1. Private keys (`app.teamX.test-key.pem`, `rootCA-key.pem`) must **never be committed to Git or transferred across insecure channels**.
> 2. Key permissions on Mac 2 must be restricted: `chmod 600 /opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem`.
> 3. Client machines (Mac 1, Mac 3) receive **only** the public root certificate (`rootCA.pem`) to establish CA trust; they never receive the CA private key.

### 2.6 Certificate & HTTPS Validation Runbook

```bash
# 1. Local Certificate Syntax & Expiration Check
openssl x509 -in /opt/homebrew/etc/nginx/certs/app.teamX.test.pem -noout -text | grep -A 2 "Validity"

# 2. Verify Private Key Matches Certificate (Modulus Comparison)
# (Hashes must match identically)
openssl x509 -noout -modulus -in /opt/homebrew/etc/nginx/certs/app.teamX.test.pem | openssl md5
openssl rsa -noout -modulus -in /opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem | openssl md5

# 3. Network TLS Handshake & SNI Verification (from Client Mac 1)
openssl s_client -connect 10.7.9.219:8443 -servername app.teamX.test -showcerts </dev/null

# 4. End-to-End Trusted HTTPS Request (without -k flag, using installed root CA)
curl -i https://app.teamX.test:8443/api/status

# 5. Explicit CA-pinned HTTPS Request (Validates chain against exported rootCA.pem)
curl -i --cacert /path/to/rootCA.pem https://app.teamX.test:8443/api/status
```

---

## 3. macOS Packet Filter (PF) Firewall & Microsegmentation

To protect unauthenticated backend microservices from direct client tampering, Mac 3 enforces Layer 4 microsegmentation using macOS Packet Filter (`pf`).

### 3.1 Intended Firewall Architecture

```
                                LAN Traffic (10.7.0.0/19)
                                           │
                    ┌──────────────────────┴──────────────────────┐
                    │                                             │
                    ▼                                             ▼
        [ Authorized Edge Ingress ]                 [ Unauthorized LAN Nodes ]
             Source: 10.7.9.219                           Source: Any Other IP
                    │                                             │
                    ▼                                             ▼
        TCP SYN to Ports 3001/3002                    TCP SYN to Ports 3001/3002
                    │                                             │
         ═════════════════════════                     xxxxxxxxxxxxxxxxxxxxxxxxx
         ║  PF Rule: PASS QUICK  ║                     x   PF Rule: BLOCK DROP x
         ═════════════════════════                     xxxxxxxxxxxxxxxxxxxxxxxxx
                    │                                             │
                    ▼                                             ▼
         State Table Created (Keep State)             Packet Dropped Silently
         Connection ESTABLISHED                       Client Encounters Timeout
                    │
                    ▼
       ┌───────────────────────────┐
       │ Backend Services (Mac 3)  │
       │   Port 3001 / Port 3002   │
       └───────────────────────────┘
```

### 3.2 Formal Ruleset Specification

The intended PF ruleset for Mac 3 isolates backend application sockets:

```pf
# /etc/pf.anchors/teamX-backends
# Service Isolation Anchor for Backend Instances on Mac 3

# Macro definitions
edge_proxy    = "10.7.9.219"
backend_ports = "{ 3001, 3002 }"
int_if        = "en0"

# Rule 1: Allow authorized traffic from primary edge proxy with state tracking
pass in quick on $int_if proto tcp from $edge_proxy to any port $backend_ports keep state

# Rule 2: Intercept and silently drop all unauthorized traffic targeting backend ports
block in drop quick on $int_if proto tcp from any to any port $backend_ports
```

Anchor definition in `/etc/pf.conf` on Mac 3:
```pf
anchor "teamX-backends"
load anchor "teamX-backends" from "/etc/pf.anchors/teamX-backends"
```

### 3.3 Runtime Audit & Live Verification Status

> [!WARNING]
> **Engineering Reality & Verification Distinction:**  
> - **Workstation Inspection**: Inspection of `/etc/pf.conf` on this administrative workstation (Mac 4) shows only the default Apple operating system anchors (`com.apple`). Mac 4 does not host backend services.
> - **Remote Host Dependency**: The isolation anchor `/etc/pf.anchors/teamX-backends` is deployed on the remote host **Mac 3 (`10.7.24.216`)**.
> - **Audit Finding**: In accordance with rigorous documentation engineering standards, **we do not claim firewall rules are permanently active at all times simply because documentation examples exist**. Live operational verification requires executing `sudo pfctl -a teamX-backends -sr` directly on Mac 3.

---

## 4. Multi-Tier Configuration Validation Checklist

This checklist provides standard, repeatable CLI commands to audit every service layer across all nodes.

### 4.1 Tier 1: Private DNS Resolvers (`dnsmasq`)

| Validation Task | Command | Target Node | Expected Outcome |
|---|---|---|---|
| **Configuration Syntax** | `dnsmasq --test -C /path/to/dnsmasq.conf` | Mac 1 / Mac 3 | `dnsmasq: syntax check OK.` |
| **Active Socket Listener** | `sudo lsof -nP -iUDP:53 -iTCP:53` | Mac 1 / Mac 3 | `dnsmasq` bound to `10.7.19.129:53` or `10.7.24.216:53` |
| **Authoritative Resolution** | `dig @10.7.19.129 app.teamX.test +short` | Client / Mac 1 | Resolves to `10.7.24.216` (or `10.7.9.219`) |
| **TTL Header Verification** | `dig @10.7.19.129 ttl-test.teamX.test` | Client / Mac 1 | Answer section displays TTL `30` |
| **Negative Filtering** | `dig @10.7.19.129 unqualified-name` | Client / Mac 1 | Returns `NXDOMAIN` (no upstream leak) |

### 4.2 Tier 2: Edge Reverse Proxy & Cache (`nginx`)

| Validation Task | Command | Target Node | Expected Outcome |
|---|---|---|---|
| **Configuration Syntax** | `nginx -t -c /opt/homebrew/etc/nginx/nginx.conf` | Mac 2 / Mac 3 | `syntax is ok` / `test is successful` |
| **Active Sockets** | `sudo lsof -nP -iTCP:8080 -iTCP:8443 -sTCP:LISTEN` | Mac 2 | `nginx: master/worker` listening on `8080` & `8443` |
| **Standby Active Sockets**| `sudo lsof -nP -iTCP:80 -iTCP:443 -sTCP:LISTEN` | Mac 3 | `nginx: master/worker` listening on `80` & `443` |
| **HTTP Reverse Proxy** | `curl -i http://10.7.9.219:8080/api/status` | Client | `HTTP/1.1 200 OK` + `X-Backend: A` or `B` |
| **Cache Header Check** | `curl -i https://app.teamX.test:8443/api/status` | Client | `X-Cache-Status: HIT` on second identical query |

### 4.3 Tier 3: TLS Certificates & Cryptography

| Validation Task | Command | Target Node | Expected Outcome |
|---|---|---|---|
| **Certificate SAN Match** | `openssl x509 -in certs/app.teamX.test.pem -noout -ext subjectAltName` | Mac 2 / Mac 3 | `DNS:app.teamX.test` present |
| **Expiration Audit** | `openssl x509 -in certs/app.teamX.test.pem -noout -enddate` | Mac 2 / Mac 3 | `notAfter=Dec 30 2028` |
| **Private Key Match** | Compare md5 of certificate modulus and private key modulus | Mac 2 | Identical MD5 hashes |
| **Live TLS 1.3 Handshake**| `openssl s_client -connect 10.7.9.219:8443 -servername app.teamX.test </dev/null` | Client | `Protocol : TLSv1.3` / `Verify return code: 0 (ok)` |

### 4.4 Tier 4: Backend Microservices (Node.js / Express)

| Validation Task | Command | Target Node | Expected Outcome |
|---|---|---|---|
| **Process Status** | `pgrep -fl "node server.js"` | Mac 3 | Two active Node.js processes |
| **Port Bindings** | `sudo lsof -nP -iTCP:3001,3002 -sTCP:LISTEN` | Mac 3 | Node processes listening on `0.0.0.0:3001` and `3002` |
| **Direct Local Probe** | `curl -i http://127.0.0.1:3001/api/status` | Mac 3 | `HTTP/1.1 200 OK` + `{"backend":"A","status":"ok"}` |
| **Direct Local Probe B**| `curl -i http://127.0.0.1:3002/api/status` | Mac 3 | `HTTP/1.1 200 OK` + `{"backend":"B","status":"ok"}` |

### 4.5 Tier 5: Packet Filter (PF) Firewall

| Validation Task | Command | Target Node | Expected Outcome |
|---|---|---|---|
| **PF Anchor Syntax** | `sudo pfctl -vnf /etc/pf.anchors/teamX-backends` | Mac 3 | Rules parsed successfully without error |
| **Active Ruleset Audit**| `sudo pfctl -a teamX-backends -sr` | Mac 3 | Shows active pass and block drop rules |
| **Firewall State Table**| `sudo pfctl -ss` | Mac 3 | Active state entries for `10.7.9.219 -> 3001/3002` |
| **Negative Probe** | `nc -zv -w 3 10.7.24.216 3001` (from Mac 1 or Mac 4) | Client (Not Mac 2) | Operation timed out (packet dropped) |

---

## 5. Configuration Bundle Quality Review

A comprehensive technical audit was conducted across the configuration assets and architectural documentation generated by team members:
- **Rudraksh**: Primary DNS (`dnsmasq`), LAN topology, Task G Wireshark evidence, Section 01.
- **Kaustubh**: Primary Nginx reverse proxy, TLS termination, Section 02, Section 04.
- **Pratyush**: Backup DNS, Standby Nginx, Backend A & B services, Section 03.

### 5.1 Audit Findings & Cross-Component Discrepancy Matrix

| Component | Author | Verified Discrepancy / Inconsistency | Root Cause Analysis | Remediation Status |
|---|---|---|---|---|
| **Nginx Upstream Pool** | Kaustubh | `configs/nginx/nginx.conf` upstream lists `server 10.7.13.5:3001; server 10.7.14.32:3002;`. | Repo config retains Phase 1 snapshot. In Phase 2, Backend B was consolidated to Mac 3 (`10.7.24.216:3002`) and Backend A is at `10.7.24.216:3001`. | Flagged in `CONFIGURATION_INDEX.md`. Live runtime config uses updated IPs; repo template must be versioned. |
| **Primary DNS IP** | Rudraksh | `configs/dns/dnsmasq.conf` contains `listen-address=10.7.17.222` and records pointing to `10.7.9.11`. | Dynamic DHCP renewal changed Mac 1 from `10.7.17.222` $\rightarrow$ `10.7.26.214` $\rightarrow$ `10.7.19.129`. | Documented in Section 02. Configuration file represents historical Phase 1 baseline. |
| **Hardcoded File URI** | Pratyush | `docs/architecture/sections/03_HTTP_TLS_Nginx_and_Backends.md` line 830 references `file:///Users/pratyushchouksey/Downloads/CN-private-network-platform-main%202/...`. | Contributor pasted local absolute laptop download path into Markdown link. | Defect logged for path sanitization. |
| **Missing Repo Configs**| Pratyush | No `dnsmasq.conf` or `nginx.conf` exists in `configs/` for the backup DNS or standby edge on Mac 3. | Secondary node configurations were provisioned interactively on Mac 3 and not backported to repository tree. | Documented as "Runtime-Only / Missing from Repo" in Index. |
| **Missing PF Anchor** | Team | No `teamX-backends` anchor file exists under `configs/pf/` in the repo. | PF firewall rules were applied directly on Mac 3 host. | Specification created in Section 04 and this document; repo lacks dedicated `.conf` file. |
| **Edge Listening Ports**| General | Occasional references to Nginx on port 80/443 on Mac 2. | Conflation between Mac 2 (8080/8443) and Mac 3 Standby Nginx (80/443). | Strictly clarified: Mac 2 uses 8080/8443; Mac 3 standby uses 80/443. |
| **Hardware HA Claims** | General | Early documentation claimed "high availability for application backends". | Colocation of Backend A & B on Mac 3 represents process-level failover, not hardware HA. | Explicitly corrected in Sections 01, 03, and 04. |
| **Mac 4 Status** | General | Phase 1 docs list Mac 4 as active Backend B host. | Mac 4 was decommissioned as an infrastructure node. | Clarified: Mac 4 is strictly an administrative documentation workstation. |

### 5.2 Secret Exposure Audit

- **Audit Procedure**: Full recursive regex scan (`git grep -i "PRIVATE KEY"`, search for `*.key`, `*.pem`, `id_rsa`).
- **Audit Result**: **PASSED CLEAN (Zero Secrets Committed)**.
- **Verification Details**:
  - All private keys (`app.teamX.test-key.pem`, `rootCA-key.pem`) are strictly excluded via `.gitignore`.
  - Only public root instructions (`configs/tls/README.md`) and verified metadata (`evidence/05-tls/tls-certificate.md`) exist in the tree.
