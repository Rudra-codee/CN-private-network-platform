# End-to-End Request Flow Specification

This document details the step-by-step lifecycle of a client request traveling through each protocol layer in the private network platform.

## Request Sequence

1. **DNS Query**: The client application issues a DNS query for `app.teamX.test` to the configured local resolver (Mac 1).
2. **DNS Response**: Mac 1 (`dnsmasq`) responds over UDP port 53 with an A record containing Mac 2's private IP address.
3. **TCP Connection**: The client initiates a TCP three-way handshake (`SYN` → `SYN-ACK` → `ACK`) to Mac 2 on port 443.
4. **TLS Handshake**: The client and Mac 2 (`nginx`) perform a TLS handshake (`ClientHello`, `ServerHello`, Certificate verification, Key Exchange, `Finished`).
5. **TLS Termination**: `nginx` on Mac 2 decrypts the incoming HTTPS traffic and inspects the HTTP request line and headers.
6. **Upstream Load Balancing**: `nginx` forwards the HTTP request over TCP to either Backend A (Mac 3 on port 3001) or Backend B (Mac 4 on port 3002) based on round-robin load balancing.
7. **Backend Execution**: The selected backend processes the HTTP request and returns an HTTP response containing payload and `X-Backend` headers.
8. **Edge Response Processing**: `nginx` receives the backend response, encrypts it using the active TLS session keys, and transmits it back to the client.
9. **Client Receipt**: The client receives and decrypts the HTTPS response, confirming valid application data and service origin.

---

## Protocol & Port Mapping

| Protocol / Layer | Role / Function | Port & Socket |
|------------------|-----------------|---------------|
| **DNS (UDP)** | Name resolution (`app.teamX.test` → Mac 2 IP) | UDP 53 |
| **TCP** | Connection establishment & reliable data transfer | TCP 443 (Client ↔ Edge) |
| **TLS** | Session encryption & server identity verification | Encapsulated over TCP 443 |
| **HTTP** | Application payload request and response messaging | Layer 7 over TLS session |
| **Backend A** | Upstream application service instance | TCP 3001 |
| **Backend B** | Upstream application service instance | TCP 3002 |
