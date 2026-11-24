# Master Evidence Index: Nginx, HTTP, TLS, Load Balancing & Protocol Traces

**Project:** Private Network Service Platform — Phase 1 & Phase 2  
**Component:** Edge Gateway, Transport Security, Upstream Proxying, and Protocol Auditing  
**Primary Auditor:** Kaustubh Hiwanj (Senior Computer Networks Engineer)  
**Target Path:** `evidence/nginx-http-tls/README.md`  
**Classification:** Technical Evidence Repository Index  

---

## 1. Executive Summary & Evidence Navigation

This master directory consolidates and organizes all empirical verification logs, cryptographic inspections, protocol captures, and operational evidence for the application delivery tier of the **Private Network Service Platform**.

Evidence is organized into five functional domains designed for rapid navigation (locate any proof within 30 seconds):
1. **[`configuration/`](configuration/nginx-configuration.md)**: Nginx 1.31.6 daemon configuration, syntax tests (`nginx -t`), and listening socket listeners (`8080`, `8443`).
2. **[`http/`](http/http-reverse-proxy.md)**: Unencrypted HTTP reverse proxying on port 8080, request-response framing, and upstream header injection.
3. **[`https-tls/`](https-tls/https-tls-verification.md)**: TLS 1.3 termination, certificate chain validation without `-k`, OpenSSL handshake telemetry, and cipher suites.
4. **[`load-balancing/`](load-balancing/load-balancing-verification.md)**: Upstream round-robin distribution, 10-request verification loops, and process-level failover.
5. **[`caching/`](caching/caching-verification.md)**: Shared-memory cache zone (`local_cache`), `X-Cache-Status` transitions (`MISS` $\rightarrow$ `HIT`), and `304 Not Modified` revalidation.
6. **[`wireshark/`](wireshark/wireshark-protocol-analysis.md)**: Multi-layer packet traces, frame dissections, and protocol flow analysis.

---

## 2. Master Evidence Catalog & Verification Audit

The table below catalogs every piece of evidence, detailing the machine used, commands executed, observed outcomes, limitations, and verification classifications:
- **`VERIFIED`**: Actively tested with concrete terminal or cryptographic evidence.
- **`HISTORICAL`**: Captured and verified during Phase 1 baseline or intermediate test sessions; retained for archival integrity.
- **`INCOMPLETE`**: Telemetry partially recorded or missing full negative test coverage.
- **`MISSING`**: Raw file or artifact not stored in version control.

