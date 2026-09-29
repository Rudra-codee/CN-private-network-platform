# End-to-End Request Flow — Planned Architecture

This document describes the intended end-to-end request flow for the Private Network Service Platform. This is the **planned Phase 1 architecture** and is documented here for reference as the target design.

> [!IMPORTANT]
> Task A establishes the LAN communication required for this request path. DNS, HTTPS, nginx, and backend services are implemented in subsequent Phase 1 tasks.

## Planned Request Flow

```
Client (Mac 1 or Mac 4)
  ↓
DNS query to Mac 1 (dnsmasq, UDP 53)
  ↓
app.teamX.test resolves to Mac 2 (10.7.9.11)
  ↓
HTTPS connection to Mac 2 (TCP 443 + TLS)
  ↓
nginx reverse proxy / load balancer
  ↓
Backend A (Mac 3, port 3001) or Backend B (Mac 4, port 3002)
```

## Request Sequence (Planned)

1. **DNS Query**: The client application issues a DNS query for `app.teamX.test` to the configured local resolver (Mac 1).
2. **DNS Response**: Mac 1 (`dnsmasq`) responds over UDP port 53 with an A record containing Mac 2's private IP address (10.7.9.11).
3. **TCP Connection**: The client initiates a TCP three-way handshake (`SYN` → `SYN-ACK` → `ACK`) to Mac 2 on port 443.
4. **TLS Handshake**: The client and Mac 2 (`nginx`) perform a TLS handshake (`ClientHello`, `ServerHello`, Certificate verification, Key Exchange, `Finished`).
5. **TLS Termination**: `nginx` on Mac 2 decrypts the incoming HTTPS traffic and inspects the HTTP request line and headers.
6. **Upstream Load Balancing**: `nginx` forwards the HTTP request over TCP to either Backend A (Mac 3 on port 3001) or Backend B (Mac 4 on port 3002) based on round-robin load balancing.
7. **Backend Execution**: The selected backend processes the HTTP request and returns an HTTP response containing payload and `X-Backend` headers.
8. **Edge Response Processing**: `nginx` receives the backend response, encrypts it using the active TLS session keys, and transmits it back to the client.
9. **Client Receipt**: The client receives and decrypts the HTTPS response, confirming valid application data and service origin.

---

## Protocol & Port Mapping (Planned)

| Protocol / Layer | Role / Function | Port & Socket |
|------------------|-----------------|---------------|
| **DNS (UDP)** | Name resolution (`app.teamX.test` → Mac 2 IP) | UDP 53 |
| **TCP** | Connection establishment & reliable data transfer | TCP 443 (Client ↔ Edge) |
| **TLS** | Session encryption & server identity verification | Encapsulated over TCP 443 |
| **HTTP** | Application payload request and response messaging | Layer 7 over TLS session |
| **Backend A** | Upstream application service instance | TCP 3001 |
| **Backend B** | Upstream application service instance | TCP 3002 |

## Current Status

As of Task A completion, only the underlying LAN connectivity between all four machines has been established and verified. The services and protocol layers described above will be deployed incrementally in Tasks B through H.
