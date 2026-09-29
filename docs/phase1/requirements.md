# Phase 1 Requirements Specification

This document details the mandatory tasks and verification criteria for Phase 1 of the Private Network Service Platform project, derived from the project specification document.

## Mandatory Tasks Summary

### Task A — Establish Private LAN
- Connect all 4 macOS laptops to the same isolated private Wi-Fi network or LAN segment.
- Record key network parameters for every machine: IPv4 address, subnet mask/prefix, default gateway, active network interface, and MAC address.
- Verify full peer-to-peer reachability across all machine pairs using `ping`.
- Construct an explicit network topology diagram identifying machine roles and interconnects.

### Task B — Configure Private DNS Server
- Deploy `dnsmasq` on Mac 1 as the designated private DNS resolver.
- Create authoritative local DNS records:
  - `app.teamX.test` → Mac 2 private IP
  - `api.teamX.test` → Mac 2 private IP
- Configure at least two client Macs to resolve names via Mac 1 (`System Preferences → Network → DNS`).
- Verify domain resolution using `dig app.teamX.test` or `nslookup app.teamX.test` from client machines.

### Task C — Build Two Simple Backend Services
- Deploy Backend Service A on Mac 3 (listening on TCP port 3001).
- Deploy Backend Service B on Mac 4 (listening on TCP port 3002).
- Ensure backend services bind to LAN-accessible interfaces (not restricted to `127.0.0.1`).
- Support mandatory REST endpoints on both backends:
  - `GET /` — Returns status confirmation.
  - `GET /api/status` — Returns JSON with status and backend identifier (`{"backend": "A", "status": "ok"}`).
  - Response header `X-Backend: A` or `X-Backend: B`.

### Task D — Configure Edge Reverse Proxy and Load Balancer
- Configure `nginx` on Mac 2 to serve as the sole public gateway.
- Enforce service encapsulation: clients must never access backend IPs directly.
- Implement round-robin load balancing distributing requests to Mac 3 (3001) and Mac 4 (3002).
- Verify alternating `X-Backend` header values across sequential client requests.

### Task E — Add HTTPS / TLS
- Generate a self-signed TLS certificate or local CA certificate for `app.teamX.test`.
- Configure `nginx` on Mac 2 for TLS termination on TCP port 443.
- Import and trust the certificate authority across all client Macs.
- Verify secure communication without bypassing validation (no `-k` flag in `curl`).

### Task F — Demonstrate HTTP Caching Behavior
- Configure backend or edge headers to include `Cache-Control` directives (e.g., `Cache-Control: max-age=60`).
- Demonstrate conditional validation using `ETag` or `If-Modified-Since`.
- Collect evidence of cache hits or `304 Not Modified` status codes using `curl -I`.

### Task G — Capture Complete Protocol Flow
- Use Wireshark / `tcpdump` to record full protocol traces for client requests.
- Identify and document:
  - DNS query and response (UDP port 53).
  - TCP three-way handshake (`SYN` → `SYN-ACK` → `ACK`).
  - TLS handshake (`ClientHello`, `ServerHello`, Certificate Exchange, Finished).
  - HTTP application payload encryption and HTTP headers.
  - Ephemeral client ports and well-known server ports.

---

## Phase 1 Gate Verification

Phase 1 completion requires meeting all 5 verification conditions from a client machine:

1. **DNS Resolution**: Client successfully resolves `app.teamX.test` to Mac 2's IP using Mac 1 DNS.
2. **Secure HTTPS**: Client connects to `app.teamX.test` via HTTPS over TCP port 443 with a trusted TLS handshake.
3. **Edge Gateway Entry**: Client reaches the `nginx` reverse proxy edge on Mac 2.
4. **Balanced Backends**: Client receives alternating responses from Backend A (Mac 3) and Backend B (Mac 4) via the `nginx` load balancer.
5. **Protocol Evidence**: Packet capture files (`.pcap`/`.pcapng`) capture and prove the full protocol sequence: **DNS → TCP → TLS → HTTP**.