| Evidence Item / Artifact | Feature Demonstrated | Host Machine | Collection Command | Observed Result | What It Proves | What It Does NOT Prove | Status |
|---|---|---|---|---|---|---|---|
| [`configuration/nginx-configuration.md`](configuration/nginx-configuration.md) | Nginx Daemon & Syntax Validation | Mac 2 | `nginx -v`<br/>`sudo nginx -t` | `nginx/1.31.6`<br/>`syntax is ok` / `test is successful` | Proves Nginx configuration syntax is valid and core modules are present. | Does not prove Nginx is currently active or listening on standard port 80. | **VERIFIED** |
| `sudo lsof -nP -iTCP:8080,8443` in [`configuration/`](configuration/nginx-configuration.md) | Listening Socket Binding | Mac 2 | `sudo lsof -nP -iTCP:8080,8443 -sTCP:LISTEN` | Nginx master (PID 6699) & worker (PID 6700) in `LISTEN` on `*:8080` and `*:8443` | Proves sockets are bound and listening across all IPv4 interfaces. | Does not prove incoming LAN packets can bypass host firewall if PF is active. | **VERIFIED** |
| [`http/http-reverse-proxy.md`](http/http-reverse-proxy.md) | Plaintext HTTP Reverse Proxy | Mac 2 | `curl -i http://app.teamX.test:8080/api/status` | `HTTP/1.1 200 OK`<br/>`Server: nginx/1.31.6`<br/>`X-Backend: A` and `B` | Proves Nginx terminates HTTP on 8080, proxies to upstreams, and relays response. | Does not prove transport layer encryption (traffic is unencrypted). | **VERIFIED** |
| [`https-tls/https-tls-verification.md`](https-tls/https-tls-verification.md) | HTTPS Request Without `-k` Bypass | Mac 2 & Mac 1 | `curl -i https://app.teamX.test:8443/api/status` | `HTTP/1.1 200 OK`<br/>`X-Backend: B`<br/>Zero TLS warnings | Proves client trust store validates leaf certificate against local root CA. | Does not prove public trust (valid only on nodes with `mkcert` root CA). | **VERIFIED** |
| `openssl x509` in [`https-tls/`](https-tls/https-tls-verification.md) | X.509 Leaf Certificate Attributes | Mac 2 | `openssl x509 -in certs/app.teamX.test.pem -noout -subject -issuer -dates -ext subjectAltName` | SAN: `DNS:app.teamX.test`<br/>Expiry: Dec 29, 2028 | Proves certificate is cryptographically valid and bound to correct hostname. | Does not prove certificate is loaded into Nginx memory without daemon reload. | **VERIFIED** |
| `curl -v` in [`https-tls/`](https-tls/https-tls-verification.md) | TLS 1.3 Handshake & Cipher Suite | Mac 2 & Mac 1 | `curl -v https://app.teamX.test:8443/api/status` | `TLSv1.3`<br/>`AEAD-CHACHA20-POLY1305-SHA256`<br/>`SSL certificate verify ok` | Proves complete TLS 1.3 handshake negotiation and encrypted HTTP exchange. | Does not prove upstream leg is encrypted (upstream proxying uses HTTP). | **VERIFIED** |
| [`load-balancing/load-balancing-verification.md`](load-balancing/load-balancing-verification.md) | Upstream Round-Robin Load Balancing | Mac 2 | `for i in {1..10}; do curl ... \| grep X-Backend; done` | Exact 50/50 alternation (`A` $\rightarrow$ `B` $\rightarrow$ `A` $\rightarrow$ `B` ...)<br/>10/10 success | Proves Nginx round-robin scheduler alternates requests across upstreams. | Does not prove hardware redundancy (both backends run on Mac 3 in Phase 2). | **VERIFIED** |
| [`caching/caching-verification.md`](caching/caching-verification.md) | Cache Miss-to-Hit Lifecycle | Mac 2 & Mac 1 | `curl -i https://app.teamX.test:8443/api/status` | Request 1: `X-Cache-Status: MISS`<br/>Request 2: `X-Cache-Status: HIT` | Proves Nginx caches 200 responses in `local_cache` and serves hits from disk/memory. | Does not prove caching for non-GET methods or dynamic uncached endpoints. | **VERIFIED** |
| `If-None-Match` in [`caching/`](caching/caching-verification.md) | RFC 7232 Conditional Revalidation | Mac 1 | `curl -i -H 'If-None-Match: ...' https://app.teamX.test:8443/api/status` | `HTTP/1.1 304 Not Modified`<br/>Zero body payload | Proves bandwidth optimization via standard HTTP conditional validation. | Does not prove upstream backend was contacted (served from Nginx cache). | **VERIFIED** |
| `mac1-tls13-https-capture.png` in [`wireshark/`](wireshark/wireshark-protocol-analysis.md) | Wireshark TLS 1.3 Handshake Capture | Mac 1 | Wireshark GUI Filter: `tls && ip.addr == 10.7.26.200 && tcp.port == 8443` | Frame 50240, ClientHello, ServerHello, Application Data | Proves encrypted network transport over Wi-Fi interface. | Does not provide raw packet capture for offline binary re-inspection. | **HISTORICAL** |
| `mac1-backend-a-response.png` in [`wireshark/`](wireshark/wireshark-protocol-analysis.md) | Visual Terminal Verification | Mac 1 | Visual PNG of curl output | Displays `200 OK`, `X-Backend: A`, `Cache-Control`, `X-Cache-Status` | Visually confirms execution context on Mac 1 client station. | Does not prove underlying TCP packet framing without accompanying Wireshark trace. | **HISTORICAL** |
| `mac1-private-dns-verification.png` in [`wireshark/`](wireshark/wireshark-protocol-analysis.md) | Authoritative DNS Resolution | Mac 1 | `dig @10.7.26.214 app.teamX.test` | `NOERROR`, `aa` flag set, answer `10.7.26.200` | Proves `dnsmasq` serves local authoritative zone for `app.teamX.test`. | Does not prove target HTTP/HTTPS service on port 8443 is online. | **HISTORICAL** |
| Raw Binary Packet Traces (`*.pcapng`) | Binary Wire Capture File | Mac 1 / Mac 2 | `tcpdump -w trace.pcap` | *File not present in repository* | N/A | **Binary trace file missing from repository** (omitted from Git). | **MISSING** |
| Mac 2 Server-Side Packet Trace | Server Ingress Capture | Mac 2 | `tcpdump -i en0 port 8443` | *File not present in repository* | N/A | Server-side capture was not executed (capture performed on client Mac 1). | **MISSING** |

---

## 3. DNS-Based Service Access & Port Architecture Summary

A critical finding in the evidence review is the distinction between DNS resolution and edge port assignments across Phase 1 and Phase 2:

```
+──────────────────────────────────────────────────────────────────────────+
|                    DNS-Based Edge Routing Realities                      |
|                                                                          |
|   1. Phase 1 Baseline:                                                   |
|      app.teamX.test ──► 10.7.9.11 (Mac 2 Edge)                           |
|      Traffic directed to: Port 8080 (HTTP) or Port 8443 (HTTPS)          |
|                                                                          |
|   2. Intermediate Phase 1/2 Test:                                        |
|      app.teamX.test ──► 10.7.26.200 (Mac 2 DHCP Renewal)                 |
|      Traffic directed to: Port 8080 (HTTP) or Port 8443 (HTTPS)          |
|                                                                          |
|   3. Phase 2 Standby Migrated State (Extension E):                       |
|      app.teamX.test ──► 10.7.24.216 (Mac 3 Standby Edge)                 |
|      Traffic directed to: Port 80 (HTTP) or Port 443 (HTTPS)             |
|                                                                          |
|   CRITICAL OPERATIONAL CONSTRAINT:                                       |
|   - Mac 2 listens strictly on 8080 and 8443.                             |
|   - Mac 3 standby listens strictly on 80 and 443.                        |
|   - If DNS points to 10.7.24.216, requests to port 8443 will FAIL        |
|     because Mac 3 does not listen on port 8443!                          |
+──────────────────────────────────────────────────────────────────────────+
```

---

## 4. Cryptographic Security & Private Key Redaction Notice

In strict adherence to network security governance:
- **No private keys** (`app.teamX.test-key.pem` or `rootCA-key.pem`) are included in any documentation or evidence artifact.
- Key file locations and permissions (`0600`) are verified, but key content is redacted.
- All HTTPS evidence was collected using public root CA trust (`mkcert`) without bypassing certificate validation via `curl -k`.
