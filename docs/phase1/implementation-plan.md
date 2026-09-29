# Phase 1 Implementation Plan

This document outlines the sequential step-by-step implementation order for Phase 1. 

> [!IMPORTANT]
> **Dependency Requirement**: Tasks MUST be completed in exact strict sequential order. Later steps depend directly on the correct operation of earlier steps. Do not attempt higher-layer configurations (e.g., TLS or Load Balancing) before verifying lower-layer connectivity (LAN, IP Reachability, and DNS).

## Step-by-Step Implementation Sequence

1. **LAN Setup**: Physically connect all 4 macOS laptops to the private Wi-Fi / LAN switch segment.
2. **IP Inventory**: Retrieve and log network interface details, MAC addresses, IPv4 addresses, subnets, and default gateways in `docs/architecture/ip-inventory.md`.
3. **Ping Verification**: Execute cross-ping verification matrix (`ping -c 3`) across all 4 machine pairs to confirm full L2/L3 reachability.
4. **Private DNS**: Install and configure `dnsmasq` on Mac 1; set client DNS resolvers to Mac 1 IP and verify `app.teamX.test` and `api.teamX.test` resolution via `dig`/`nslookup`.
5. **Backend A**: Implement lightweight HTTP REST server on Mac 3 (listening on TCP port 3001) returning `X-Backend: A`.
6. **Backend B**: Implement lightweight HTTP REST server on Mac 4 (listening on TCP port 3002) returning `X-Backend: B`.
7. **Direct Backend Connectivity**: Test direct client connectivity to Mac 3 (port 3001) and Mac 4 (port 3002) via `curl` to verify backend availability.
8. **nginx Reverse Proxy**: Install and configure `nginx` on Mac 2 to proxy port 80/443 traffic to backend servers.
9. **Load Balancing**: Configure upstream block in `nginx` for round-robin load balancing and confirm alternating `X-Backend` headers.
10. **TLS Setup**: Generate local CA / self-signed certificates, install CA in client trust stores, and configure TLS termination on `nginx` (port 443).
11. **HTTP Caching**: Add `Cache-Control` / `ETag` headers and verify client cache hits / `304 Not Modified` responses using `curl -I`.
12. **Wireshark Evidence**: Capture and export `.pcap`/`.pcapng` packet files covering DNS query, TCP handshake, TLS handshake, and HTTP payload.
13. **Failure Demonstrations**: Inject and record standard failure scenarios (wrong DNS server, wrong record, single backend down, both backends down, wrong port).
14. **Final Phase 1 Verification**: Execute the end-to-end Phase 1 gate verification test suite and confirm all evidence artifacts are collected in `evidence/`.
