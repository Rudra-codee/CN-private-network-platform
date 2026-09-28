# Network Topology & Machine Roles

This document describes the physical and logical network topology for Phase 1 of the Private Network Service Platform.

## Network Topology Diagram

```
                  Private Wi-Fi / LAN
                         |
        +----------------+----------------+
        |                |                |
      Mac 1            Mac 2            Mac 3
   DNS + Client    nginx Edge/LB       Backend A
                     :443              :3001
                         |
                         |
                       Mac 4
                     Backend B
                       :3002
```

## Machine Roles & Responsibilities

- **Mac 1 — Private DNS Server + Test Client**
  - Runs `dnsmasq` to provide authoritative private domain resolution for `.teamX.test`.
  - Serves as a primary DNS resolver for other nodes on the private LAN.
  - Generates test requests to verify DNS resolution and HTTPS end-to-end traffic.

- **Mac 2 — Edge Reverse Proxy & Load Balancer**
  - Runs `nginx` acting as the single public entry point (`:443`).
  - Terminates TLS connections for `app.teamX.test` and `api.teamX.test`.
  - Load balances incoming HTTP requests across Backend A and Backend B using round-robin.
  - Inserts/forwards proxy headers (`X-Forwarded-For`, `X-Forwarded-Proto`).

- **Mac 3 — Backend Server A**
  - Runs a lightweight HTTP/REST backend service listening on TCP port 3001.
  - Serves application requests routed from Mac 2.
  - Includes `X-Backend: A` in response headers to identify service origin.

- **Mac 4 — Backend Server B + Test Client**
  - Runs a lightweight HTTP/REST backend service listening on TCP port 3002.
  - Serves application requests routed from Mac 2.
  - Includes `X-Backend: B` in response headers to identify service origin.
  - Serves as an additional test client node for running traffic generators and Wireshark captures.

> [!NOTE]
> IP addresses will be assigned dynamically or recorded statically when connecting all machines to the private LAN segment. No static IPs are assumed prior to physical deployment.
